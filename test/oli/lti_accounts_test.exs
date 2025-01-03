defmodule Oli.AccountsTest do
  use Oli.DataCase

  alias Oli.Accounts
  alias Lti_1p3.Tool.ContextRoles

  def make_user() do
    %{
      sub: "1234-1234",
      name: "User Name",
      given_name: "User",
      family_name: "Name",
      middle_name: "",
      email: "user@example.edu",
      email_verified: true,
    }
  end

  describe "insert or update" do

    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
    end

    test "inserts, then updates", %{section: section} do

      institution_id = section.institution_id

      {:ok, user1} = Accounts.insert_or_update_lms_user(make_user(), institution_id)
      Oli.Delivery.Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_learner)])
      {:ok, user2} = Accounts.insert_or_update_lms_user(make_user(), institution_id)

      assert user1.id == user2.id
    end

    test "inserts, then inserts", %{section: section} do

      institution_id = section.institution_id

      {:ok, user1} = Accounts.insert_or_update_lms_user(make_user(), institution_id)
      {:ok, user2} = Accounts.insert_or_update_lms_user(make_user(), institution_id)

      refute user1.id == user2.id
    end
  end
end
