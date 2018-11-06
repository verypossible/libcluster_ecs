defmodule ClusterECS.AWS do
  @moduledoc """
  Utility functions relative to AWS.
  """

  @doc """
      iex> region_from_arn("arn:partition:service:region:account-id:resourcetype/resource/qualifier")
      {:ok, "region"}

      iex> region_from_arn("arn:partition:service:region")
      {:ok, "region"}

      iex> region_from_arn("arn:partition:service")
      {:error, {ClusterECS.AWS, :region_from_arn}}

      iex> region_from_arn("")
      {:error, {ClusterECS.AWS, :region_from_arn}}
  """
  def region_from_arn(arn) do
    arn
    |> String.split(":")
    |> Enum.at(3)
    |> case do
      nil -> {:error, {__MODULE__, :region_from_arn}}
      region -> {:ok, region}
    end
  end
end
