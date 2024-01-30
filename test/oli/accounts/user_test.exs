defmodule Oli.Accounts.UserTest do
  alias Oli.Accounts
  use Oli.DataCase
  alias Oli.Accounts.User
  import Oli.Factory

  describe "update_changeset_for_admin/2" do
    setup do
      user =
        insert(:user,
          name: "CurrentName",
          given_name: "CurrentGivenName",
          family_name: "CurrentFamilyName",
          email: "CurrentEmail@oli.com",
          independent_learner: true,
          can_create_sections: true,
          guest: false
        )

      {:ok, %{user: user}}
    end

    test "success: admin can update a user with valid values", %{user: user} do
      attrs =
        %{
          given_name: "UpdatedGivenName",
          family_name: "UpdatedFamilyName",
          email: "UpdatedEmail@oli.com",
          independent_learner: false,
          can_create_sections: false
        }

      updated_user = User.update_changeset_for_admin(user, attrs) |> apply_changes()
      assert updated_user.given_name == attrs.given_name
      assert updated_user.family_name == attrs.family_name
      # Assert that also checks for downcasing email
      assert updated_user.email == String.downcase(attrs.email)
      assert updated_user.independent_learner == attrs.independent_learner
      assert updated_user.can_create_sections == attrs.can_create_sections
      # Check name has been well formed
      assert updated_user.name == "#{attrs.given_name} #{attrs.family_name}"
    end

    test "error: validate_required", %{user: user} do
      attrs =
        %{
          given_name: "",
          family_name: "",
          email: "UpdatedEmail@oli.com",
          independent_learner: false,
          can_create_sections: false
        }

      changeset = User.update_changeset_for_admin(user, attrs)

      refute changeset.valid?

      assert changeset.errors[:given_name] == {"can't be blank", [validation: :required]}
      assert changeset.errors[:family_name] == {"can't be blank", [validation: :required]}
    end

    test "error: hits users_email_independent_learner_index DB constraint", %{user: user} do
      email = "alreay_in_use@email.com"
      _another_user = insert(:user, email: email)
      attrs = %{email: email}

      {:error, changeset} =
        User.update_changeset_for_admin(user, attrs)
        |> Accounts.update_user_from_admin()

      refute changeset.valid?

      assert changeset.errors[:email] ==
               {"Email has already been taken by another independent learner",
                [
                  constraint: :unique,
                  constraint_name: "users_email_independent_learner_index"
                ]}
    end
  end
end
