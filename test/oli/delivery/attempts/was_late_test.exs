defmodule Oli.Delivery.Attempts.WasLateTest do
  use Oli.DataCase

  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Attempts.PageLifecycle.AttemptState

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

  describe "verify was_late tracking" do
    setup do
      map = Seeder.base_project_with_resource2()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_activity(%{title: "title 1", content: @content_manual}, :publication, :project, :author, :activity_a)

      # page content that references :activity_a
      content = %{
        "advancedDelivery" => false,
        "advancedAuthoring" => false,
        "model" => [
          %{
            "id" => "1649184696677",
            "type" => "activity-reference",
            "activity_id" => map.activity_a.resource.id,
          }
        ]
      }

      map
      |> Seeder.add_page(%{graded: true, content: content}, :graded_page1)
      |> Seeder.ensure_published()
      |> Seeder.create_section()
      |> Seeder.create_section_resources()
    end

    test "finalization after time limit results in was_late being set to true", %{
      section: section,
      graded_page1: page,
      user1: user,
    } do

      Oli.Delivery.Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      datashop_session_id_user1 = UUID.uuid4()

      effective_settings = %Oli.Delivery.Settings.Combined{time_limit: 5}
      sr = Oli.Delivery.Sections.get_section_resource(section.id, page.resource.id)
      Oli.Delivery.Sections.update_section_resource(sr, %{time_limit: 5})

      Oli.Delivery.Attempts.Core.track_access(page.resource.id, section.id, user.id)

      activity_provider = &Oli.Delivery.ActivityProvider.provide/6
      {:ok, %AttemptState{resource_attempt: ra}} = PageLifecycle.start(page.revision.slug, section.slug, datashop_session_id_user1, user, effective_settings, activity_provider)

      sql = """
      UPDATE resource_attempts SET inserted_at = inserted_at - interval '8 minutes'
      WHERE id = $1
      """

      {:ok, _} = Ecto.Adapters.SQL.query(Oli.Repo, sql, [ra.id])

      {:ok, %ResourceAccess{} = resource_access} =
        PageLifecycle.finalize(section.slug, ra.attempt_guid, datashop_session_id_user1)

      ra1 = Core.get_resource_attempt_by(attempt_guid: ra.attempt_guid)
      assert ra1.was_late
      assert resource_access.was_late
    end

    test "finalization after time limit results in was_late being set to false, considering grace period", %{
      section: section,
      graded_page1: page,
      user1: user,
    } do

      Oli.Delivery.Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      datashop_session_id_user1 = UUID.uuid4()

      effective_settings = %Oli.Delivery.Settings.Combined{time_limit: 5, grace_period: 4}
      sr = Oli.Delivery.Sections.get_section_resource(section.id, page.resource.id)
      Oli.Delivery.Sections.update_section_resource(sr, %{time_limit: 5, grace_period: 4})

      Oli.Delivery.Attempts.Core.track_access(page.resource.id, section.id, user.id)

      activity_provider = &Oli.Delivery.ActivityProvider.provide/6
      {:ok, %AttemptState{resource_attempt: ra}} = PageLifecycle.start(page.revision.slug, section.slug, datashop_session_id_user1, user, effective_settings, activity_provider)

      sql = """
      UPDATE resource_attempts SET inserted_at = inserted_at - interval '8 minutes'
      WHERE id = $1
      """

      {:ok, _} = Ecto.Adapters.SQL.query(Oli.Repo, sql, [ra.id])

      {:ok, %ResourceAccess{} = resource_access} =
        PageLifecycle.finalize(section.slug, ra.attempt_guid, datashop_session_id_user1)

      ra1 = Core.get_resource_attempt_by(attempt_guid: ra.attempt_guid)
      refute ra1.was_late
      refute resource_access.was_late
    end
  end

end
