import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

config :oli,
  env: :test,
  depot_coordinator: Oli.Delivery.SingletonDepotCoordinator,
  s3_media_bucket_name: "torus-media-test",
  s3_xapi_bucket_name: "torus-xapi-test",
  media_url: "http://localhost:9000/minio/oli-torus-media",
  http_client: Oli.Test.MockHTTP,
  aws_client: Oli.Test.MockAws,
  openai_client: Oli.Test.MockOpenAIClient,
  date_time_module: Oli.Test.DateTimeMock,
  date_module: Oli.Test.DateMock,
  recaptcha_module: Oli.Test.RecaptchaMock,
  slack_webhook_url: nil,
  branding: [
    name: "OLI Torus Test",
    logo: "/images/oli_torus_logo.png",
    logo_dark: "/images/oli_torus_logo_dark.png",
    favicons: "/favicons"
  ]

config :oli, :blob_storage,
  bucket_name: "torus-blob-test",
  use_deprecated_api: true

config :oli, :xapi_upload_pipeline,
  producer_module: Oli.Analytics.XAPI.QueueProducer,
  uploader_module: Oli.Analytics.XAPI.FileWriterUploader,
  batcher_concurrency: 1,
  batch_size: 2,
  batch_timeout: 1,
  processor_concurrency: 1,
  suppress_event_emitting: true,
  xapi_local_output_dir: System.get_env("XAPI_LOCAL_TEST_OUTPUT_DIR", "./xapi_test_output")

# Configure database
database_url = System.get_env("DATABASE_URL")

if database_url && database_url != "" do
  config :oli, Oli.Repo, url: database_url
else
  config :oli, Oli.Repo,
    username: System.get_env("DB_USER", "postgres"),
    password: System.get_env("DB_PASSWORD", "postgres"),
    hostname: System.get_env("DB_HOST", "localhost"),
    database: "oli_test"
end

config :oli, Oli.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  timeout: 600_000,
  pool_size: 30,
  ownership_timeout: 600_000

config :oli, Oban,
  plugins: false,
  queues: false,
  testing: :manual

# Configure reCAPTCHA
config :oli, :recaptcha,
  verify_url: "https://www.google.com/recaptcha/api/siteverify",
  timeout: 5000,
  site_key: System.get_env("RECAPTCHA_SITE_KEY", "6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI"),
  secret: System.get_env("RECAPTCHA_PRIVATE_KEY", "6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe")

# Configure help
config :oli, :help, dispatcher: Oli.Help.Providers.EmailHelp

# Configure Email
config :oli, Oli.Mailer, adapter: Swoosh.Adapters.Test

config :oli, :clickhouse_inventory,
  manifest_bucket: "test-inventory-bucket",
  manifest_prefix: "inventory/test-prefix",
  manifest_suffix: "manifest.json",
  directory_time_suffix: "T01-00Z",
  batch_chunk_size: 5,
  max_simultaneous_batches: 1,
  max_batch_retries: 1

config :oli, :clickhouse,
  host: "localhost",
  http_port: 8123,
  native_port: 9000,
  user: "default",
  password: "",
  database: "default"

config :oli, :clickhouse_analytics_module, Oli.Test.ClickhouseStub
config :oli, :clickhouse_olap_enabled?, true

# speed up tests by lowering the hash iterations
config :bcrypt_elixir, log_rounds: 4

config :lti_1p3,
  http_client: Oli.Test.MockHTTP,
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

# Configurable http/https protocol options for cowboy
# https://ninenines.eu/docs/en/cowboy/2.5/manual/cowboy_http/
http_max_header_name_length =
  System.get_env("HTTP_MAX_HEADER_NAME_LENGTH", "64") |> String.to_integer()

http_max_header_value_length =
  System.get_env("HTTP_MAX_HEADER_VALUE_LENGTH", "4096") |> String.to_integer()

http_max_headers = System.get_env("HTTP_MAX_HEADERS", "100") |> String.to_integer()

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :oli, OliWeb.Endpoint,
  http: [
    port: 4002,
    protocol_options: [
      max_header_name_length: http_max_header_name_length,
      max_header_value_length: http_max_header_value_length,
      max_headers: http_max_headers
    ]
  ],
  server: false,
  url: [scheme: "https"]

# Config adapter for refreshing part_mapping
config :oli, Oli.Publishing, refresh_adapter: Oli.Publishing.PartMappingRefreshSync
config :oli, :lti_access_token_provider, provider: Oli.Lti.AccessTokenTest

# Print only warnings and errors during test
config :logger, level: :warning

config :oli,
  enable_playwright_scenarios: true,
  playwright_scenario_token: System.get_env("PLAYWRIGHT_SCENARIO_TOKEN")

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

config :appsignal, :config, active: false

config :oli, :section_cache, dispatcher: Oli.TestHelpers.CustomDispatcher

config :assent, http_adapter: Oli.Test.MockHTTP

config :ex_aws,
  region: "us-east-1",
  access_key_id: "test-access-key",
  secret_access_key: "test-secret-key"

config :ex_aws, :s3,
  region: "us-east-1",
  access_key_id: "test-access-key",
  secret_access_key: "test-secret-key",
  scheme: "https://",
  port: 443,
  host: "s3.amazonaws.com"

config :ex_aws, :emr, region: System.get_env("AWS_REGION", "us-east-1")

config :ex_aws, :hackney_opts,
  follow_redirect: true,
  recv_timeout: 200_000

config :oli, Oli.Vault,
  json_library: Jason,
  ciphers: [
    default:
      {Cloak.Ciphers.AES.GCM,
       tag: "AES.GCM.V1", key: Base.decode64!("HXCdm5z61eNgUpnXObJRv94k3JnKSrnfwppyb60nz6w=")}
  ]
