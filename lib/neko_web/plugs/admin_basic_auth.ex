defmodule NekoWeb.Plugs.AdminBasicAuth do
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    Plug.BasicAuth.basic_auth(
      conn,
      Application.fetch_env!(:neko, :admin_basic_auth)
    )
  end
end
