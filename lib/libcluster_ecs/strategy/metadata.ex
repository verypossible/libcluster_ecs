defmodule ClusterECS.Strategy.Metadata do
  @moduledoc """
  This clustering strategy works like so:

  - Use the ECS API to list tasks by service
  - Use the ECS API to describe tasks
  - Build node names from IPs resolved from previous step

  It will continually monitor and update its connections every 5s.
  """

  use GenServer
  use Cluster.Strategy
  alias Cluster.{Strategy, Strategy.State}
  alias ClusterECS.{AWS, ECS, MetadataEndpoint}

  @default_polling_interval 5_000

  @impl Strategy
  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  @impl GenServer
  def init([state]) do
    send(self(), :load)
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:load, %State{} = state), do: {:noreply, load(state)}

  defp load(%State{meta: %{service_name: _, cluster_arn: _, region: _, nodes: _}} = state) do
    {:ok, reported_nodes} = get_nodes(state)

    nodes =
      reported_nodes
      |> MapSet.new()
      |> disconnect_nodes(state)
      |> connect_nodes(state)

    Process.send_after(self(), :load, polling_interval(state))
    put_in(state.meta.nodes, nodes)
  end

  defp load(%State{config: config, topology: topology, meta: meta} = state) do
    new_meta =
      with {:ok, %{cluster_arn: cluster_arn, task_arn: task_arn}} <- MetadataEndpoint.get(:v2),
           {:ok, region} <- AWS.region_from_arn(task_arn),
           opts <-
             config
             |> Enum.into(%{})
             |> Map.take([:access_key_id, :secret_access_key]),
           {:ok, service_name} <- ECS.service_name_from_task(region, cluster_arn, task_arn, opts) do
        %{
          cluster_arn: cluster_arn,
          nodes: MapSet.new([]),
          region: region,
          service_name: service_name,
          task_arn: task_arn
        }
      else
        {:error, {MetadataEndpoint, :get, {status, body}}} ->
          Cluster.Logger.warn(
            topology,
            "cannot query ECS Task Metadata Endpoint (#{status}): #{inspect(body)}"
          )

          meta

        {:error, {module, function}} ->
          Cluster.Logger.error(topology, "#{inspect({module, function})} failed!")
          meta

        {:error, {module, function, error}} ->
          Cluster.Logger.error(
            topology,
            "#{inspect({module, function})} failed!: #{inspect(error)}"
          )

          meta
      end

    Process.send_after(self(), :load, polling_interval(state))
    %{state | meta: new_meta}
  end

  defp disconnect_nodes(desired_nodes, state) do
    removed = MapSet.difference(state.meta.nodes, desired_nodes)

    state.topology
    |> Strategy.disconnect_nodes(state.disconnect, state.list_nodes, MapSet.to_list(removed))
    |> case do
      :ok ->
        desired_nodes

      {:error, bad_nodes} ->
        Enum.reduce(bad_nodes, desired_nodes, fn {n, _}, acc -> MapSet.put(acc, n) end)
    end
  end

  defp connect_nodes(desired_nodes, state) do
    added = MapSet.difference(desired_nodes, state.meta.nodes)

    state.topology
    |> Strategy.connect_nodes(state.connect, state.list_nodes, MapSet.to_list(added))
    |> case do
      :ok ->
        desired_nodes

      {:error, bad_nodes} ->
        Enum.reduce(bad_nodes, desired_nodes, fn {n, _}, acc -> MapSet.delete(acc, n) end)
    end
  end

  defp get_nodes(%State{
         config: config,
         meta: %{
           cluster_arn: cluster_arn,
           region: region,
           service_name: service_name,
           task_arn: current_task_arn
         }
       }) do
    opts =
      config
      |> Enum.into(%{})
      |> Map.take([:access_key_id, :secret_access_key])

    with {:ok, task_arns} <- ECS.list_task_arns(region, cluster_arn, service_name, opts),
         other_task_arns <- Enum.reject(task_arns, &(&1 == current_task_arn)),
         {:ok, tasks} <- ECS.describe_task_arns(region, cluster_arn, other_task_arns, opts) do
      nodes =
        for task <- tasks, do: :"#{service_name}@#{ECS.hostname_from_task(region, task, opts)}"

      {:ok, MapSet.new(nodes)}
    else
      {:error, _} = e -> e
    end
  end

  defp polling_interval(%State{config: config}) do
    Keyword.get(config, :polling_interval, @default_polling_interval)
  end
end
