defmodule ClusterECS.Strategy.MetadataTest do
  use ExUnit.Case, async: false
  import Tesla.Mock, only: [mock_global: 1, json: 1]
  alias Cluster.Strategy.State
  alias ClusterECS.{MetadataEndpoint, Strategy.Metadata}
  alias ClusterECS.Test.Factory

  test "start_link/1" do
    metadata_endpoint_url = MetadataEndpoint.url(:v2)
    ecs_url = "https://ecs.us-east-1.amazonaws.com/"
    %{taskArn: task_arn} = task = Factory.build(:task, %{service_name: "my_service"})

    mock_global(fn
      %{method: :get, url: ^metadata_endpoint_url} ->
        {:ok, json(%{TaskARN: task_arn, Cluster: Factory.build(:cluster_arn)})}

      %{body: body, headers: headers, method: :post, url: ^ecs_url} ->
        case Factory.aws_request_target(headers) do
          "DescribeTasks" ->
            case Jason.decode!(body) do
              %{"tasks" => []} -> {:ok, json(%{tasks: []})}
              %{"tasks" => [^task_arn]} -> {:ok, json(%{tasks: [task]})}
            end

          "ListTasks" ->
            payload = %{taskArns: [task_arn]}
            {:ok, json(payload)}
        end
    end)

    assert {:ok, pid} = Metadata.start_link([build_state()])
  end

  describe "handle_info/2" do
    test "before metadata - happy path" do
      region = Factory.build(:region)
      ecs_url = "https://ecs.#{region}.amazonaws.com/"
      metadata_endpoint_url = MetadataEndpoint.url(:v2)
      service_name = "my_service"
      cluster_arn = Factory.build(:cluster_arn, %{region: region})
      state = build_state()

      %{taskArn: task_arn} =
        task = Factory.build(:task, %{service_name: service_name, region: region})

      mock_global(fn
        %{method: :get, url: ^metadata_endpoint_url} ->
          payload = %{TaskARN: task_arn, Cluster: cluster_arn}
          {:ok, json(payload)}

        %{body: body, headers: headers, method: :post, url: ^ecs_url} ->
          case Factory.aws_request_target(headers) do
            "DescribeTasks" ->
              case Jason.decode!(body) do
                %{"tasks" => []} -> {:ok, json(%{tasks: []})}
                %{"tasks" => [^task_arn]} -> {:ok, json(%{tasks: [task]})}
              end
          end
      end)

      expected_state = %{
        state
        | meta: %{
            nodes: MapSet.new([]),
            cluster_arn: cluster_arn,
            region: region,
            service_name: service_name,
            task_arn: task_arn
          }
      }

      assert Metadata.handle_info(:load, state) == {:noreply, expected_state}
    end

    test "before metadata - metadata endpoint unavailable" do
      metadata_endpoint_url = MetadataEndpoint.url(:v2)
      state = build_state()
      mock_global(fn %{method: :get, url: ^metadata_endpoint_url} -> {:error, :econnrefused} end)
      assert Metadata.handle_info(:load, state) == {:noreply, state}
    end

    test "after metadata - happy path 1 node" do
      region = Factory.build(:region)
      service_name = "my_service"
      cluster_arn = Factory.build(:cluster_arn, %{region: region})
      ecs_url = "https://ecs.us-east-1.amazonaws.com/"

      %{taskArn: task_arn} =
        task = Factory.build(:task, %{service_name: service_name, region: region})

      mock_global(fn
        %{body: body, headers: headers, method: :post, url: ^ecs_url} ->
          case Factory.aws_request_target(headers) do
            "DescribeTasks" ->
              case Jason.decode!(body) do
                %{"tasks" => []} ->
                  raise "fail - describe_task_arns/4 should not be called with 0 tasks"

                %{"tasks" => [^task_arn]} ->
                  {:ok, json(%{tasks: [task]})}
              end

            "ListTasks" ->
              payload = %{taskArns: [task_arn]}
              {:ok, json(payload)}
          end
      end)

      expected_state = %{
        build_state()
        | meta: %{
            nodes: MapSet.new([]),
            cluster_arn: cluster_arn,
            region: region,
            service_name: service_name,
            task_arn: task_arn
          }
      }

      assert Metadata.handle_info(:load, expected_state) == {:noreply, expected_state}
    end
  end

  test "init/1" do
    state = build_state()
    assert {:ok, ^state} = Metadata.init([state])
    assert_receive :load
  end

  defp build_state() do
    %State{
      topology: :topology_name,
      connect: {:net_kernel, :connect_node, []},
      disconnect: {:erlang, :disconnect_mfa, []},
      list_nodes: {:erlang, :nodes, [:connected]},
      config: []
    }
  end
end
