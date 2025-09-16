defmodule OliWeb.Components.UtilsTest do
  use Oli.DataCase

  alias Oli.Accounts.User
  alias OliWeb.Components.Utils

  describe "user_is_guest?/1" do
    test "returns true when user is guest in socket assigns" do
      guest_user = %User{guest: true}
      assigns = %{current_user: guest_user}

      assert Utils.user_is_guest?(assigns) == true
    end

    test "returns true when user is guest in session" do
      guest_user = %User{guest: true}
      session = %{"user" => guest_user}

      assert Utils.user_is_guest?(session) == true
    end

    test "returns false when user is not guest in socket assigns" do
      regular_user = %User{guest: false}
      assigns = %{current_user: regular_user}

      assert Utils.user_is_guest?(assigns) == false
    end

    test "returns false when user is not guest in session" do
      regular_user = %User{guest: false}
      session = %{"user" => regular_user}

      assert Utils.user_is_guest?(session) == false
    end

    test "returns false when no user in socket assigns" do
      assigns = %{current_user: nil}

      assert Utils.user_is_guest?(assigns) == false
    end

    test "returns false when no user in session" do
      session = %{}

      assert Utils.user_is_guest?(session) == false
    end

    test "returns false when current_user key is not present in assigns" do
      assigns = %{other_field: "value"}

      assert Utils.user_is_guest?(assigns) == false
    end

    test "returns false when `user` key is not present in session" do
      session = %{"other_key" => "value"}

      assert Utils.user_is_guest?(session) == false
    end
  end
end
