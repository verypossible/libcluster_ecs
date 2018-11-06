defmodule ClusterECS.MetadataEndpointTest do
  use ExUnit.Case
  import Tesla.Mock
  alias ClusterECS.{MetadataEndpoint, Test.Factory}
  alias Tesla.Env

  doctest MetadataEndpoint

  @url_v2 MetadataEndpoint.url(:v2)

  describe "get/1" do
    test "success" do
      task_arn = Factory.build(:task_arn)
      cluster_arn = Factory.build(:cluster_arn)

      mock(fn %{method: :get, url: @url_v2} ->
        payload = %{
          "TaskARN" => task_arn,
          "Cluster" => cluster_arn,
          "Containers" => [
            %{Type: "CNI_PAUSE"},
            %{Type: "NORMAL", Networks: [%{IPv4Addresses: ["10.0.2.106"]}]}
          ]
        }

        {:ok, json(payload)}
      end)

      assert MetadataEndpoint.get(:v2) === {:ok, %{task_arn: task_arn, cluster_arn: cluster_arn}}
    end

    test "non-200" do
      status = 400
      mock(fn %{method: :get, url: @url_v2} -> {:ok, %Env{status: status}} end)
      assert {:error, {MetadataEndpoint, :get, {^status, _body}}} = MetadataEndpoint.get(:v2)
    end

    test "failure" do
      error = :some_error
      mock(fn %{method: :get, url: @url_v2} -> {:error, error} end)
      assert MetadataEndpoint.get(:v2) === {:error, {MetadataEndpoint, :get, error}}
    end
  end
end
