# In this file, we load production configuration and secrets
# from environment variables at runtime
import Config

get_env_as_string = fn key, default ->
  System.get_env(key, default)
  |> String.trim()
  |> String.downcase()
end

get_env_as_boolean = fn key, default ->
  System.get_env(key, default)
  |> String.downcase()
  |> String.trim()
  |> case do
    "true" -> true
    _ -> false
  end
end

get_env_as_integer = fn key, default ->
  System.get_env(key, default)
  |> String.to_integer()
end

# Appsignal client key is required for appsignal integration
config :appsignal, :client_key, System.get_env("APPSIGNAL_PUSH_API_KEY", nil)

# Configure runtime log level if LOG_LEVEL is set
case System.get_env("LOG_LEVEL", nil) do
  nil ->
    nil

  log_level ->
    config :logger, level: String.to_existing_atom(log_level)
end

if get_env_as_boolean.("APPSIGNAL_ENABLE_LOGGING", "false") do
  config :logger, backends: [:console, {Appsignal.Logger.Backend, [group: "phoenix"]}]
end

config :oli, :author_auth_providers,
  google:
    (case System.get_env("GOOGLE_CLIENT_ID") do
       nil ->
         nil

       client_id ->
         [
           client_id: client_id,
           client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
           strategy: Assent.Strategy.Google
         ]
     end),
  github:
    (case System.get_env("AUTHOR_GITHUB_CLIENT_ID") do
       nil ->
         nil

       client_id ->
         [
           client_id: client_id,
           client_secret: System.get_env("AUTHOR_GITHUB_CLIENT_SECRET"),
           strategy: Assent.Strategy.Github
         ]
     end)

config :oli, :user_auth_providers,
  google:
    (case System.get_env("GOOGLE_CLIENT_ID") do
       nil ->
         nil

       client_id ->
         [
           client_id: client_id,
           client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
           strategy: Assent.Strategy.Google
         ]
     end)

config :oli, :certificates,
  generate_pdf_lambda:
    System.get_env("CERTIFICATES_GENERATE_PDF_LAMBDA", "generate_certificate_pdf_from_html"),
  s3_pdf_bucket: System.get_env("CERTIFICATES_S3_PDF_URL", "torus-pdf-certificates")

####################### Production-only configurations ########################
## Note: These configurations are only applied in production
###############################################################################
if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  db_timeout =
    case get_env_as_string.("DB_TIMEOUT", "600000") do
      "infinity" -> :infinity
      val -> String.to_integer(val)
    end

  config :oli, Oli.Repo,
    url: database_url,
    database: System.get_env("DB_NAME", "oli"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    timeout: db_timeout,
    queue_target: String.to_integer(System.get_env("DB_QUEUE_TARGET") || "50"),
    queue_interval: String.to_integer(System.get_env("DB_QUEUE_INTERVAL") || "1000"),
    ownership_timeout: 600_000,
    socket_options: maybe_ipv6

  config :ex_aws, :s3,
    region: System.get_env("AWS_REGION", "us-east-1"),
    scheme: System.get_env("AWS_S3_SCHEME", "https") <> "://",
    port: System.get_env("AWS_S3_PORT", "443") |> String.to_integer(),
    host: System.get_env("AWS_S3_HOST", "s3.amazonaws.com")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  live_view_salt =
    System.get_env("LIVE_VIEW_SALT") ||
      raise """
      environment variable LIVE_VIEW_SALT is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host =
    System.get_env("HOST") ||
      raise """
      environment variable HOST is missing.
      For example: host.example.com
      """

  s3_media_bucket_name =
    System.get_env("S3_MEDIA_BUCKET_NAME") ||
      raise """
      environment variable S3_MEDIA_BUCKET_NAME is missing.
      For example: torus-media
      """

  s3_xapi_bucket_name =
    System.get_env("S3_XAPI_BUCKET_NAME") ||
      raise """
      environment variable S3_XAPI_BUCKET_NAME is missing.
      For example: torus-xapi
      """

  if System.get_env("PAYMENT_PROVIDER") == "stripe" &&
       (!System.get_env("STRIPE_PUBLIC_SECRET") || !System.get_env("STRIPE_PRIVATE_SECRET")) do
    raise """
    Stripe payment provider not configured correctly. Both STRIPE_PUBLIC_SECRET
    and STRIPE_PRIVATE_SECRET values must be set.
    """
  end

  if System.get_env("PAYMENT_PROVIDER") == "cashnet" &&
       (!System.get_env("CASHNET_STORE") || !System.get_env("CASHNET_CHECKOUT_URL") ||
          !System.get_env("CASHNET_CLIENT") || !System.get_env("CASHNET_GL_NUMBER")) do
    raise """
    Cashnet payment provider not configured correctly. CASHNET_STORE, CASHNET_CHECKOUT_URL,
    CASHNET_CLIENT and CASHNET_GL_NUMBER values must be set.
    """
  end

  media_url =
    System.get_env("MEDIA_URL") ||
      raise """
      environment variable MEDIA_URL is missing.
      For example: your_s3_media_bucket_url.s3.amazonaws.com
      """

  # General OLI app config
  config :oli,
    instructor_dashboard_details: get_env_as_boolean.("INSTRUCTOR_DASHBOARD_DETAILS", "true"),
    depot_warmer_days_lookback: System.get_env("DEPOT_WARMER_DAYS_LOOKBACK", "5"),
    depot_warmer_max_number_of_entries: System.get_env("DEPOT_WARMER_MAX_NUMBER_OF_ENTRIES", "0"),
    s3_media_bucket_name: s3_media_bucket_name,
    s3_xapi_bucket_name: s3_xapi_bucket_name,
    media_url: media_url,
    email_from_name: System.get_env("EMAIL_FROM_NAME", "OLI Torus"),
    email_from_address: System.get_env("EMAIL_FROM_ADDRESS", "admin@example.edu"),
    email_reply_to: System.get_env("EMAIL_REPLY_TO", "admin@example.edu"),
    slack_webhook_url: System.get_env("SLACK_WEBHOOK_URL"),
    load_testing_mode: get_env_as_boolean.("LOAD_TESTING_MODE", "false"),
    payment_provider: System.get_env("PAYMENT_PROVIDER", "none"),
    blackboard_application_client_id: System.get_env("BLACKBOARD_APPLICATION_CLIENT_ID"),
    branding: [
      name: System.get_env("BRANDING_NAME", "OLI Torus"),
      logo: System.get_env("BRANDING_LOGO", "/images/oli_torus_logo.png"),
      logo_dark:
        System.get_env(
          "BRANDING_LOGO_DARK",
          System.get_env("BRANDING_LOGO", "/images/oli_torus_logo_dark.png")
        ),
      favicons: System.get_env("BRANDING_FAVICONS_DIR", "/favicons")
    ],
    node_js_pool_size: String.to_integer(System.get_env("NODE_JS_POOL_SIZE", "2")),
    screen_idle_timeout_in_seconds:
      String.to_integer(System.get_env("SCREEN_IDLE_TIMEOUT_IN_SECONDS", "1800")),
    log_incomplete_requests: get_env_as_boolean.("LOG_INCOMPLETE_REQUESTS", "true")

  config :oli, :dataset_generation,
    enabled: System.get_env("EMR_DATASET_ENABLED", "false") == "true",
    emr_aplication_name: System.get_env("EMR_DATASET_APPLICATION_NAME", "csv_job"),
    execution_role:
      System.get_env(
        "EMR_DATASET_EXECUTION_ROLE",
        "arn:aws:iam::123456789012:role/service-role/EMR_DefaultRole"
      ),
    entry_point: System.get_env("EMR_DATASET_ENTRY_POINT", "s3://analyticsjobs/job.py"),
    log_uri: System.get_env("EMR_DATASET_LOG_URI", "s3://analyticsjobs/logs"),
    source_bucket: System.get_env("EMR_DATASET_SOURCE_BUCKET", "torus-xapi-prod"),
    context_bucket: System.get_env("EMR_DATASET_CONTEXT_BUCKET", "torus-datasets-prod"),
    spark_submit_parameters:
      System.get_env(
        "EMR_DATASET_SPARK_SUBMIT_PARAMETERS",
        "--conf spark.archives=s3://analyticsjobs/dataset.zip#dataset --py-files s3://analyticsjobs/dataset.zip --conf spark.executor.memory=2G --conf spark.executor.cores=2"
      )

  config :oli, :xapi_upload_pipeline,
    batcher_concurrency: get_env_as_integer.("XAPI_BATCHER_CONCURRENCY", "20"),
    batch_size: get_env_as_integer.("XAPI_BATCH_SIZE", "50"),
    batch_timeout: get_env_as_integer.("XAPI_BATCHER_CONCURRENCY", "5000"),
    processor_concurrency: get_env_as_integer.("XAPI_PROCESSOR_CONCURRENCY", "2")

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

  # optional emerald cloudlab configuration
  config :oli,
    ecl_username: System.get_env("ECL_USERNAME", ""),
    ecl_password: System.get_env("ECL_PASSWORD", "")

  config :oli, :stripe_provider,
    public_secret: System.get_env("STRIPE_PUBLIC_SECRET"),
    private_secret: System.get_env("STRIPE_PRIVATE_SECRET")

  config :oli, :cashnet_provider,
    cashnet_store: System.get_env("CASHNET_STORE"),
    cashnet_checkout_url: System.get_env("CASHNET_CHECKOUT_URL"),
    cashnet_client: System.get_env("CASHNET_CLIENT"),
    cashnet_gl_number: System.get_env("CASHNET_GL_NUMBER")

  config :oli, :upgrade_experiment_provider,
    url: System.get_env("UPGRADE_EXPERIMENT_PROVIDER_URL"),
    user_url: System.get_env("UPGRADE_EXPERIMENT_USER_URL"),
    api_token: System.get_env("UPGRADE_EXPERIMENT_PROVIDER_API_TOKEN")

  # Configure reCAPTCHA
  config :oli, :recaptcha,
    verify_url: "https://www.google.com/recaptcha/api/siteverify",
    timeout: 5000,
    site_key: System.get_env("RECAPTCHA_SITE_KEY"),
    secret: System.get_env("RECAPTCHA_PRIVATE_KEY")

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
      nil -> Oli.Activities.Transformers.VariableSubstitution.NoOpImpl
      provider -> Module.concat([Oli, Activities, Transformers, VariableSubstitution, provider])
    end

  config :oli, :variable_substitution,
    dispatcher: variable_substitution_provider,
    aws_fn_name: System.get_env("VARIABLE_SUBSTITUTION_LAMBDA_FN_NAME", "eval"),
    aws_region: System.get_env("VARIABLE_SUBSTITUTION_LAMBDA_REGION", "us-east-1"),
    rest_endpoint_url: System.get_env("VARIABLE_SUBSTITUTION_REST_ENDPOINT_URL", "us-east-1")

  # Configure help
  # HELP_PROVIDER env var must be a string representing an existing provider module, such as "FreshdeskHelp"
  help_provider =
    case System.get_env("HELP_PROVIDER") do
      nil -> Oli.Help.Providers.FreshdeskHelp
      provider -> Module.concat([Oli, Help, Providers, provider])
    end

  config :oli, :help,
    dispatcher: help_provider,
    knowledge_base_link: System.get_env("KNOWLEDGE_BASE_LINK", "")

  # Configurable http/https protocol options for cowboy
  # https://ninenines.eu/docs/en/cowboy/2.5/manual/cowboy_http/
  http_max_header_name_length =
    System.get_env("HTTP_MAX_HEADER_NAME_LENGTH", "64") |> String.to_integer()

  http_max_header_value_length =
    System.get_env("HTTP_MAX_HEADER_VALUE_LENGTH", "4096") |> String.to_integer()

  http_max_headers = System.get_env("HTTP_MAX_HEADERS", "100") |> String.to_integer()

  if System.get_env("PHX_SERVER") do
    config :oli, OliWeb.Endpoint, server: true
  end

  config :oli, OliWeb.Endpoint,
    http: [
      :inet6,
      port: String.to_integer(System.get_env("HTTP_PORT", "80")),
      protocol_options: [
        max_header_name_length: http_max_header_name_length,
        max_header_value_length: http_max_header_value_length,
        max_headers: http_max_headers
      ]
    ],
    url: [
      scheme: System.get_env("SCHEME", "https"),
      host: host,
      port: String.to_integer(System.get_env("PORT", "443"))
    ],
    secret_key_base: secret_key_base,
    live_view: [signing_salt: live_view_salt]

  if System.get_env("SSL_CERT_PATH") && System.get_env("SSL_KEY_PATH") do
    config :oli, OliWeb.Endpoint,
      https: [
        port: 443,
        otp_app: :oli,
        keyfile: System.get_env("SSL_CERT_PATH", "priv/ssl/localhost.key"),
        certfile: System.get_env("SSL_KEY_PATH", "priv/ssl/localhost.crt"),
        protocol_options: [
          max_header_name_length: http_max_header_name_length,
          max_header_value_length: http_max_header_value_length,
          max_headers: http_max_headers
        ]
      ]
  end

  truncate =
    System.get_env("LOGGER_TRUNCATE", "8192")
    |> String.downcase()
    |> case do
      "infinity" ->
        :infinity

      val ->
        String.to_integer(val)
    end

  config :logger, truncate: truncate

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

  # Configure if age verification checkbox appears on learner account creation
  config :oli, :age_verification, is_enabled: System.get_env("IS_AGE_VERIFICATION_ENABLED", "")

  # Configure libcluster for horizontal scaling
  # Take into account that different strategies could use different config options
  config :libcluster,
    topologies: [
      oli:
        case System.get_env("LIBCLUSTER_STRATEGY", "Cluster.Strategy.Gossip") do
          "ClusterEC2.Strategy.Tags" = ec2_strategy ->
            [
              strategy: Module.concat([ec2_strategy]),
              config: [
                ec2_tagname: System.get_env("LIBCLUSTER_EC2_STRATEGY_TAG_NAME", ""),
                ec2_tagvalue: System.get_env("LIBCLUSTER_EC2_STRATEGY_TAG_VALUE", ""),
                app_prefix: System.get_env("LIBCLUSTER_EC2_STRATEGY_APP_PREFIX", "oli")
              ]
            ]

          strategy ->
            [
              strategy: Module.concat([strategy])
            ]
        end
    ]

  config :oli, :datashop,
    cache_limit: String.to_integer(System.get_env("DATASHOP_CACHE_LIMIT", "200"))

  config :oli, :student_sign_in,
    background_color: System.get_env("STUDENT_SIGNIN_BACKGROUND_COLOR", "#FF82E4")

  config :oli, knowledge_base_link: System.get_env("KNOWLEDGE_BASE_LINK", "")

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
      default: String.to_integer(System.get_env("OBAN_QUEUE_SIZE_DEFAULT", "10")),
      snapshots: String.to_integer(System.get_env("OBAN_QUEUE_SIZE_SNAPSHOTS", "20")),
      s3_uploader: String.to_integer(System.get_env("OBAN_QUEUE_SIZE_S3UPLOADER", "20")),
      selections: String.to_integer(System.get_env("OBAN_QUEUE_SIZE_SELECTIONS", "20")),
      updates: String.to_integer(System.get_env("OBAN_QUEUE_SIZE_UPDATES", "2")),
      grades: String.to_integer(System.get_env("OBAN_QUEUE_SIZE_GRADES", "30")),
      auto_submit: String.to_integer(System.get_env("OBAN_QUEUE_SIZE_AUTOSUBMIT", "3")),
      analytics_export: String.to_integer(System.get_env("OBAN_QUEUE_SIZE_ANALYTICS", "1")),
      datashop_export: String.to_integer(System.get_env("OBAN_QUEUE_SIZE_DATASHOP", "1")),
      project_export: String.to_integer(System.get_env("OBAN_QUEUE_SIZE_PROJECT_EXPORT", "3")),
      objectives: String.to_integer(System.get_env("OBAN_QUEUE_SIZE_OBJECTIVES", "3")),
      mailer: String.to_integer(System.get_env("OBAN_QUEUE_SIZE_MAILER", "10")),
      certificate_eligibility:
        String.to_integer(System.get_env("OBAN_QUEUE_SIZE_CERTIFICATE_ELIGIBILITY", "10"))
    ]
end
