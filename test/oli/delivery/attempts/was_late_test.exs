defmodule Oli.Delivery.Attempts.WasLateTest do
  use Oli.DataCase

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Attempts.PageLifecycle.AttemptState
  alias Oli.Delivery.Attempts.PageLifecycle.FinalizationSummary
  alias Oli.Delivery.Sections.SectionResource

  @content_manual %{
    "stem" => "2",
    "authoring" => %{
      "parts" => [
        %{
          "id" => "1",
          "responses" => [],
          "scoringStrategy" => "best",
          "gradingApproach" => "automatic"
        }
      ]
    }
  }

  defp setup_was_late(_) do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_activity(
        %{title: "title 1", content: @content_manual},
        :publication,
        :project,
        :author,
        :activity_a
      )

    # page content that references :activity_a
    content = %{
      "advancedDelivery" => false,
      "advancedAuthoring" => false,
      "model" => [
        %{
          "id" => "1649184696677",
          "type" => "activity-reference",
          "activity_id" => map.activity_a.resource.id
        }
      ]
    }

    map
    |> Seeder.add_page(%{graded: true, content: content}, :graded_page1)
    |> Seeder.ensure_published()
    |> Seeder.create_section()
    |> Seeder.create_section_resources()
  end

  describe "verify was_late tracking" do
    setup [:setup_tags, :setup_was_late]

    @tag isolation: "serializable"
    test "finalization after time limit results in was_late being set to true", %{
      section: section,
      graded_page1: page,
      user1: user
    } do
      Oli.Delivery.Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      datashop_session_id_user1 = UUID.uuid4()

      effective_settings = %Oli.Delivery.Settings.Combined{
        time_limit: 5,
        scheduling_type: :due_by
      }

      sr = Oli.Delivery.Sections.get_section_resource(section.id, page.resource.id)

      Oli.Delivery.Sections.update_section_resource(sr, %{
        time_limit: 5,
        scheduling_type: :due_by
      })

      Oli.Delivery.Attempts.Core.track_access(page.resource.id, section.id, user.id)

      activity_provider = &Oli.Delivery.ActivityProvider.provide/7

      {:ok, %AttemptState{resource_attempt: ra}} =
        PageLifecycle.start(
          page.revision.slug,
          section.slug,
          datashop_session_id_user1,
          user,
          effective_settings,
          activity_provider
        )

      sql = """
      UPDATE resource_attempts SET inserted_at = inserted_at - interval '8 minutes'
      WHERE id = $1
      """

      {:ok, _} = Ecto.Adapters.SQL.query(Oli.Repo, sql, [ra.id])

      {:ok, %FinalizationSummary{resource_access: resource_access}} =
        PageLifecycle.finalize(section.slug, ra.attempt_guid, datashop_session_id_user1)

      ra1 = Core.get_resource_attempt_by(attempt_guid: ra.attempt_guid)
      assert ra1.was_late
      assert resource_access.was_late
    end

    @tag isolation: "serializable"
    test "finalization after time limit results in was_late being set to false, considering grace period",
         %{
           section: section,
           graded_page1: page,
           user1: user
         } do
      Oli.Delivery.Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      datashop_session_id_user1 = UUID.uuid4()

      effective_settings = %Oli.Delivery.Settings.Combined{time_limit: 5, grace_period: 4}
      sr = Oli.Delivery.Sections.get_section_resource(section.id, page.resource.id)
      Oli.Delivery.Sections.update_section_resource(sr, %{time_limit: 5, grace_period: 4})

      Oli.Delivery.Attempts.Core.track_access(page.resource.id, section.id, user.id)

      activity_provider = &Oli.Delivery.ActivityProvider.provide/7

      {:ok, %AttemptState{resource_attempt: ra}} =
        PageLifecycle.start(
          page.revision.slug,
          section.slug,
          datashop_session_id_user1,
          user,
          effective_settings,
          activity_provider
        )

      sql = """
      UPDATE resource_attempts SET inserted_at = inserted_at - interval '8 minutes'
      WHERE id = $1
      """

      {:ok, _} = Ecto.Adapters.SQL.query(Oli.Repo, sql, [ra.id])

      {:ok, %FinalizationSummary{resource_access: resource_access}} =
        PageLifecycle.finalize(section.slug, ra.attempt_guid, datashop_session_id_user1)

      ra1 = Core.get_resource_attempt_by(attempt_guid: ra.attempt_guid)
      refute ra1.was_late
      refute resource_access.was_late
    end

    @tag isolation: "serializable"
    test "finalization after end date doesn't set was_late if read_by", %{
      section: section,
      graded_page1: page,
      user1: user
    } do
      Oli.Delivery.Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      datashop_session_id_user1 = UUID.uuid4()

      yesterday = DateTime.utc_now() |> DateTime.add(-1, :day)

      effective_settings = %Oli.Delivery.Settings.Combined{
        end_date: yesterday,
        scheduling_type: :read_by
      }

      sr = Oli.Delivery.Sections.get_section_resource(section.id, page.resource.id)

      Oli.Delivery.Sections.update_section_resource(sr, %{
        end_date: yesterday,
        scheduling_type: :read_by
      })

      Oli.Delivery.Attempts.Core.track_access(page.resource.id, section.id, user.id)

      activity_provider = &Oli.Delivery.ActivityProvider.provide/7

      {:ok, %AttemptState{resource_attempt: ra}} =
        PageLifecycle.start(
          page.revision.slug,
          section.slug,
          datashop_session_id_user1,
          user,
          effective_settings,
          activity_provider
        )

      {:ok, %FinalizationSummary{resource_access: resource_access}} =
        PageLifecycle.finalize(section.slug, ra.attempt_guid, datashop_session_id_user1)

      ra1 = Core.get_resource_attempt_by(attempt_guid: ra.attempt_guid)
      refute ra1.was_late
      refute resource_access.was_late
    end

    @tag isolation: "serializable"
    test "finalization after end date sets was_late", %{
      section: section,
      graded_page1: page,
      user1: user
    } do
      Oli.Delivery.Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      datashop_session_id_user1 = UUID.uuid4()

      yesterday = DateTime.utc_now() |> DateTime.add(-1, :day)

      effective_settings = %Oli.Delivery.Settings.Combined{
        end_date: yesterday,
        scheduling_type: :due_by
      }

      sr = Oli.Delivery.Sections.get_section_resource(section.id, page.resource.id)

      Oli.Delivery.Sections.update_section_resource(sr, %{
        end_date: yesterday,
        scheduling_type: :due_by
      })

      Oli.Delivery.Attempts.Core.track_access(page.resource.id, section.id, user.id)

      activity_provider = &Oli.Delivery.ActivityProvider.provide/7

      {:ok, %AttemptState{resource_attempt: ra}} =
        PageLifecycle.start(
          page.revision.slug,
          section.slug,
          datashop_session_id_user1,
          user,
          effective_settings,
          activity_provider
        )

      {:ok, %FinalizationSummary{resource_access: resource_access}} =
        PageLifecycle.finalize(section.slug, ra.attempt_guid, datashop_session_id_user1)

      ra1 = Core.get_resource_attempt_by(attempt_guid: ra.attempt_guid)
      assert ra1.was_late
      assert resource_access.was_late
    end

    @tag isolation: "serializable"
    test "start after end date fails", %{
      section: section,
      graded_page1: page,
      user1: user
    } do
      Oli.Delivery.Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      datashop_session_id_user1 = UUID.uuid4()

      yesterday = DateTime.utc_now() |> DateTime.add(-1, :day)

      sr = Oli.Delivery.Sections.get_section_resource(section.id, page.resource.id)

      Oli.Delivery.Sections.update_section_resource(sr, %{
        end_date: yesterday,
        late_start: :disallow
      })

      Oli.Delivery.Attempts.Core.track_access(page.resource.id, section.id, user.id)

      activity_provider = &Oli.Delivery.ActivityProvider.provide/7

      scheduling_types =
        Ecto.Enum.values(SectionResource, :scheduling_type) |> List.delete(:read_by)

      for scheduling_type <- scheduling_types do
        assert {:error, {:end_date_passed}} ==
                 PageLifecycle.start(
                   page.revision.slug,
                   section.slug,
                   datashop_session_id_user1,
                   user,
                   %Oli.Delivery.Settings.Combined{
                     end_date: yesterday,
                     late_start: :disallow,
                     scheduling_type: scheduling_type
                   },
                   activity_provider
                 )
      end
    end
  end
end
