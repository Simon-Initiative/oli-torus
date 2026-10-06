defmodule OliWeb.TransportSecurityTest do
  use ExUnit.Case, async: true

  alias OliWeb.TransportSecurity

  test "listener negotiates modern TLS 1.2 and TLS 1.3 suites" do
    for {version, cipher} <- [
          {:"tlsv1.2", ~c"ECDHE-RSA-AES256-GCM-SHA384"},
          {:"tlsv1.2", ~c"ECDHE-RSA-AES128-GCM-SHA256"},
          {:"tlsv1.3", ~c"TLS_AES_256_GCM_SHA384"}
        ] do
      assert {:ok, info} = handshake(version, cipher)
      assert info[:protocol] == version
      assert info[:selected_cipher_suite].mac == :aead
    end
  end

  test "listener rejects legacy protocol and CBC negotiation" do
    for {version, cipher} <- [
          {:tlsv1, ~c"ECDHE-RSA-AES256-SHA"},
          {:"tlsv1.1", ~c"ECDHE-RSA-AES256-SHA"},
          {:"tlsv1.2", ~c"ECDHE-RSA-AES256-SHA"},
          {:"tlsv1.2", ~c"AES256-GCM-SHA384"}
        ] do
      assert {:error, _} = handshake(version, cipher)
    end
  end

  defp handshake(version, cipher) do
    options =
      TransportSecurity.https_options() ++
        [
          certfile: ~c"priv/ssl/localhost.crt",
          keyfile: ~c"priv/ssl/localhost.key",
          active: false,
          ip: {127, 0, 0, 1}
        ]

    {:ok, listener} = :ssl.listen(0, options)
    {:ok, {_, port}} = :ssl.sockname(listener)

    server =
      Task.async(fn ->
        {:ok, socket} = :ssl.transport_accept(listener, 5_000)

        case :ssl.handshake(socket, 5_000) do
          {:ok, socket} -> :ssl.close(socket)
          {:error, _} -> :ok
        end
      end)

    try do
      result =
        case :ssl.connect(
               {127, 0, 0, 1},
               port,
               [versions: [version], ciphers: [cipher], verify: :verify_none, active: false],
               5_000
             ) do
          {:ok, socket} ->
            info = :ssl.connection_information(socket, [:protocol, :selected_cipher_suite])
            :ssl.close(socket)
            info

          {:error, _} = error ->
            error
        end

      Task.await(server, 6_000)
      result
    after
      :ssl.close(listener)
      Task.shutdown(server)
    end
  end
end
