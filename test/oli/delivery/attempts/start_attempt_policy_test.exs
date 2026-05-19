defmodule Oli.Delivery.Attempts.StartAttemptPolicyTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Attempts.StartAttemptPolicy
  alias Oli.Delivery.Settings.Combined

  describe "validate/2" do
    test "allows starts when no assessment password is configured" do
      assert :ok = StartAttemptPolicy.validate(%Combined{password: nil})
      assert :ok = StartAttemptPolicy.validate(%Combined{password: ""})
    end

    test "requires a submitted password when an assessment password is configured" do
      settings = %Combined{password: "secret"}

      assert {:error, :password_required} = StartAttemptPolicy.validate(settings)

      assert {:error, :password_required} =
               StartAttemptPolicy.validate(settings, password: "")
    end

    test "rejects incorrect submitted assessment passwords" do
      settings = %Combined{password: "secret"}

      assert {:error, :incorrect_password} =
               StartAttemptPolicy.validate(settings, password: "wrong")
    end

    test "allows matching submitted assessment passwords" do
      settings = %Combined{password: "secret"}

      assert :ok = StartAttemptPolicy.validate(settings, password: "secret")
    end
  end
end
