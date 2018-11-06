defmodule ClusterECS.MetadataEndpoint do
  @moduledoc """
  A wrapper around the Amazon ECS Task Metadata Endpoint.

  Refer to
  (the docs)[https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-metadata-endpoint.html].
  for more information about what dictates which versions of the endpoint are available to your
  task.
  """

  alias Tesla.Env

  @typedoc "Possible supported versions of the Amazon ECS Task Metadata Endpoint"
  @type version :: :v2

  def url(:v2), do: "http://169.254.170.2/v2/metadata"

  @doc """
  Hits `version` of the metadata API returning a strict subset of the results.
  """
  @spec get(version()) ::
          {:ok, %{task_arn: ECS.task_arn(), cluster_arn: ECS.cluster_arn()}}
          | {:error,
             {Env.status(), Env.body()}
             | any()}
  def get(:v2 = version) do
    version
    |> url()
    |> Tesla.get()
    |> parse_response(%{function: :get, version: version})
  end

  defp parse_response({:ok, %Env{status: 200, body: body}}, %{version: :v2}) do
    %{"TaskARN" => task_arn, "Cluster" => cluster_arn} = Jason.decode!(body)
    {:ok, %{task_arn: task_arn, cluster_arn: cluster_arn}}
  end

  defp parse_response({:ok, %Env{status: status, body: body}}, %{function: function, version: :v2}) do
    {:error, {__MODULE__, function, {status, body}}}
  end

  defp parse_response({:error, error}, %{function: function, version: :v2}) do
    {:error, {__MODULE__, function, error}}
  end
end
