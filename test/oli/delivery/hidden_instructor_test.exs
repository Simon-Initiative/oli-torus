defmodule Oli.Delivery.HiddenInstructorTest do
  use OliWeb.ConnCase

  alias Oli.Seeder
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Delivery.Sections

  describe "admins auto enroll as a hidden instructor account" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
    end

    test "enrolls the admin as a hidden instructor",
         %{
           section: section
         } do
      # Verify that no enrollments exist
      assert [] = Oli.Repo.all(Enrollment)

      # Now create a hidden instructor account for this section
      {:ok, {user, token}} = Sections.fetch_hidden_instructor(section.id)

      # Verify that the user was created
      assert user.hidden
      assert user.email_verified
      assert user.age_verified

      # Verify it was a session token created which points
      # to the newly created user
      actual_token = Oli.Repo.get_by(Oli.Accounts.UserToken, token: token)
      assert actual_token.user_id == user.id
      assert actual_token.context == "session"

      [enrollment] = Oli.Repo.all(Enrollment)
      assert enrollment.user_id == user.id
      assert enrollment.section_id == section.id
      assert enrollment.status == :enrolled

      # Verify that the user is an instructor in this section
      assert Sections.is_instructor?(user, section.slug)

      # Now call the function again to verify that it doesn't create a new user
      # but rather returns the existing one.  It should also return a new token
      # for the existing user.
      {:ok, {user2, token2}} = Sections.fetch_hidden_instructor(section.id)

      assert user2.id == user.id
      refute token2 == token
    end
  end
end
