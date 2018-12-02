use Mix.Config
alias Tesla.{Adapter.Hackney, Mock}
alias ClusterECS.Test.TeslaWrapper

# TODO: Expect HTTP adapter to be configured by parent, default to httpc, document this, remove
# this configuration.
config :tesla, adapter: Hackney

if Mix.env() == :dev, do: config(:mix_test_watch, clear: true)

if Mix.env() == :test do
  config :tesla, adapter: Mock

  config :ex_aws,
    access_key_id: "test_key",
    secret_access_key: "test_secret",
    http_client: TeslaWrapper
end
