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

      # Starts the nonce cleanup task, call Oli.Lti_1p3.Nonces.cleanup_nonce_store/0 at 1:01 UTC every day
      %{ id: "cleanup_nonce_store_daily", start: {SchedEx, :run_every, [Oli.Lti_1p3.Nonces, :cleanup_nonce_store, [], "1 1 * * *"]} },
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
end
