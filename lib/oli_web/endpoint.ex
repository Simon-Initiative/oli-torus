defmodule OliWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :oli

  @session_options [
    store: :cookie,
    key: "_oli_key",
    signing_salt: "KydU49lB",
    same_site: "None",
    secure: true
  ]

  socket("/v1/api/state", OliWeb.UserSocket,
    websocket: true,
    longpoll: false
  )

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug(Plug.Static,
    at: "/",
    from: :oli,
    gzip: true,
    only:
      ~w(assets css fonts images js custom branding vlab sw.js idb.js offline.html manifest.json favicon.ico robots.txt flame_graphs ebsco)
  )

  plug Plug.Static, at: "/schemas", from: {:oli, "priv/schemas"}, gzip: true

  if Code.ensure_loaded?(Tidewave) do
    plug Tidewave
  end

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"
  )

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    # 512mb is the max body size our file-upload client code can generate.
    length: 512_000_000,
    json_decoder: Phoenix.json_library(),
    body_reader: {OliWeb.CacheBodyReader, :read_body, []}
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  unless Mix.env() == :test do
    plug(Oli.Plugs.SSL,
      rewrite_on: [:x_forwarded_proto],
      hsts: true,
      log: false
    )
  end

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug(Plug.Session, @session_options)

  plug(OliWeb.Router)
end
