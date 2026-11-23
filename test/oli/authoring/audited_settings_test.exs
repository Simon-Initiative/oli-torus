defmodule Oli.Authoring.AuditedSettingsTest do
  # The audit failure test adds a trigger to the audit table, which locks it until the test ends.
  use Oli.DataCase, async: false

  import ExUnit.CaptureLog
  import Oli.Factory

  alias Oli.Auditing.Context
  alias Oli.Authoring.Audited
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project

  setup do
    author = insert(:author)
    context = Context.for_actor(author, source: :ui)
    {:ok, %{project: project}} = Audited.create_project(context, "Biology", author)
    %{author: author, context: context, project: project}
  end

  describe "update_project_settings/4" do
    test "records the fields that changed", %{context: context, project: project, author: author} do
      assert {:ok, %Project{title: "Chemistry"}} =
               Audited.update_project_settings(
                 context,
                 project.id,
                 %{"title" => "Chemistry", "description" => project.description},
                 [:title, :description]
               )

      event = assert_audited(:project_settings_changed, project_id: project.id, actor: author)
      assert event.event_key == "project:#{project.id}:settings_changed"

      assert event.changes == %{
               "title" => %{"operation" => "set", "before" => "Biology", "after" => "Chemistry"}
             }
    end

    test "merges attributes into the persisted embed and records each subfield", %{
      context: context,
      project: project
    } do
      {:ok, _} =
        Audited.update_project_settings(
          context,
          project.id,
          %{attributes: %{learning_language: "es", coverage_formative_threshold: 4}},
          [:attributes]
        )

      assert {:ok, updated} =
               Audited.update_project_settings(
                 context,
                 project.id,
                 %{attributes: %{coverage_summative_threshold: 5}},
                 [:attributes]
               )

      assert updated.attributes.learning_language == "es"
      assert updated.attributes.coverage_formative_threshold == 4
      assert updated.attributes.coverage_summative_threshold == 5

      assert [first, second] = audit_events(:project_settings_changed, project_id: project.id)
      assert Map.keys(first.changes) == ["coverage_formative_threshold", "learning_language"]

      assert second.changes == %{
               "coverage_summative_threshold" => %{
                 "operation" => "set",
                 "before" => 3,
                 "after" => 5
               }
             }
    end

    test "an update that changes nothing records nothing", %{context: context, project: project} do
      assert {:ok, _} =
               Audited.update_project_settings(
                 context,
                 project.id,
                 %{auto_update_sections: project.auto_update_sections},
                 [:auto_update_sections]
               )

      assert audit_events(:project_settings_changed, project_id: project.id) == []
    end

    test "a key outside the form's fields is protected", %{context: context, project: project} do
      assert {:error, :protected} =
               Audited.update_project_settings(
                 context,
                 project.id,
                 %{"title" => "Other", "visibility" => "global"},
                 [:title]
               )

      assert Course.get_project!(project.id).title == "Biology"
      assert audit_events(:project_settings_changed, project_id: project.id) == []
    end

    test "a form that lists a field that is not a setting is a programming error", %{
      context: context,
      project: project
    } do
      assert_raise ArgumentError, fn ->
        Audited.update_project_settings(context, project.id, %{slug: "other"}, [:slug])
      end
    end

    test "an invalid change returns the changeset and records nothing", %{
      context: context,
      project: project
    } do
      assert {:error, %Ecto.Changeset{}} =
               Audited.update_project_settings(context, project.id, %{title: nil}, [:title])

      assert audit_events(:project_settings_changed, project_id: project.id) == []
    end

    test "an audit failure rolls the change back", %{context: context, project: project} do
      reject_audit_inserts()

      capture_log(fn ->
        assert {:error, _} =
                 Audited.update_project_settings(context, project.id, %{title: "Other"}, [:title])
      end)

      assert Course.get_project!(project.id).title == "Biology"
    end
  end

  describe "enable_triggers/2" do
    test "records activation_settings_changed once", %{context: context, project: project} do
      assert {:ok, %Project{allow_triggers: true}} = Audited.enable_triggers(context, project.id)
      assert {:ok, %Project{allow_triggers: true}} = Audited.enable_triggers(context, project.id)

      event = assert_audited(:activation_settings_changed, project_id: project.id)

      assert event.changes == %{
               "allow_triggers" => %{"operation" => "set", "before" => false, "after" => true}
             }

      assert audit_events(:project_settings_changed, project_id: project.id) == []
    end
  end

  describe "project survey" do
    test "creation and deletion record the survey link", %{context: context, project: project} do
      assert {:ok, revision} = Audited.create_project_survey(context, project.id)
      assert Course.get_project!(project.id).required_survey_resource_id == revision.resource_id

      assert {:error, "The project already has a survey"} =
               Audited.create_project_survey(context, project.id)

      assert {:ok, %Project{required_survey_resource_id: nil}} =
               Audited.delete_project_survey(context, project.id)

      assert {:error, "The project doesn't have a survey"} =
               Audited.delete_project_survey(context, project.id)

      assert [created, deleted] = audit_events(:project_settings_changed, project_id: project.id)

      assert created.changes == %{
               "required_survey_resource_id" => %{
                 "operation" => "set",
                 "before" => nil,
                 "after" => revision.resource_id
               }
             }

      assert deleted.changes["required_survey_resource_id"]["after"] == nil
    end
  end

  describe "complete_import/3" do
    test "writes the late import fields inside the import that created the project", %{
      author: author,
      context: context
    } do
      title = "Imported #{System.unique_integer([:positive])}"

      {:ok, project} =
        Repo.transaction(fn ->
          {:ok, %{project: project}} = Audited.import_project(context, title, author, :naive, %{})

          {:ok, project} =
            Audited.complete_import(context, project, %{
              customizations: %{unit: "Chapter", module: "Module", section: "Section"}
            })

          project
        end)

      assert project.customizations.unit == "Chapter"
      assert_audited(:project_imported, project_id: project.id)
      assert audit_events(:project_settings_changed, project_id: project.id) == []
    end

    test "refuses other fields, other operations, and calls outside a transaction", %{
      author: author,
      context: context,
      project: project
    } do
      # Fields other than the late import fields
      assert {:error, :protected} = Audited.complete_import(context, project, %{title: "Other"})

      # A project that this operation did not import
      assert {:ok, {:error, :not_importing}} =
               Repo.transaction(fn ->
                 Audited.complete_import(context, project, %{customizations: nil})
               end)

      # An earlier import, under another operation
      {:ok, imported} =
        Repo.transaction(fn ->
          {:ok, %{project: imported}} =
            Audited.import_project(context, "Earlier", author, :naive, %{})

          imported
        end)

      later = Context.for_actor(author, source: :ui)

      assert {:ok, {:error, :not_importing}} =
               Repo.transaction(fn ->
                 Audited.complete_import(later, imported, %{customizations: nil})
               end)

      # Outside any transaction
      assert {:error, :not_importing} =
               Audited.complete_import(context, imported, %{customizations: nil})
    end
  end

  describe "update_visibility_grants/3" do
    test "records granted and removed access, skipping no-ops", %{
      context: context,
      project: project
    } do
      grantee = insert(:author)
      institution = insert(:institution)

      assert {:ok, [_, _]} =
               Oli.Publishing.Audited.update_visibility_grants(context, project.id, %{
                 add: [{:author, grantee.id}, {:institution, institution.id}]
               })

      # Adding an existing grant and removing a missing one change nothing
      assert {:ok, [_, _]} =
               Oli.Publishing.Audited.update_visibility_grants(context, project.id, %{
                 add: [{:author, grantee.id}],
                 remove: [{:author, insert(:author).id}]
               })

      assert {:ok, [_]} =
               Oli.Publishing.Audited.update_visibility_grants(context, project.id, %{
                 remove: [{:author, grantee.id}]
               })

      assert [added, removed] = audit_events(:project_settings_changed, project_id: project.id)

      assert added.changes == %{
               "visibility_grants" => %{
                 "operation" => "added",
                 "after" => [%{"author_id" => grantee.id}, %{"institution_id" => institution.id}]
               }
             }

      assert removed.changes == %{
               "visibility_grants" => %{
                 "operation" => "removed",
                 "before" => [%{"author_id" => grantee.id}]
               }
             }
    end
  end

  describe "alternatives groups" do
    test "creation and edits record the group; unchanged edits record nothing", %{
      author: author,
      context: context,
      project: project
    } do
      content = %{
        "options" => [%{"id" => "a", "name" => "A"}],
        "strategy" => "user_section_preference"
      }

      assert {:ok, group} =
               Audited.create_alternatives_group(context, project.slug, author, %{
                 title: "Mode",
                 content: content
               })

      assert {:ok, _} =
               Audited.edit_alternatives_group(
                 context,
                 project.slug,
                 group.resource_id,
                 author,
                 %{
                   title: "Mode"
                 }
               )

      assert {:ok, _} =
               Audited.edit_alternatives_group(
                 context,
                 project.slug,
                 group.resource_id,
                 author,
                 %{
                   title: "Reading mode"
                 }
               )

      assert [created, renamed] = audit_events(:project_settings_changed, project_id: project.id)
      assert created.details == %{"alternatives_group_id" => group.resource_id}

      assert created.changes["alternatives_groups"] == %{
               "operation" => "added",
               "after" => [
                 %{
                   "resource_id" => group.resource_id,
                   "title" => "Mode",
                   "strategy" => "user_section_preference",
                   "options" => [%{"id" => "a", "name" => "A"}]
                 }
               ]
             }

      assert [%{"title" => "Reading mode"}] = renamed.changes["alternatives_groups"]["after"]
    end

    test "an audit failure leaves no group", %{author: author, context: context, project: project} do
      reject_audit_inserts()

      capture_log(fn ->
        assert {:error, _} =
                 Audited.create_alternatives_group(context, project.slug, author, %{
                   title: "Rejected",
                   content: %{"options" => []}
                 })
      end)

      refute Oli.Publishing.AuthoringResolver.from_title(project.slug, "Rejected") |> Enum.any?()
    end
  end
end
