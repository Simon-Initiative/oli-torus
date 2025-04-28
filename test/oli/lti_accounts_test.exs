defmodule Oli.LtiAccountsTest do
  use Oli.DataCase

  alias Oli.Accounts
  alias Oli.Accounts.User
  alias Lti_1p3.Roles.ContextRoles

  def make_user(institution_id) do
    %{
      sub: "1234-1234",
      name: "User Name",
      given_name: "User",
      family_name: "Name",
      middle_name: "",
      password: "password",
      password_confirmation: "password",
      email: "user@example.edu",
      email_verified: true,
      lti_institution_id: institution_id
    }
  end

  describe "insert or update" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
    end

    test "no user at all exists", %{section: section} do
      institution_id = section.institution_id

      {:ok, user1} = Accounts.insert_or_update_lms_user(make_user(institution_id), institution_id)

      assert user1.lti_institution_id == institution_id

      # Read it again to make sure it was inserted correctly
      user = Oli.Repo.get_by(User, sub: user1.sub, lti_institution_id: institution_id)
      assert user.lti_institution_id == institution_id
      assert user.id == user1.id

      # Now try to insert it again, but this time it will be an update
      {:ok, user2} = Accounts.insert_or_update_lms_user(make_user(institution_id), institution_id)
      assert user1.id == user2.id
    end

    test "a user exists already with this sub, but with nil institution", %{section: section} do
      institution_id = section.institution_id

      # Insert a user with nil institution
      {:ok, user} = Oli.Repo.insert(User.noauth_changeset(%User{}, make_user(nil)))

      # Now a call to insert_or_update_lms_user should create a new user with the institution_id
      # because there is no enrollment record
      {:ok, user1} = Accounts.insert_or_update_lms_user(make_user(institution_id), institution_id)

      refute user1.id == user.id
    end

    test "a user exists already with this sub, but with nil institution AND enrollment", %{
      section: section
    } do
      institution_id = section.institution_id

      # Insert a user with nil institution and enroll it in a section
      {:ok, user} = Oli.Repo.insert(User.noauth_changeset(%User{}, make_user(nil)))

      Oli.Delivery.Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      # Now a call to insert_or_update_lms_user should UPDATE that user, not create a new one
      {:ok, user1} = Accounts.insert_or_update_lms_user(make_user(institution_id), institution_id)

      assert user1.id == user.id
    end
  end
end
