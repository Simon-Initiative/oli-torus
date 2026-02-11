defmodule Oli.Delivery.Attempts.TargetedActivityTest do
  use Oli.DataCase

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Activities
  alias Oli.Delivery.Attempts.ActivityLifecycle
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.ActivityAttempt
  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Attempts.PageLifecycle.FinalizationSummary
  alias Oli.Delivery.Sections
  alias Oli.Repo
  alias Oli.Resources.ScoringStrategy

  defp load_targeted_activity_content do
    __DIR__
    |> Path.join("targeted_activity.json")
    |> File.read!()
    |> Jason.decode!()
  end

  defp setup_targeted_activity(_) do
    activity_type_id = Activities.get_registration_by_slug("oli_multi_input").id
    content = load_targeted_activity_content()

    map =
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_activity(
        %{
          title: "targeted activity",
          content: content,
          scope: "banked",
          activity_type_id: activity_type_id,
          scoring_strategy_id: ScoringStrategy.get_id_by_type("total")
        },
        :banked_activity
      )

    Seeder.ensure_published(map.publication.id)

    page_content = %{
      "model" => [
        %{
          "type" => "selection",
          "id" => "bank-selection-1",
          "count" => 1,
          "pointsPerActivity" => 8,
          "logic" => %{"conditions" => nil}
        }
      ]
    }

    map =
      Seeder.add_page(
        map,
        %{
          title: "graded bank selection page",
          graded: true,
          content: page_content
        },
        :container,
        :graded_page
      )
      |> Seeder.create_section_resources()

    {:ok, map}
  end

  describe "bank selection grading" do
    setup [:setup_tags, :setup_targeted_activity]

    @tag isolation: "serializable"
    test "finalize evaluates bank-selected activity using pointsPerActivity", %{
      graded_page: %{revision: revision},
      section: section,
      user1: user,
      banked_activity: banked_activity
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      effective_settings =
        Oli.Delivery.Settings.get_combined_settings(revision, section.id, user.id)

      activity_provider = &Oli.Delivery.ActivityProvider.provide/6
      datashop_session_id = UUID.uuid4()

      Core.track_access(revision.resource_id, section.id, user.id)

      {:ok,
       %PageLifecycle.AttemptState{
         resource_attempt: resource_attempt,
         attempt_hierarchy: attempt_hierarchy
       }} =
        PageLifecycle.start(
          revision.slug,
          section.slug,
          datashop_session_id,
          user,
          effective_settings,
          activity_provider
        )

      {activity_attempt, part_attempts} =
        attempt_hierarchy
        |> Map.values()
        |> hd()

      assert activity_attempt.resource_id == banked_activity.revision.resource_id

      part1_attempt = Map.fetch!(part_attempts, "1")
      part2_attempt = Map.fetch!(part_attempts, "3677703835")

      {:ok, _} =
        ActivityLifecycle.save_student_input([
          %{
            attempt_guid: part1_attempt.attempt_guid,
            response: %{input: "1s^2 2s^2 2p^3"}
          }
        ])

      # Answer part 2 in a way that trips the first response, the non-targeted one, whose
      # score is 1.  Originally, this part would have scored 1 out of 4, but new logic
      # should award full points to account for a bad model (where a "correct" targeted response
      # has a higher score than the correct, non-targeted response).
      {:ok, _} =
        ActivityLifecycle.save_student_input([
          %{
            attempt_guid: part2_attempt.attempt_guid,
            response: %{input: "1s^2 2s^2 2p^6 3s^2 3p^1"}
          }
        ])

      {:ok, %FinalizationSummary{resource_access: access}} =
        PageLifecycle.finalize(section.slug, resource_attempt.attempt_guid, datashop_session_id)

      Core.get_latest_part_attempts(activity_attempt.attempt_guid)
      |> Enum.map(fn pa ->
        %{
          part_id: pa.part_id,
          lifecycle_state: pa.lifecycle_state,
          score: pa.score,
          out_of: pa.out_of
        }
      end)

      updated_activity_attempt =
        Repo.get_by!(ActivityAttempt, attempt_guid: activity_attempt.attempt_guid)

      assert updated_activity_attempt.lifecycle_state == :evaluated
      assert updated_activity_attempt.out_of == 8.0
      assert updated_activity_attempt.score == 8.0
      assert access.out_of == 8.0
      assert access.score == 8.0
    end
  end
end
