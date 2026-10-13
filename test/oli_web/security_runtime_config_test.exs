defmodule OliWeb.SecurityRuntimeConfigTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  setup do
    values = %{
      "DATABASE_URL" => "ecto://postgres:postgres@localhost/oli_test",
      "SECRET_KEY_BASE" => String.duplicate("a", 64),
      "LIVE_VIEW_SALT" => "security-test-salt",
      "HOST" => "torus.example.edu",
      "S3_MEDIA_BUCKET_NAME" => "test-media",
      "S3_XAPI_BUCKET_NAME" => "test-xapi",
      "MEDIA_URL" => "https://media.example.edu",
      "CLOAK_VAULT_KEY" => Base.encode64(String.duplicate("a", 32)),
      "PAYMENT_PROVIDER" => "none",
      "SSL_CERT_PATH" => "priv/ssl/localhost.crt",
      "SSL_KEY_PATH" => "priv/ssl/localhost.key",
      "CSP_REPORT_ONLY" => nil
    }

    original = Map.new(values, fn {key, _} -> {key, System.get_env(key)} end)
    System.put_env(values)
    on_exit(fn -> System.put_env(original) end)
    :ok
  end

  test "production direct HTTPS uses the correct files and negotiable modern TLS options" do
    config = Config.Reader.read!("config/runtime.exs", env: :prod, target: :host)
    options = config[:oli][OliWeb.Endpoint][:https]
    assert options[:certfile] == "priv/ssl/localhost.crt"
    assert options[:keyfile] == "priv/ssl/localhost.key"
    assert options[:versions] == [:"tlsv1.3", :"tlsv1.2"]
    assert {:ok, configured} = Plug.SSL.configure(options)
    assert configured[:ciphers] == OliWeb.TransportSecurity.https_options()[:ciphers]
  end

  test "report-only runtime policy is opt-in and rejects header injection or oversized values" do
    read = fn -> Config.Reader.read!("config/runtime.exs", env: :test, target: :host) end
    assert read.()[:oli][:csp_report_only] == nil

    System.put_env("CSP_REPORT_ONLY", "default-src 'self'")
    assert read.()[:oli][:csp_report_only] == "default-src 'self'"

    for invalid <- ["default-src 'self'\r\nx-injected: yes", String.duplicate("a", 4097)] do
      System.put_env("CSP_REPORT_ONLY", invalid)
      assert_raise RuntimeError, ~r/CSP_REPORT_ONLY/, read
    end
  end

  test "SSL redirect keeps health checks and trusted forwarded HTTPS working" do
    original = Application.get_env(:oli, :force_ssl_redirect?)
    Application.put_env(:oli, :force_ssl_redirect?, true)

    on_exit(fn ->
      case original do
        nil -> Application.delete_env(:oli, :force_ssl_redirect?)
        value -> Application.put_env(:oli, :force_ssl_redirect?, value)
      end
    end)

    opts =
      Oli.Plugs.SSL.init(
        rewrite_on: [:x_forwarded_proto],
        hsts: true,
        expires: 31_536_000,
        subdomains: false,
        preload: false,
        log: false
      )

    conn =
      conn(:get, "http://torus.example.edu/lti/register_form")
      |> put_req_header("x-forwarded-proto", "https")
      |> Oli.Plugs.SSL.call(opts)

    refute conn.halted
    assert get_resp_header(conn, "strict-transport-security") == ["max-age=31536000"]

    redirect = conn(:get, "http://torus.example.edu/") |> Oli.Plugs.SSL.call(opts)
    assert redirect.halted
    assert get_resp_header(redirect, "location") == ["https://torus.example.edu/"]

    health = conn(:get, "http://torus.example.edu/healthz") |> Oli.Plugs.SSL.call(opts)
    refute health.halted
    assert get_resp_header(health, "location") == []
  end
end
