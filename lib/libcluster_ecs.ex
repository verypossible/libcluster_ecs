defmodule LibclusterECS do
  @moduledoc """
  Documentation for LibclusterECS.
  """

  use GenServer
  use Cluster.Strategy
  alias Cluster.Strategy
  alias Cluster.Strategy.State

  @impl Strategy
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(%State{} = state) do
    new_state = Map.put(state, :meta, %{names: MapSet.new()})

    {:ok, new_state}
  end
end
