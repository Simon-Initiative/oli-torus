defmodule Oli.Delivery.Metrics.LastInteractionTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Resources.ResourceType

  defp set_interaction(section, resource, user, timestamp) do
    insert(:resource_access, %{
      section: section,
      resource: resource,
      user: user,
      inserted_at: timestamp,
      updated_at: timestamp
    })
  end

  defp create_page(slug) do
    page_resource = insert(:resource)

    page_revision =
      insert(:revision, %{
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: ResourceType.get_id_by_type("page"),
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Page 1",
        resource: page_resource,
        slug: slug
      })

    {:ok, page_revision.resource}
  end

  describe "last_interaction calculations" do
    setup do
      section = insert(:section)

      {:ok, page_1} = create_page(section.slug)
      {:ok, page_2} = create_page(section.slug)

      [student_1, student_2] = insert_pair(:user)

      Sections.enroll(student_1.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, %{updated_at: student_2_enrollment_timestamp}} =
        Sections.enroll(student_2.id, section.id, [ContextRoles.get_role(:context_learner)])

      %{
        section: section,
        student_1: student_1,
        student_2: student_2,
        student_2_enrollment_timestamp: student_2_enrollment_timestamp,
        page_1: page_1,
        page_2: page_2
      }
    end

    test "students_last_interaction/1 calculates correctly", %{
      section: section,
      student_1: student_1,
      student_2: student_2,
      student_2_enrollment_timestamp: student_2_enrollment_timestamp,
      page_1: page_1,
      page_2: page_2
    } do
      set_interaction(section, page_1, student_1, ~U[2023-04-03 12:25:42.000000Z])
      set_interaction(section, page_2, student_1, ~U[2023-04-05 12:25:42.000000Z])

      last_interactions = Metrics.students_last_interaction_across(section)

      assert last_interactions[student_1.id] == ~U[2023-04-05 12:25:42.000000Z]

      assert last_interactions[student_2.id] |> DateTime.truncate(:second) ==
               student_2_enrollment_timestamp
    end

    test "students_last_interaction_for_page/2 calculates correctly", %{
      section: section,
      student_1: student_1,
      student_2: student_2,
      student_2_enrollment_timestamp: student_2_enrollment_timestamp,
      page_1: page_1,
      page_2: page_2
    } do
      set_interaction(section, page_1, student_1, ~U[2023-04-03 12:25:42.000000Z])
      set_interaction(section, page_2, student_1, ~U[2023-04-04 12:25:42.000000Z])

      last_interactions_for_page =
        Metrics.students_last_interaction_for_page(section.slug, page_1.id)

      assert last_interactions_for_page[student_1.id] == ~U[2023-04-03 12:25:42.000000Z]

      assert last_interactions_for_page[student_2.id] |> DateTime.truncate(:second) ==
               student_2_enrollment_timestamp
    end
  end
end
