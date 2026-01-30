defmodule Spotlight.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SpotlightWeb.Telemetry,
      Spotlight.Repo,
      {DNSCluster, query: Application.get_env(:spotlight, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Spotlight.PubSub},
      SpotlightWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Spotlight.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    SpotlightWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
