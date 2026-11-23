defmodule Oli.Delivery.Sections.AuditedSettingsTest do
  use Oli.DataCase

  import Ecto.Query, only: [from: 2]
  import Oli.Factory

  alias Oli.Auditing.Context
  alias Oli.Delivery.Sections.Audited
  alias Oli.Delivery.Sections.{Section, SectionResource}
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Utils.Seeder

  setup do
    author = insert(:author)

    seeds =
      Seeder.Project.create_sample_project(%{}, author,
        project_tag: :project,
        publication_tag: :publication
      )

    survey = create_project_survey_fixture(seeds.project, author)
    Seeder.Project.ensure_published(seeds, seeds.publication)
    publication = Oli.Publishing.get_latest_published_publication_by_slug(seeds.project.slug)

    {:ok, section} =
      Audited.create_section_from_publication(
        audit_context(),
        publication,
        %{
          title: "Settings",
          type: :enrollable,
          base_project_id: seeds.project.id,
          context_id: UUID.uuid4(),
          open_and_free: true
        },
        rebuild: true
      )

    %{section: section, survey: survey, instructor: insert(:user)}
  end

  describe "settings forms" do
    test "write only the allowed fields and record the audited ones that changed", %{
      section: section,
      instructor: instructor
    } do
      context = Context.for_actor(instructor, source: :ui)

      assert {:ok, updated} =
               Audited.update_section_settings(
                 context,
                 section,
                 %{
                   "title" => "Renamed",
                   "grace_period_days" => "5",
                   "context_id" => "pushed",
                   "registration_open" => "true"
                 },
                 [:title, :grace_period_days]
               )

      assert {updated.title, updated.grace_period_days, updated.context_id,
              updated.registration_open} ==
               {"Renamed", 5, section.context_id, section.registration_open}

      event =
        assert_audited(:section_settings_changed,
          section_id: section.id,
          actor: instructor,
          source: :ui
        )

      # Payment settings are written without an event until their own events exist
      assert Map.keys(event.changes) == ["title"]

      assert {event.entity_type, event.event_key} ==
               {:section, "section:#{section.id}:settings_changed"}
    end

    test "a save that changes nothing records nothing", %{section: section} do
      assert {:ok, _} =
               Audited.update_section_settings(
                 audit_context(),
                 section,
                 %{title: section.title},
                 [:title]
               )

      assert audit_events(:section_settings_changed, section_id: section.id) == []
    end

    test "fields no settings form writes are refused", %{section: section} do
      for field <- [
            :grade_passback_enabled,
            :context_id,
            :assistant_enabled,
            :previous_next_index
          ] do
        assert {:error, :invalid_request} =
                 Audited.update_section_settings(audit_context(), section, %{}, [field])
      end
    end

    test "the publication update policy has its own event", %{section: section} do
      assert {:ok, _} =
               Audited.update_section_settings(
                 audit_context(),
                 section,
                 %{apply_major_updates: true},
                 [:apply_major_updates]
               )

      event = assert_audited(:publication_update_policy_changed, section_id: section.id)
      assert event.project_id == section.base_project_id
      assert audit_events(:section_settings_changed, section_id: section.id) == []
    end

    test "archiving and reactivating through the status field", %{section: section} do
      assert {:ok, archived} =
               Audited.update_section_settings(
                 audit_context(),
                 section,
                 %{status: :archived},
                 [:status]
               )

      assert_audited(:section_archived, section_id: section.id)
      assert audit_events(:section_settings_changed, section_id: section.id) == []

      assert {:ok, _} =
               Audited.update_section_settings(
                 audit_context(),
                 archived,
                 %{status: :active},
                 [:status]
               )

      event = assert_audited(:section_settings_changed, section_id: section.id)

      assert event.changes["status"] == %{
               "operation" => "set",
               "before" => "archived",
               "after" => "active"
             }
    end

    test "nothing is written when the event cannot be recorded", %{section: section} do
      reject_audit_inserts()

      assert {:error, _} =
               capture_log_result(fn ->
                 Audited.update_section_settings(
                   audit_context(),
                   section,
                   %{title: "Unrecorded"},
                   [:title]
                 )
               end)

      assert Repo.get!(Section, section.id).title == section.title
    end
  end

  describe "DOT settings" do
    test "a prompt longer than 2,000 characters is recorded cut, with prompt_truncated", %{
      section: section
    } do
      prompt = String.duplicate("a", 2_100)

      assert {:ok, updated} =
               Audited.update_section_dot(
                 audit_context(),
                 section,
                 %{page_prompt_template: prompt},
                 [:page_prompt_template]
               )

      assert updated.page_prompt_template == prompt

      event = assert_audited(:dot_settings_changed, section_id: section.id)
      assert String.length(event.changes["page_prompt_template"]["after"]) == 2_000
      assert event.details["prompt_truncated"] == true
    end

    test "settings forms cannot write DOT settings, nor DOT commands other settings", %{
      section: section
    } do
      assert {:error, :invalid_request} =
               Audited.update_section_dot(audit_context(), section, %{}, [:title])

      assert {:error, :invalid_request} =
               Audited.update_section_settings(audit_context(), section, %{}, [:triggers_enabled])
    end
  end

  describe "required survey" do
    test "is required and removed with a settings event", %{section: section, survey: survey} do
      assert {:ok, with_survey} = Audited.create_section_survey(audit_context(), section)
      assert with_survey.required_survey_resource_id == survey.resource_id

      assert {:error, :survey_already_required} =
               Audited.create_section_survey(audit_context(), with_survey)

      assert {:ok, without_survey} = Audited.delete_section_survey(audit_context(), with_survey)
      assert without_survey.required_survey_resource_id == nil

      assert {:error, :no_required_survey} =
               Audited.delete_section_survey(audit_context(), without_survey)

      assert [created, deleted] =
               audit_events(:section_settings_changed, section_id: section.id)

      assert created.changes["required_survey_resource_id"]["after"] == survey.resource_id
      assert deleted.changes["required_survey_resource_id"]["after"] == nil
    end
  end

  describe "discussions" do
    test "the course board records its configuration and the section flag", %{
      section: section
    } do
      assert {:ok, %{section: updated, section_resource: root}} =
               Audited.update_course_discussions(audit_context(), section, %{status: :enabled})

      assert {updated.contains_discussions, root.collab_space_config.status} == {true, :enabled}

      event = assert_audited(:discussion_settings_changed, section_id: section.id)
      assert event.entity_type == :section
      assert event.changes["contains_discussions"]["after"] == true

      assert {:ok, %{section: unchanged_flag}} =
               Audited.update_course_discussions(audit_context(), updated, %{auto_accept: false})

      assert unchanged_flag.contains_discussions

      [_, auto_accept] = audit_events(:discussion_settings_changed, section_id: section.id)
      assert Map.keys(auto_accept.changes) == ["auto_accept"]
    end

    test "a section without a root container is not found" do
      section = insert(:section, root_section_resource_id: nil)

      assert {:error, :not_found} =
               Audited.update_course_discussions(audit_context(), section, %{status: :enabled})
    end

    test "a page records its configuration as a resource of the section", %{section: section} do
      page = first_page(section)

      assert {:ok, %{section_resource: updated_page}} =
               Audited.update_page_discussions(
                 audit_context(),
                 section,
                 page.resource_id,
                 %{status: :enabled, threaded: false}
               )

      assert %CollabSpaceConfig{status: :enabled, threaded: false} =
               updated_page.collab_space_config

      event =
        assert_audited(:discussion_settings_changed,
          section_id: section.id,
          resource_id: page.resource_id
        )

      assert {event.entity_type, event.entity_id} == {:resource, to_string(page.resource_id)}
    end
  end

  describe "generic section resource writer" do
    test "refuses the discussion configuration", %{section: section} do
      page = first_page(section)

      assert {:error, :protected} =
               Oli.Delivery.Sections.update_section_resource(page, %{
                 collab_space_config: %{status: :enabled}
               })

      assert Repo.get!(SectionResource, page.id).collab_space_config == page.collab_space_config
    end
  end

  # A curriculum entry other than the root container.
  defp first_page(section) do
    Repo.one!(
      from(sr in SectionResource,
        where: sr.section_id == ^section.id and sr.id != ^section.root_section_resource_id,
        order_by: sr.id,
        limit: 1
      )
    )
  end

  defp capture_log_result(fun) do
    {result, _log} = ExUnit.CaptureLog.with_log(fun)
    result
  end
end
