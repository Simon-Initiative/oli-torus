defmodule OliWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :oli

  @session_options [
    store: :cookie,
    key: "_oli_key",
    signing_salt: "KydU49lB",
    same_site: "None",
    secure: true,
  ]

  socket "/socket", OliWeb.UserSocket,
    websocket: true,
    longpoll: false


  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]


  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :oli,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    length: 20_000_000,
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug Plug.Session, @session_options

  plug Pow.Plug.Session, OliWeb.Pow.PowHelpers.get_pow_config(:author)
  plug Pow.Plug.Session, OliWeb.Pow.PowHelpers.get_pow_config(:user)

  plug OliWeb.Router
end
