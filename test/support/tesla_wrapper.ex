defmodule ClusterECS.Test.TeslaWrapper do
  @moduledoc false

  alias ExAws.Request.HttpClient
  alias Tesla.{Env, Mock}

  @behaviour HttpClient

  @impl HttpClient
  def request(method, url, body, headers, opts) do
    %Env{status: status, body: body} =
      Tesla.request!(Tesla.client([], Mock),
        method: method,
        url: url,
        body: body,
        headers: headers,
        opts: opts
      )

    {:ok, %{status_code: status, body: body}}
  end
end
