defmodule Oli.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # Install the logger truncator
    Oli.LoggerTruncator.init()

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
        {Cachex, name: :page_content_cache},

        # Starts Cachex to store vr user agents
        Oli.VrLookupCache,

        # Starts Cachex to store section info
        Oli.Delivery.Sections.SectionCache,

        # a supervisor which can be used to dynamically supervise tasks
        {Task.Supervisor, name: Oli.TaskSupervisor}
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

  defp log_incomplete_requests?() do
    Application.fetch_env!(:oli, :log_incomplete_requests)
  end
end
