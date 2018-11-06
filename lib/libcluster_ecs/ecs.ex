defmodule ClusterECS.ECS do
  @moduledoc """
  A wrapper around (ExAws.ECS)[https://hex.pm/packages/ex_aws_ecs].
  """

  @typep cluster_arn :: String.t()
  @typep group :: String.t()
  @typep opts :: [{:max_attempts, pos_integer()}]
  @typep region :: String.t()
  @typep service_name :: String.t()
  @typep task :: %{
           containers: [
             %{task_arn: task_arn(), network_interfaces: [%{private_ipv4_address: String.t()}]}
           ],
           group: group(),
           task_arn: task_arn()
         }
  @typep task_arn :: String.t()

  @spec service_name_from_task(region(), cluster_arn(), task_arn(), opts) ::
          {:ok, service_name()}
          | {:error, {__MODULE__, :service_name_from_task, any()}}
  def service_name_from_task(region, cluster_arn, task_arn, opts \\ %{}) do
    region
    |> describe_task_arns(cluster_arn, [task_arn], opts)
    |> case do
      {:ok, [%{group: group}]} ->
        [_, service_name] = String.split(group, ":")
        {:ok, service_name}

      {:error, {m, f, e}} ->
        {:error, {m, List.flatten([:service_name_from_task, f]), e}}
    end
  end

  @spec list_task_arns(region(), cluster_arn(), service_name(), opts()) ::
          {:ok, [task_arn()]}
          | {:error, {__MODULE__, :list_task_arns, any()}}
  def list_task_arns(region, cluster_arn, service_name, opts \\ %{}) do
    ExAws.ECS.list_tasks(cluster_arn, service_name: service_name)
    |> ExAws.request(Enum.into([json_codec: Jason, region: region], opts))
    |> parse_response(:list_task_arns)
    |> case do
      {:ok, %{"taskArns" => task_arns}} -> {:ok, task_arns}
      {:error, _} = e -> e
    end
  end

  @spec describe_task_arns(region(), cluster_arn(), [task_arn()], opts()) ::
          {:ok, [task()]}
          | {:error, {__MODULE__, :list_task_arns, any()}}
  def describe_task_arns(region, cluster_arn, task_arns, opts \\ %{}) do
    cluster_arn
    |> ExAws.ECS.describe_tasks(task_arns)
    |> ExAws.request(Enum.into([json_codec: Jason, region: region], opts))
    |> parse_response(:describe_task_arns)
    |> case do
      {:ok, %{"tasks" => tasks}} -> {:ok, map_tasks(tasks)}
      {:error, _} = e -> e
    end
  end

  @doc """
  See https://docs.aws.amazon.com/vpc/latest/userguide/vpc-dns.html#vpc-dns-hostnames
  """
  @spec hostname_from_task(region(), task()) :: String.t()
  def hostname_from_task(region, %{containers: containers, task_arn: task_arn}) do
    %{network_interfaces: [%{private_ipv4_address: ip} | _]} =
      Enum.find(containers, &(&1.task_arn == task_arn))

    case region do
      "us-east-1" -> "ip-#{ip}.ec2.internal"
      region -> "ip-#{ip}.#{region}.compute.internal"
    end
  end

  defp map_tasks(ts), do: for(t <- ts, do: map_task(t))

  defp map_task(%{"containers" => cs, "taskArn" => ta, "group" => group}) do
    %{containers: map_containers(cs), task_arn: ta, group: group}
  end

  defp map_containers(cs), do: for(c <- cs, do: map_container(c))

  defp map_container(%{"taskArn" => ta, "networkInterfaces" => nis}) do
    %{task_arn: ta, network_interfaces: map_network_interfaces(nis)}
  end

  defp map_network_interfaces(nis), do: for(ni <- nis, do: map_network_interface(ni))

  defp map_network_interface(%{"privateIpv4Address" => ip}), do: %{private_ipv4_address: ip}

  defp parse_response(tagged_ret, function)

  defp parse_response({:ok, _} = ret, _), do: ret

  defp parse_response({:error, e}, f) do
    {:error, {__MODULE__, f, e}}
  end
end
