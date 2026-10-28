defmodule Oli.Encrypted.BinaryTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Oli.Encrypted.Binary

  test "converts Cloak authentication failures to nil and logs an operator-facing error" do
    log = capture_log(fn -> assert Binary.after_decrypt(:error) == nil end)

    assert log =~ "Unable to decrypt an encrypted value"
    assert log =~ "CLOAK_VAULT_KEY"
  end

  test "preserves successfully decrypted binary values" do
    assert Binary.after_decrypt("secret") == "secret"
  end
end
