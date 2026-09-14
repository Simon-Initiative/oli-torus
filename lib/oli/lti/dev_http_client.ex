defmodule Oli.Lti.DevHTTPClient do
  @moduledoc """
  Development LTI HTTP client that trusts an additional local CA.

  Enabled by `LTI_CA_CERT_PATH` in development. Public roots and Hackney's
  hostname verification remain in place for keyset, token, NRPS, and AGS calls.
  """

  use HTTPoison.Base

  @doc """
  Adds the configured PEM certificates to the public CA bundle, preserving request options.

  Raises for a missing or empty certificate file instead of silently falling back
  to an untrusted connection. The file is reread so local certificate renewal
  does not require recompiling this client.
  """
  @impl true
  @spec process_request_options(keyword()) :: keyword()
  def process_request_options(options) do
    path = Application.fetch_env!(:oli, __MODULE__) |> Keyword.fetch!(:ca_cert_path)

    certificates =
      path
      |> File.read!()
      |> :public_key.pem_decode()
      |> Enum.flat_map(fn
        {:Certificate, der, :not_encrypted} -> [der]
        _ -> []
      end)

    case certificates do
      [] -> raise ArgumentError, "LTI_CA_CERT_PATH must contain PEM certificates: #{path}"
      _ -> :ok
    end

    ssl =
      options
      |> Keyword.get(:ssl, [])
      |> Keyword.merge(cacerts: :certifi.cacerts() ++ certificates, verify: :verify_peer)

    Keyword.put(options, :ssl, ssl)
  end
end
