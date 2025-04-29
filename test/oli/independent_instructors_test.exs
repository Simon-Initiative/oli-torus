defmodule Oli.IndependentLearnersTest do
  use Oli.DataCase
  alias Oli.Delivery.Sections
  alias Oli.Accounts

  describe "independent learners and instructors" do
    setup do
      map = Seeder.base_project_with_resource2()

      independent_learner = user_fixture(%{independent_learner: true})

      {:ok, independent_instructor} =
        Accounts.update_user_platform_roles(
          user_fixture(%{can_create_sections: true, independent_learner: true}),
          [
            Lti_1p3.Roles.PlatformRoles.get_role(:institution_instructor)
          ]
        )

      {:ok,
       Map.merge(map, %{
         independent_learner: independent_learner,
         independent_instructor: independent_instructor
       })}
    end

    test "user_is_independent_learner/1", %{
      independent_instructor: independent_instructor,
      independent_learner: independent_learner
    } do
      user = Accounts.get_user!(independent_instructor.id, preload: [:platform_roles])

      assert Sections.is_independent_instructor?(user)
      refute Sections.is_independent_instructor?(independent_learner)

      assert Lti_1p3.Roles.PlatformRoles.has_roles?(
               user,
               [
                 Lti_1p3.Roles.PlatformRoles.get_role(:institution_instructor)
               ],
               :all
             )
    end
  end
end
