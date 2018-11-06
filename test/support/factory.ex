defmodule ClusterECS.Test.Factory do
  @moduledoc false

  alias Faker.{Internet, Lorem, UUID}

  def build(id, opts \\ %{})

  def build(:task, opts) do
    task_arn = resolve(opts, :task_arn)
    service_name = resolve(opts, :service_name)

    %{
      taskArn: task_arn,
      containers: [
        %{
          taskArn: task_arn,
          networkInterfaces: [%{privateIpv4Address: build(:ipv4)}]
        }
      ],
      group: build(:task_group_name, %{service_name: service_name})
    }
  end

  def build(:ipv4, _opts), do: Internet.ip_v4_address()

  def build(:task_arn, opts) do
    build(:arn, Map.merge(%{resource_type: "task"}, opts))
  end

  def build(:cluster_arn, opts) do
    build(:arn, Map.merge(%{resource_type: "cluster"}, opts))
  end

  def build(:arn, opts) do
    region = Map.get_lazy(opts, :region, fn -> build(:region) end)
    resource_type = Map.get_lazy(opts, :resource_type, fn -> build(:resource_type) end)
    resource = UUID.v4()
    "arn:partition:service:#{region}:account-id:#{resource_type}/#{resource}/qualifier"
  end

  def build(:resource_type, _opts) do
    Enum.random(["cluster", "task"])
  end

  def build(:region, _opts) do
    Enum.random(["us-east-1"])
  end

  def build(:service_name, _opts), do: "#{Lorem.characters(1..255)}"

  def build(:task_group_name, opts) do
    case opts do
      %{service_name: service_name} -> "service:#{service_name}"
    end
  end

  def aws_request_target(headers) do
    [_, target] =
      headers
      |> List.keyfind("x-amz-target", 0)
      |> elem(1)
      |> String.split(".")

    target
  end

  defp resolve(opts, key, pass_opts \\ true) do
    opts = if pass_opts, do: opts, else: %{}
    Map.get_lazy(opts, key, fn -> build(key, opts) end)
  end
end
