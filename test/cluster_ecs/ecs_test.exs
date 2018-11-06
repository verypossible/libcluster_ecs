defmodule ClusterECS.ECSTest do
  use ExUnit.Case
  import Tesla.Mock, only: [mock_global: 1, json: 1, json: 2]
  alias ClusterECS.{ECS, Test.Factory}

  doctest ECS, import: true

  setup do
    region = Factory.build(:region)
    service_name = Factory.build(:service_name)
    task = Factory.build(:task, %{region: region, service_name: service_name})

    %{
      cluster_arn: Factory.build(:cluster_arn, %{region: region}),
      ecs_url: "https://ecs.#{region}.amazonaws.com/",
      region: region,
      service_name: service_name,
      task: task,
      task_arn: task.taskArn
    }
  end

  describe "service_from_task/4" do
    test "success", %{
      cluster_arn: cluster_arn,
      ecs_url: ecs_url,
      region: region,
      service_name: service_name,
      task: task,
      task_arn: task_arn
    } do
      mock_global(fn %{method: :post, url: ^ecs_url} -> json(%{tasks: [task]}) end)

      assert ECS.service_name_from_task(region, cluster_arn, task_arn) === {:ok, service_name}
    end

    test "failure", %{
      cluster_arn: cluster_arn,
      ecs_url: ecs_url,
      region: region,
      task_arn: task_arn
    } do
      %{body: body, status: status} = resp = json(%{red: :blue}, status: 500)
      mock_global(fn %{method: :post, url: ^ecs_url} -> resp end)
      error = {:http_error, status, body}

      assert ECS.service_name_from_task(region, cluster_arn, task_arn, %{
               retries: %{max_attempts: 1}
             }) === {:error, {ECS, [:service_name_from_task, :describe_task_arns], error}}
    end
  end

  describe "list_task_arns/3" do
    test "success", %{
      cluster_arn: cluster_arn,
      ecs_url: ecs_url,
      region: region,
      task_arn: task_arn
    } do
      task_arns = [task_arn, Factory.build(:task_arn)]

      mock_global(fn
        %{headers: headers, method: :post, url: ^ecs_url} ->
          assert Factory.aws_request_target(headers) === "ListTasks"
          json(%{taskArns: task_arns})
      end)

      assert ECS.list_task_arns(region, cluster_arn, "my_service") === {:ok, task_arns}
    end

    test "failure", %{
      cluster_arn: cluster_arn,
      ecs_url: ecs_url,
      region: region,
      service_name: service_name
    } do
      mock_global(fn
        %{headers: headers, method: :post, url: ^ecs_url} ->
          assert Factory.aws_request_target(headers) === "ListTasks"
          json(%{}, status: 500)
      end)

      assert {:error, {ECS, :list_task_arns, {:http_error, 500, _}}} =
               ECS.list_task_arns(region, cluster_arn, service_name, %{
                 retries: %{max_attempts: 1}
               })
    end
  end
end
