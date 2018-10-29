defmodule LibclusterECSTest do
  use ExUnit.Case
  doctest LibclusterECS

  alias Cluster.Strategy.State

  test "start_link/1" do
    assert {:ok, pid} = LibclusterECS.start_link(%State{})
    assert :ok = GenServer.stop(pid)
  end

  test "init/1" do
    blank_state = build_state()
    assert {:ok, ^blank_state} = LibclusterECS.init(%State{})
  end

  defp build_state(names \\ []), do: %State{meta: %{names: MapSet.new(names)}}
end
