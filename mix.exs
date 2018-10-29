defmodule LibclusterECS.MixProject do
  use Mix.Project

  def project do
    [
      app: :libcluster_ecs,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:libcluster, "~> 3.0"},
      {:mix_test_watch, "~> 0.9", only: :dev, runtime: false}
    ]
  end
end
