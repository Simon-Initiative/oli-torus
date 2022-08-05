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

  # Returns the Oban configuration for the application.
  # It makes sure that only one node in the cluster has the part_mapping_refresh queue configured.
  defp oban_config do
    env_oban_config = Application.fetch_env!(:oli, Oban)

    # Get the current oban config in all other nodes in the cluster
    nodes_config = :erpc.multicall(Node.list(), Oli.Application, :current_oban_config, [])

    # Check if a node already has the part_mapping_refresh queue configured
    pm_refresh_already_setup? = Enum.any?(nodes_config, fn
      {:ok, config} ->
        config[:queues][:part_mapping_refresh]

      _ -> false
    end)

    if pm_refresh_already_setup? do
      # If the part_mapping_refresh queue is already setup somewhere else, we don't want to setup it in this node.
      queues_without_pm = Keyword.delete(env_oban_config[:queues], :part_mapping_refresh)
      Keyword.put(env_oban_config, :queues, queues_without_pm)
    else
      # If the part_mapping_refresh queue is not already setup, we need to setup it.
      # We'll use the default queue configuration, but with the part_mapping_refresh queue configured.
      env_oban_config
    end
  end

  def current_oban_config do
    Application.fetch_env!(:oli, Oban)
  end

  # Only add in the NodeJS config if it is being used for either the rule evaluator or the
  # variable substitution transformer
  defp maybe_node_js_config do
    if Application.fetch_env!(:oli, :rule_evaluator)[:dispatcher] ==
         Oli.Delivery.Attempts.ActivityLifecycle.NodeEvaluator or
         Application.fetch_env!(:oli, :variable_substitution)[:dispatcher] ==
           Oli.Activities.Transformers.VariableSubstitution.NodeImpl do
      [
        %{
          id: NodeJS,
          start:
            {NodeJS, :start_link,
             [
               [
                 path: "#{:code.priv_dir(:oli)}/node",
                 pool_size: Application.fetch_env!(:oli, :node_js_pool_size)
               ]
             ]}
        }
      ]
    else
      []
    end
  end
end
