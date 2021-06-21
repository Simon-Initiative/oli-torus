defmodule Oli.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {Phoenix.PubSub, name: Oli.PubSub},

      # Start the Ecto repository
      Oli.Repo,

      # Starts telemetry
      OliWeb.Telemetry,

      # Start the endpoint when the application starts
      OliWeb.Endpoint,

      # Start the Oban background job processor
      {Oban, oban_config()},

      # Start the Pow MnesiaCache to persist session across server restarts
      Pow.Store.Backend.MnesiaCache,

      # Start the NodeJS bridge
      %{
        id: NodeJS,
        start:
          {NodeJS, :start_link,
           [[path: "./priv/node", pool_size: Application.fetch_env!(:oli, :node_js_pool_size)]]}
      },

      # Starts the nonce cleanup task, call Lti_1p3.Nonces.cleanup_nonce_store/0 at 1:01 UTC every day
      %{
        id: "cleanup_nonce_store_daily",
        start: {SchedEx, :run_every, [Lti_1p3.Nonces, :cleanup_nonce_store, [], "1 1 * * *"]}
      },
      %{
        id: "cleanup_login_hint_store_daily",
        start:
          {SchedEx, :run_every,
           [Lti_1p3.Platform.LoginHints, :cleanup_login_hint_store, [], "1 1 * * *"]}
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Oli.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    OliWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp oban_config do
    Application.fetch_env!(:oli, Oban)
  end
end
