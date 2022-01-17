defmodule Oli.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children =
      [
        # libcluster config
        {Cluster.Supervisor,
         [Application.fetch_env!(:libcluster, :topologies), [name: Oli.ClusterSupervisor]]},

        # Start Phoenix PubSub
        {Phoenix.PubSub, name: Oli.PubSub},

        # Start the Ecto repository
        Oli.Repo,

        # Starts telemetry
        OliWeb.Telemetry,

        # Start the endpoint when the application starts
        OliWeb.Endpoint,

        # Start the Oban background job processor
        {Oban, oban_config()},

        # Start the Pow MnesiaCache to persist session across multiple servers
        Oli.MnesiaClusterSupervisor,

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
      ] ++ maybe_node_js_config()

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

  # Only add in the NodeJS config if that is indeed the selected rule engine evaluator
  defp maybe_node_js_config do
    case Application.fetch_env!(:oli, :rule_evaluator)[:dispatcher] do
      Oli.Delivery.Attempts.ActivityLifecycle.NodeEvaluator ->
        [
          %{
            id: NodeJS,
            start:
              {NodeJS, :start_link,
               [
                 [
                   path: "#{:code.priv_dir(:oli)}/node",
                   pool_size: Application.fetch_env!(:oli, :rule_evaluator)[:node_js_pool_size]
                 ]
               ]}
          }
        ]

      _ ->
        []
    end
  end
end
