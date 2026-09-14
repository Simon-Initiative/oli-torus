defmodule Oli.Lti.DevHTTPClientTest do
  use ExUnit.Case, async: false

  alias Oli.Lti.DevHTTPClient

  setup do
    previous = Application.get_env(:oli, DevHTTPClient)
    path = Path.join(System.tmp_dir!(), "lti-ca-#{System.unique_integer([:positive])}.pem")
    Application.put_env(:oli, DevHTTPClient, ca_cert_path: path)

    on_exit(fn ->
      File.rm(path)

      case previous do
        nil -> Application.delete_env(:oli, DevHTTPClient)
        value -> Application.put_env(:oli, DevHTTPClient, value)
      end
    end)

    %{path: path}
  end

  test "augments public trust and preserves timeouts and hostname verification", %{path: path} do
    [certificate | _] = :certifi.cacerts()
    File.write!(path, :public_key.pem_encode([{:Certificate, certificate, :not_encrypted}]))

    options = DevHTTPClient.process_request_options(timeout: 1234, recv_timeout: 5678)
    assert options[:timeout] == 1234
    assert options[:recv_timeout] == 5678
    assert options[:ssl][:cacerts] == :certifi.cacerts() ++ [certificate]

    # Inspect the effective options from the installed transport, not just our overrides.
    ssl = :hackney_connection.ssl_opts(~c"moodle.test", ssl_options: options[:ssl])
    assert ssl[:verify] == :verify_peer
    assert ssl[:server_name_indication] == ~c"moodle.test"
    assert {_verify, [check_hostname: ~c"moodle.test"]} = ssl[:verify_fun]
  end

  test "fails explicitly when the configured CA file is missing", %{path: path} do
    assert_raise File.Error, fn -> DevHTTPClient.process_request_options([]) end
    refute File.exists?(path)
  end

  test "rejects a file without certificates", %{path: path} do
    File.write!(path, "not a certificate")

    assert_raise ArgumentError, ~r/LTI_CA_CERT_PATH must contain PEM certificates/, fn ->
      DevHTTPClient.process_request_options([])
    end
  end
end
