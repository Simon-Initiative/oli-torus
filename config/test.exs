import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

config :oli,
  env: :test,
  s3_media_bucket_name: System.get_env("TEST_S3_MEDIA_BUCKET_NAME"),
  s3_xapi_bucket_name: System.get_env("S3_XAPI_BUCKET_NAME"),
  media_url: System.get_env("TEST_MEDIA_URL"),
  http_client: Oli.Test.MockHTTP,
  aws_client: Oli.Test.MockAws,
  openai_client: Oli.Test.MockOpenAIClient,
  date_time_module: Oli.Test.DateTimeMock,
  date_module: Oli.Test.DateMock,
  slack_webhook_url: nil,
  branding: [
    name: "OLI Torus Test",
    logo: "/images/oli_torus_logo.png",
    logo_dark: "/images/oli_torus_logo_dark.png",
    favicons: "/favicons"
  ]

config :oli, :xapi_upload_pipeline,
  producer_module: Oli.Analytics.XAPI.QueueProducer,
  uploader_module: Oli.Analytics.XAPI.FileWriterUploader,
  batcher_concurrency: 1,
  batch_size: 2,
  batch_timeout: 1,
  processor_concurrency: 1,
  suppress_event_emitting: true

# Configure your database
config :oli, Oli.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  database: "oli_test",
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
config :oli, Oli.Mailer, adapter: Bamboo.TestAdapter

config :oli, OliWeb.Pow.Mailer, adapter: Bamboo.TestAdapter

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

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :oli, OliWeb.Endpoint,
  http: [port: 4002],
  server: false,
  url: [scheme: "https"]

# Config adapter for refreshing part_mapping
config :oli, Oli.Publishing, refresh_adapter: Oli.Publishing.PartMappingRefreshSync
config :oli, :lti_access_token_provider, provider: Oli.Lti.AccessTokenTest

# Print only warnings and errors during test
config :logger, level: :warning

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
