defmodule Oli.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # Install the logger truncator
    Oli.LoggerTruncator.init()
    maybe_add_appsignal_logger_backend()

    # List all child processes to be supervised
    children =
      [
        Oli.Vault,

        # libcluster config
        {Cluster.Supervisor,
         [Application.fetch_env!(:libcluster, :topologies), [name: Oli.ClusterSupervisor]]},

        # Start Phoenix PubSub
        {Phoenix.PubSub, name: Oli.PubSub},

        # Start the Ecto repository
        Oli.Repo,

        # Starts telemetry
        OliWeb.Telemetry,
        Oli.Analytics.XAPI.UploadPipeline,

        # Start the endpoint when the application starts
        OliWeb.Endpoint,

        # Start the Oban background job processor
        {Oban, oban_config()},

        # Starts the presence tracker
        OliWeb.Presence,

        # Starts the nonce cleanup task, call Lti_1p3.Nonces.cleanup_nonce_store/0 at 1:01 UTC every day
        %{
          id: "cleanup_nonce_store_daily",
          start: {SchedEx, :run_every, [Lti_1p3.Nonces, :cleanup_nonce_store, [], "1 1 * * *"]}
        },
        # Starts the login hint cleanup task
        %{
          id: "cleanup_login_hint_store_daily",
          start:
            {SchedEx, :run_every,
             [Lti_1p3.Platform.LoginHints, :cleanup_login_hint_store, [], "1 1 * * *"]}
        },
        # Starts the publication diff cleanup task
        %{
          id: "cleanup_publication_diffs_daily",
          start:
            {SchedEx, :run_every,
             [Oli.Publishing.Publications.DiffAgent, :cleanup_diff_store, [], "1 1 * * *"]}
        },

        # Starts the publication diff agent store
        Oli.Publishing.Publications.DiffAgent,
        Oli.Delivery.Attempts.PartAttemptCleaner,

        # Starts Cachex to store page content info
        Oli.Delivery.DistributedDepotCoordinator,
        Oli.Delivery.DepotWarmer,
        Supervisor.child_spec({Cachex, name: :page_content_cache}, id: :page_content_cache),
        Supervisor.child_spec(
          {Cachex, name: :feature_flag_stage, limit: 200_000, policy: Cachex.Policy.LRW},
          id: :feature_flag_stage_cache
        ),
        Supervisor.child_spec(
          {Cachex, name: :feature_flag_cohorts, limit: 200_000, policy: Cachex.Policy.LRW},
          id: :feature_flag_cohort_cache
        ),

        # Cache assistant replies for AI page triggers (per-node, capped)
        Supervisor.child_spec(
          {
            Cachex,
            # Keep at most 10k entries, evict oldest first
            name: :ai_page_trigger_reply_cache, limit: 10_000, policy: Cachex.Policy.LRW
          },
          id: :ai_page_trigger_reply_cache
        ),

        # Starts Cachex to store vr user agents
        Oli.VrLookupCache,

        # Starts Cachex to store section info
        Oli.Delivery.Sections.SectionCache,
        Oli.ScopedFeatureFlags.CacheSubscriber,

        # Starts the LTI 1.3 keyset cache for caching platform public keys
        Oli.Lti.KeysetCache,

        # a supervisor which can be used to dynamically supervise tasks
        {Task.Supervisor, name: Oli.TaskSupervisor},

        # GenAI hackney connection pool
        Oli.GenAI.HackneyPool,

        # MCP (Model Context Protocol) server for AI agents
        Anubis.Server.Registry,

        # AI Agent system
        Oli.GenAI.Agent.Registry,
        Oli.GenAI.Agent.ToolBroker,
        Oli.GenAI.Agent.RunSupervisor,
        {Oli.MCP.Server, transport: :streamable_http}
      ] ++ maybe_node_js_config()

    if log_incomplete_requests?() do
      :ok =
        :telemetry.attach(
          "cowboy-request-handler",
          [:cowboy, :request, :early_error],
          &Oli.LogIncompleteRequestHandler.handle_event/4,
          nil
        )
    end

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
    Oban.Telemetry.attach_default_logger()

    Application.fetch_env!(:oli, Oban)
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

  defp maybe_add_appsignal_logger_backend do
    case Application.get_env(:oli, :appsignal_logger_backend) do
      nil ->
        :ok

      opts when is_list(opts) ->
        _ = LoggerBackends.add({Appsignal.Logger.Backend, opts})
        :ok

      opts ->
        _ = LoggerBackends.add({Appsignal.Logger.Backend, List.wrap(opts)})
        :ok
    end
  end

  defp log_incomplete_requests?() do
    Application.fetch_env!(:oli, :log_incomplete_requests)
  end
end
