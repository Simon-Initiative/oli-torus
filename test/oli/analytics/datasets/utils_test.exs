defmodule Oli.Analytics.Datasets.UtilsTest do
  use Oli.DataCase

  alias Oli.Analytics.Datasets.Utils
  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections

  def enroll(section, attrs, roles) do
    {:ok, user} =
      User.noauth_changeset(
        %User{
          sub: UUID.uuid4(),
          name: "Ms Jane Marie Doe",
          given_name: "Jane",
          family_name: "Doe",
          middle_name: "Marie",
          picture: "https://platform.example.edu/jane.jpg",
          email: "jane#{System.unique_integer([:positive])}@platform.example.edu",
          locale: "en-US",
          independent_learner: false,
          age_verified: true
        },
        attrs
      )
      |> Repo.insert()

    Sections.enroll(user.id, section.id, roles)

    user.id
  end

  describe "determining user ids to ignore" do
    setup do
      map = Seeder.base_project_with_resource2()

      {:ok, section} =
        Sections.create_section(%{
          title: "Section Title",
          registration_open: true,
          open_and_free: true,
          context_id: UUID.uuid4(),
          institution_id: map.institution.id,
          base_project_id: map.project.id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(map.publication)

      Map.put(map, :section, section)
    end

    test "with instructors and students", %{section: section} do
      # Enroll an instructor
      instructor_id =
        enroll(section, %{research_opt_out: false}, [ContextRoles.get_role(:context_instructor)])

      # Enroll a student who opts out
      opt_out_student_id =
        enroll(section, %{research_opt_out: true}, [ContextRoles.get_role(:context_learner)])

      # Enroll a student who does not opt out
      student_id =
        enroll(section, %{research_opt_out: false}, [ContextRoles.get_role(:context_learner)])

      # Verify that only the instructor and opt-out student are ignored
      results = Utils.determine_ignored_student_ids([section.id])
      assert Enum.count(results) == 2
      assert Enum.any?(results, fn id -> id == instructor_id end)
      assert Enum.any?(results, fn id -> id == opt_out_student_id end)
      refute Enum.any?(results, fn id -> id == student_id end)
    end

    test "with students that have both learner and member roles assigned", %{section: section} do
      # Enroll an instructor
      instructor_id =
        enroll(section, %{research_opt_out: false}, [ContextRoles.get_role(:context_instructor)])

      # Enroll a student who opts out
      opt_out_student_id =
        enroll(section, %{research_opt_out: true}, [
          ContextRoles.get_role(:context_learner),
          ContextRoles.get_role(:context_member)
        ])

      # Enroll a student who does not opt out
      student_id =
        enroll(section, %{research_opt_out: false}, [
          ContextRoles.get_role(:context_learner),
          ContextRoles.get_role(:context_member)
        ])

      # Verify that only the instructor and opt-out student are ignored
      results = Utils.determine_ignored_student_ids([section.id])
      assert Enum.count(results) == 2
      assert Enum.any?(results, fn id -> id == instructor_id end)
      assert Enum.any?(results, fn id -> id == opt_out_student_id end)
      refute Enum.any?(results, fn id -> id == student_id end)
    end
  end
end
