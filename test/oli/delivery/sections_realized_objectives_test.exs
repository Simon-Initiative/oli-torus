defmodule Oli.Delivery.SectionsRealizedObjectivesTest do
  use Oli.DataCase, async: true

  import Ecto.Query
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Analytics.Summary.{ResourcePartResponse, StudentResponse}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.ContainedObjective
  alias Oli.Repo
  alias Oli.Resources.ResourceType

  setup do
    seeds = Oli.TestHelpers.create_full_project_with_objectives()
    Repo.delete_all(from(co in ContainedObjective, where: co.section_id == ^seeds.section.id))

    activity =
      insert(:revision,
        resource_type_id: ResourceType.id_for_activity(),
        objectives: %{
          "answered" => [seeds.resources.obj_resource_a.id],
          "unanswered" => [seeds.resources.obj_resource_b.id]
        }
      )

    insert(:published_resource,
      publication: seeds.publication,
      revision: activity,
      resource: activity.resource
    )

    Map.put(seeds, :activity, activity)
  end

  test "deduplicates realized parts across 400 learners and retains their page containers",
       seeds do
    students = insert_list(400, :user)
    learner = ContextRoles.get_role(:context_learner)
    Sections.enroll(Enum.map(students, & &1.id), seeds.section.id, [learner])

    Enum.each(students, fn student ->
      record_response(seeds, student)
      record_summary(seeds, student)
    end)

    # Another response variant for the same learner/part must not add another objective.
    record_response(seeds, hd(students), response: "another response")

    [objective] = Sections.get_objectives_and_subobjectives(seeds.section)
    assert objective.resource_id == seeds.resources.obj_resource_a.id

    assert MapSet.new(objective.container_ids) ==
             MapSet.new([
               nil,
               seeds.resources.unit_resource.id,
               seeds.resources.module_resource_1.id
             ])

    assert objective.student_proficiency_obj_dist == %{"Not enough data" => 400}
  end

  for excluded <- [
        :instructor,
        :suspended,
        :other_section,
        :other_user,
        :other_part,
        :no_attempts,
        :project_summary,
        :deleted_activity
      ] do
    @excluded excluded
    test "ignores evidence from #{@excluded}", seeds do
      student = insert(:user)
      role = if @excluded == :instructor, do: :context_instructor, else: :context_learner
      status = if @excluded == :suspended, do: :suspended, else: :enrolled
      Sections.enroll(student.id, seeds.section.id, [ContextRoles.get_role(role)], status)

      response_opts =
        case @excluded do
          :other_section -> [section_id: insert(:section).id]
          _ -> []
        end

      summary_opts =
        case @excluded do
          :other_user -> [user_id: insert(:user).id]
          :other_part -> [part_id: "unanswered"]
          :no_attempts -> [num_attempts: 0]
          :project_summary -> [project_id: seeds.project.id]
          _ -> []
        end

      case @excluded do
        :deleted_activity ->
          seeds.activity |> Ecto.Changeset.change(deleted: true) |> Repo.update!()

        _ ->
          :ok
      end

      record_response(seeds, student, response_opts)
      record_summary(seeds, student, summary_opts)

      assert Sections.get_objectives_and_subobjectives(seeds.section) == []
    end
  end

  defp record_response(seeds, student, opts \\ []) do
    response =
      Repo.insert!(%ResourcePartResponse{
        resource_id: seeds.activity.resource_id,
        part_id: "answered",
        response: Keyword.get(opts, :response, "response #{student.id}"),
        label: "response"
      })

    Repo.insert!(%StudentResponse{
      section_id: Keyword.get(opts, :section_id, seeds.section.id),
      user_id: student.id,
      page_id: seeds.resources.page_resource_2.id,
      resource_part_response_id: response.id
    })
  end

  defp record_summary(seeds, student, opts \\ []) do
    insert(
      :resource_summary,
      Keyword.merge(
        [
          section_id: seeds.section.id,
          user_id: student.id,
          resource_id: seeds.activity.resource_id,
          resource_type_id: ResourceType.id_for_activity(),
          project_id: -1,
          part_id: "answered",
          num_attempts: 1
        ],
        opts
      )
    )
  end
end
