defmodule Neko.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NekoWeb.Telemetry,
      Neko.Repo,
      {DNSCluster, query: Application.get_env(:neko, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Neko.PubSub},
      # Start a worker by calling: Neko.Worker.start_link(arg)
      # {Neko.Worker, arg},
      # Start to serve requests, typically the last entry
      NekoWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Neko.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NekoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
