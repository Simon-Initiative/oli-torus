defmodule OliWeb.TransportSecurity do
  @moduledoc "TLS policy for deployments terminating HTTPS in the application."

  @doc """
  Allows TLS 1.2 ECDHE/AES-GCM and modern TLS 1.3 authenticated-encryption suites.

  Proxy-terminated deployments must configure the same policy at their public
  listener; these options do not affect outbound LMS connections.
  """
  @spec https_options() :: keyword()
  def https_options do
    [
      versions: [:"tlsv1.3", :"tlsv1.2"],
      ciphers: ~w(
        TLS_AES_256_GCM_SHA384
        TLS_AES_128_GCM_SHA256
        TLS_CHACHA20_POLY1305_SHA256
        ECDHE-ECDSA-AES256-GCM-SHA384
        ECDHE-RSA-AES256-GCM-SHA384
        ECDHE-ECDSA-AES128-GCM-SHA256
        ECDHE-RSA-AES128-GCM-SHA256
      )c
    ]
  end
end
