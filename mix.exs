defmodule LibclusterECS.MixProject do
  use Mix.Project

  def project do
    [
      app: :libcluster_ecs,
      deps: deps(),
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: "0.1.0"
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [
      {:excoveralls, "~> 0.0"},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_ecs, "~> 0.0"},
      {:faker, "~> 0.0"},
      {:hackney, "~> 1.0"},
      {:jason, "~> 1.0"},
      {:libcluster, "~> 3.0"},
      {:mix_test_watch, "~> 0.0", only: :dev, runtime: false},
      {:tesla, "~> 1.0"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_), do: ["lib", "web"]
end
