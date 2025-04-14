# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# NOTICE: All configurations defined here are set at COMPILE time. For runtime
# configurations, use `config/runtime.exs`. These configurations can also serve
# as defaults and be overridden by `config/runtime.exs` as well.
#
# If you are unsure where a configuration belongs, it likely belongs in `config/runtime.exs`.
#
# This configuration file is loaded before any dependency and is restricted to this project.

# General application configuration
import Config

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

world_universities_and_domains_json =
  case File.read("./priv/data/world_universities_and_domains.json") do
    {:ok, body} ->
      body

    _ ->
      "[]"
  end

default_sha = if Mix.env() == :dev, do: "DEV BUILD", else: "UNKNOWN BUILD"

get_env_as_boolean = fn key, default ->
  System.get_env(key, default)
  |> String.downcase()
  |> String.trim()
  |> case do
    "true" -> true
    _ -> false
  end
end

config :oli,
  instructor_dashboard_details: get_env_as_boolean.("INSTRUCTOR_DASHBOARD_DETAILS", "true"),
  depot_coordinator: Oli.Delivery.DistributedDepotCoordinator,
  depot_warmer_days_lookback: System.get_env("DEPOT_WARMER_DAYS_LOOKBACK", "5"),
  depot_warmer_max_number_of_entries: System.get_env("DEPOT_WARMER_MAX_NUMBER_OF_ENTRIES", "0"),
  load_testing_mode: false,
  problematic_query_detection: false,
  problematic_query_cost_threshold: 150,
  ecto_repos: [Oli.Repo],
  build: %{
    version: Mix.Project.config()[:version],
    sha: System.get_env("SHA", default_sha),
    date: DateTime.now!("Etc/UTC"),
    env: Mix.env()
  },
  local_activity_manifests:
    Path.wildcard(File.cwd!() <> "/assets/src/components/activities/*/manifest.json")
    |> Enum.map(&File.read!/1),
  local_part_component_manifests:
    Path.wildcard(File.cwd!() <> "/assets/src/components/parts/*/manifest.json")
    |> Enum.map(&File.read!/1),
  email_from_name: System.get_env("EMAIL_FROM_NAME", "OLI Torus"),
  email_from_address: System.get_env("EMAIL_FROM_ADDRESS", "admin@example.edu"),
  email_reply_to: System.get_env("EMAIL_REPLY_TO", "admin@example.edu"),
  world_universities_and_domains_json: world_universities_and_domains_json,
  branding: [
    name: System.get_env("BRANDING_NAME", "OLI Torus"),
    logo: System.get_env("BRANDING_LOGO", "/branding/prod/oli_torus_logo.png"),
    logo_dark:
      System.get_env(
        "BRANDING_LOGO_DARK",
        System.get_env("BRANDING_LOGO", "/branding/prod/oli_torus_logo_dark.png")
      ),
    favicons: System.get_env("BRANDING_FAVICONS_DIR", "/branding/prod/favicons")
  ],
  payment_provider: System.get_env("PAYMENT_PROVIDER", "none"),
  node_js_pool_size: String.to_integer(System.get_env("NODE_JS_POOL_SIZE", "2")),
  screen_idle_timeout_in_seconds:
    String.to_integer(System.get_env("SCREEN_IDLE_TIMEOUT_IN_SECONDS", "1800")),
  log_incomplete_requests: true

config :oli, :dataset_generation,
  enabled: System.get_env("EMR_DATASET_ENABLED", "false") == "true",
  emr_application_name: System.get_env("EMR_DATASET_APPLICATION_NAME", "csv_job"),
  execution_role:
    System.get_env(
      "EMR_DATASET_EXECUTION_ROLE",
      "arn:aws:iam::123456789012:role/service-role/EMR_DefaultRole"
    ),
  entry_point: System.get_env("EMR_DATASET_ENTRY_POINT", "s3://analyticsjobs/job.py"),
  log_uri: System.get_env("EMR_DATASET_LOG_URI", "s3://analyticsjobs/logs"),
  context_bucket: System.get_env("EMR_DATASET_CONTEXT_BUCKET", "torus-datasets-prod"),
  source_bucket: System.get_env("EMR_DATASET_SOURCE_BUCKET", "torus-xapi-prod"),
  spark_submit_parameters:
    System.get_env(
      "EMR_DATASET_SPARK_SUBMIT_PARAMETERS",
      "--conf spark.archives=s3://analyticsjobs/dataset.zip#dataset --py-files s3://analyticsjobs/dataset.zip --conf spark.executor.memory=2G --conf spark.executor.cores=2"
    )

config :oli, :xapi_upload_pipeline,
  producer_module: Oli.Analytics.XAPI.QueueProducer,
  uploader_module: Oli.Analytics.XAPI.Uploader

rule_evaluator_provider =
  case System.get_env("RULE_EVALUATOR_PROVIDER") do
    nil -> Oli.Delivery.Attempts.ActivityLifecycle.NodeEvaluator
    provider -> Module.concat([Oli, Delivery, Attempts, ActivityLifecycle, provider])
  end

config :oli, :rule_evaluator,
  dispatcher: rule_evaluator_provider,
  aws_fn_name: System.get_env("EVAL_LAMBDA_FN_NAME", "rules"),
  aws_region: System.get_env("EVAL_LAMBDA_REGION", "us-east-1")

variable_substitution_provider =
  case System.get_env("VARIABLE_SUBSTITUTION_PROVIDER") do
    nil -> Oli.Activities.Transformers.VariableSubstitution.RestImpl
    provider -> Module.concat([Oli, Activities, Transformers, VariableSubstitution, provider])
  end

config :oli, :variable_substitution,
  dispatcher: variable_substitution_provider,
  aws_fn_name: System.get_env("VARIABLE_SUBSTITUTION_LAMBDA_FN_NAME", "eval"),
  aws_region: System.get_env("VARIABLE_SUBSTITUTION_LAMBDA_REGION", "us-east-1"),
  rest_endpoint_url:
    System.get_env("VARIABLE_SUBSTITUTION_REST_ENDPOINT_URL", "http://localhost:8000/sandbox")

default_description = """
The Open Learning Initiative enables research and experimentation with all aspects of the learning experience.
As a leader in higher education's innovation of online learning, we're a growing research and production project exploring effective approaches since the early 2000s.
"""

config :oli, :vendor_property,
  workspace_logo:
    System.get_env("VENDOR_PROPERTY_WORKSPACE_LOGO", "/branding/prod/oli_torus_icon.png"),
  product_full_name:
    System.get_env("VENDOR_PROPERTY_PRODUCT_FULL_NAME", "Open Learning Initiative"),
  product_short_name: System.get_env("VENDOR_PROPERTY_PRODUCT_SHORT_NAME", "OLI Torus"),
  product_description:
    System.get_env(
      "VENDOR_PROPERTY_PRODUCT_DESCRIPTION",
      default_description
    ),
  product_learn_more_link:
    System.get_env("VENDOR_PROPERTY_PRODUCT_LEARN_MORE_LINK", "https://oli.cmu.edu"),
  company_name: System.get_env("VENDOR_PROPERTY_COMPANY_NAME", "Carnegie Mellon University"),
  company_address:
    System.get_env(
      "VENDOR_PROPERTY_COMPANY_ADDRESS",
      "5000 Forbes Ave, Pittsburgh, PA 15213 US"
    ),
  support_email: System.get_env("VENDOR_PROPERTY_SUPPORT_EMAIL"),
  faq_url:
    System.get_env(
      "VENDOR_PROPERTY_FAQ_URL",
      "https://olihelp.zohodesk.com/portal/en/kb/articles/frqu"
    )

config :oli, :stripe_provider,
  public_secret: System.get_env("STRIPE_PUBLIC_SECRET"),
  private_secret: System.get_env("STRIPE_PRIVATE_SECRET")

config :oli, :cashnet_provider,
  cashnet_store: System.get_env("CASHNET_STORE"),
  cashnet_checkout_url: System.get_env("CASHNET_CHECKOUT_URL"),
  cashnet_client: System.get_env("CASHNET_CLIENT"),
  cashnet_gl_number: System.get_env("CASHNET_GL_NUMBER")

# Configure database
config :oli, Oli.Repo,
  migration_timestamps: [type: :timestamptz],
  types: Oli.PostgrexTypes

# Config adapter for refreshing part_mapping
config :oli, Oli.Publishing, refresh_adapter: Oli.Publishing.PartMappingRefreshAsync
config :oli, :lti_access_token_provider, provider: Oli.Lti.AccessTokenLibrary

config :oli, :upgrade_experiment_provider,
  url: System.get_env("UPGRADE_EXPERIMENT_PROVIDER_URL"),
  user_url: System.get_env("UPGRADE_EXPERIMENT_USER_URL"),
  api_token: System.get_env("UPGRADE_EXPERIMENT_PROVIDER_API_TOKEN")

# Configures the endpoint
config :oli, OliWeb.Endpoint,
  live_view: [signing_salt: System.get_env("LIVE_VIEW_SALT", "LIVE_VIEW_SALT")],
  url: [host: "localhost"],
  secret_key_base: "GE9cpXBwVXNaplyUCYbIWqERmC/OlcR5iVMwLX9/W7gzQRxkD1ETjda9E0jW/BW1",
  render_errors: [
    accepts: ~w(html json),
    root_layout: {OliWeb.LayoutView, :error},
    view: OliWeb.ErrorView
  ],
  pubsub_server: Oli.PubSub

config :oli, Oban,
  repo: Oli.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {
      Oban.Plugins.Cron,
      crontab: [
        {"*/2 * * * *", OliWeb.DatasetStatusPoller, queue: :default}
      ]
    }
  ],
  queues: [
    default: 10,
    snapshots: 20,
    embeddings: 1,
    selections: 2,
    updates: 10,
    grades: 30,
    auto_submit: 3,
    project_export: 3,
    analytics_export: 3,
    datashop_export: 3,
    objectives: 3,
    mailer: 10,
    certificate_pdf: 3,
    certificate_mailer: 3,
    certificate_eligibility: 10
  ]

config :ex_money,
  auto_start_exchange_rate_service: false,
  default_cldr_backend: Oli.Cldr,
  json_library: Jason

# Configure reCAPTCHA
config :oli, :recaptcha,
  verify_url: "https://www.google.com/recaptcha/api/siteverify",
  timeout: 5000,
  site_key: System.get_env("RECAPTCHA_SITE_KEY"),
  secret: System.get_env("RECAPTCHA_PRIVATE_KEY")

# Configure help
# HELP_PROVIDER env var must be a string representing an existing provider module, such as "EmailHelp"
help_provider =
  case System.get_env("HELP_PROVIDER") do
    nil -> Oli.Help.Providers.EmailHelp
    provider -> Module.concat([Oli, Help, Providers, provider])
  end

config :oli, :help,
  dispatcher: help_provider,
  knowledge_base_link: System.get_env("KNOWLEDGE_BASE_LINK", "")

config :oli,
  ecl_username: System.get_env("ECL_USERNAME", ""),
  ecl_password: System.get_env("ECL_PASSWORD", "")

config :lti_1p3,
  provider: Lti_1p3.DataProviders.EctoProvider,
  ecto_provider: [
    repo: Oli.Repo,
    schemas: [
      user: Oli.Accounts.User,
      registration: Oli.Lti.Tool.Registration,
      deployment: Oli.Lti.Tool.Deployment
    ]
  ],
  ags_line_item_prefix: "oli-torus-"

config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role],
  region: [{:system, "AWS_REGION"}, :instance_role]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

case System.get_env("LOG_LEVEL", nil) do
  nil ->
    nil

  log_level ->
    config :logger, level: String.to_existing_atom(log_level)
end

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

if Mix.env() == :dev do
  config :mix_test_watch,
    clear: true
end

config :appsignal, :config, revision: System.get_env("SHA", default_sha)

# Configure Privacy Policies link
config :oli, :privacy_policies,
  url: System.get_env("PRIVACY_POLICIES_URL", "https://www.cmu.edu/legal/privacy-notice.html")

# Configure footer text and links
config :oli, :footer,
  text: System.get_env("FOOTER_TEXT", ""),
  link_1_location: System.get_env("FOOTER_LINK_1_LOCATION", ""),
  link_1_text: System.get_env("FOOTER_LINK_1_TEXT", ""),
  link_2_location: System.get_env("FOOTER_LINK_2_LOCATION", ""),
  link_2_text: System.get_env("FOOTER_LINK_2_TEXT", "")

config :ex_json_schema,
       :remote_schema_resolver,
       {Oli.Utils.SchemaResolver, :resolve_uri}

# Configure if age verification checkbox appears on learner account creation
config :oli, :age_verification, is_enabled: System.get_env("IS_AGE_VERIFICATION_ENABLED", "")

# Configure libcluster for horizontal scaling
# Take into account that different strategies could use different config options
config :libcluster,
  topologies: [
    oli: [
      strategy: Module.concat([System.get_env("LIBCLUSTER_STRATEGY", "Cluster.Strategy.Gossip")])
    ]
  ]

config :tailwind,
  version: "3.2.4",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/css/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :ex_cldr,
  default_locale: "en",
  default_backend: Oli.Cldr

config :oli, :datashop,
  cache_limit: String.to_integer(System.get_env("DATASHOP_CACHE_LIMIT", "200"))

config :oli, :student_sign_in,
  background_color: System.get_env("STUDENT_SIGNIN_BACKGROUND_COLOR", "#FF82E4")

# config :oli, knowledge_base_link: System.get_env("KNOWLEDGE_BASE_LINK", "")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
