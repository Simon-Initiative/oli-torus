defmodule Oli.Delivery.SecureDeliveryConfigTest do
  use ExUnit.Case, async: false

  @tag capture_log: true
  test "runtime configuration normalizes booleans and defaults to false" do
    previous = System.get_env("SUPPORTS_SECURE_DELIVERY")

    on_exit(fn ->
      case previous do
        nil -> System.delete_env("SUPPORTS_SECURE_DELIVERY")
        value -> System.put_env("SUPPORTS_SECURE_DELIVERY", value)
      end
    end)

    for {value, expected} <- [
          {nil, false},
          {"false", false},
          {"true", true},
          {" TRUE ", true},
          {"invalid", false}
        ] do
      case value do
        nil -> System.delete_env("SUPPORTS_SECURE_DELIVERY")
        value -> System.put_env("SUPPORTS_SECURE_DELIVERY", value)
      end

      config = Config.Reader.read!("config/runtime.exs", env: :test, target: :host)
      assert config[:oli][:supports_secure_delivery] == expected
    end
  end
end
