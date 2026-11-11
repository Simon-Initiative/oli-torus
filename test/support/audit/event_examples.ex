defmodule Oli.Auditing.EventExamples do
  @moduledoc """
  One realistic version 2 row per catalog event, with every column set as its contract expects.

  These examples are the single source for the contract tests and for the generated reference
  `docs/design-docs/audit-log-events.md`. A catalog event without an example fails the suite.
  Values are fixed so the generated reference is stable.
  """

  alias Oli.Auditing.{Changes, Context, EntityId, Snapshot}

  @occurred_at ~U[2026-10-29 14:05:08.123456Z]
  @operation_id "6f1c2a9e-4b7d-4c1e-9a53-2d8e7f0b1c34"
  @parent_operation_id "0b7e4d2a-91c3-4f6e-8d25-7a1f3c9e5b40"

  @project %{id: 88, title: "Intro Biology", slug: "intro_biology"}
  @section %{id: 301, title: "Biology 101 - Fall 2026", slug: "bio_101_fall_2026"}
  @product %{id: 290, title: "Intro Biology Product", slug: "intro_bio_product"}
  @resource %{id: 4512, title: "Unit 1 Quiz"}
  @institution %{id: 9, name: "State University"}
  @learner %{id: 77, name: "Ada Student", email: "ada.student@example.edu"}
  @instructor %{id: 41, name: "Grace Hopper", email: "grace.hopper@example.edu"}
  @admin %{id: 5, name: "Alan Admin", email: "alan.admin@example.edu"}
  @author %{id: 12, name: "Katherine Author", email: "katherine.author@example.edu"}

  @doc """
  Returns the example row of an event name. Every example is a version 2 row except names
  marked `v1_only`, which are documented as migrated history.
  """
  @spec example(atom()) :: map()
  def example(name), do: name |> spec() |> build(name)

  @doc "Returns the event names that have an example."
  @spec names() :: [atom()]
  def names, do: Oli.Auditing.EventCatalog.names() |> Enum.filter(&has_example?/1)

  @doc "Returns true when the event has an example."
  @spec has_example?(atom()) :: boolean()
  def has_example?(name) do
    spec(name)
    true
  rescue
    FunctionClauseError -> false
  end

  # Authentication

  defp spec(:user_logged_in),
    do: [
      actor: :learner,
      entity: {:user, @learner},
      affected: {:user, 77},
      key: "session:user:started",
      details: %{"auth_method" => "lti", "session_ref" => 90_211}
    ]

  defp spec(:author_logged_in),
    do: [
      actor: :author,
      entity: {:author, @author},
      affected: {:author, 12},
      key: "session:author:started",
      details: %{"auth_method" => "password", "session_ref" => 4410}
    ]

  defp spec(:user_logged_out),
    do: [
      actor: :learner,
      entity: {:user, @learner},
      affected: {:user, 77},
      key: "session:user:ended",
      details: %{"session_ref" => 90_211}
    ]

  defp spec(:author_logged_out),
    do: [
      actor: :author,
      entity: {:author, @author},
      affected: {:author, 12},
      key: "session:author:ended",
      details: %{"session_ref" => 4410}
    ]

  defp spec(:session_revoked),
    do: [
      actor: :admin,
      entity: {:user, @learner},
      affected: {:user, 77},
      key: "session:user:revoked",
      details: %{"revoked_count" => 3}
    ]

  # Account

  defp spec(:account_created),
    do: [
      actor: {:system, :provider_provisioning},
      source: :system,
      entity: {:user, @learner},
      affected: {:user, 77},
      key: "account:primary:created",
      changes: %{
        "email" => %{"operation" => "set", "after" => "ada.student@example.edu"},
        "name" => %{"operation" => "set", "after" => "Ada Student"}
      },
      details: %{"creation_source" => "lti_launch"}
    ]

  defp spec(:account_updated),
    do: [
      actor: :admin,
      entity: {:user, @learner},
      affected: {:user, 77},
      key: "account:primary:updated",
      changes: %{
        "family_name" => %{"operation" => "set", "before" => "Studnet", "after" => "Student"},
        "password" => Changes.secret_record()
      }
    ]

  defp spec(:account_locked),
    do: [
      actor: :admin,
      entity: {:user, @learner},
      affected: {:user, 77},
      key: "account:primary:locked",
      changes: %{
        "locked_at" => %{"operation" => "set", "before" => nil, "after" => "2026-10-29T14:05:08Z"}
      }
    ]

  defp spec(:account_unlocked),
    do: [
      actor: :admin,
      entity: {:user, @learner},
      affected: {:user, 77},
      key: "account:primary:unlocked",
      changes: %{
        "locked_at" => %{"operation" => "set", "before" => "2026-10-01T09:00:00Z", "after" => nil}
      }
    ]

  defp spec(:account_linked),
    do: [
      actor: :instructor,
      entity: {:user, @instructor},
      affected: {:user, 41},
      key: "account:primary:linked",
      refs: [ref(:linked, :author, 12, "katherine.author@example.edu")],
      changes: %{"author_id" => %{"operation" => "set", "before" => nil, "after" => 12}}
    ]

  defp spec(:account_identity_linked),
    do: [
      actor: :learner,
      entity: {:user, @learner},
      affected: {:user, 77},
      key: "account:primary:account_identity_linked:google",
      details: %{"provider" => "google"}
    ]

  defp spec(:account_identity_unlinked),
    do: [
      actor: :learner,
      entity: {:user, @learner},
      affected: {:user, 77},
      key: "account:primary:account_identity_unlinked:google",
      details: %{"provider" => "google"}
    ]

  defp spec(:account_permissions_changed),
    do: [
      actor: :admin,
      entity: {:user, @learner},
      affected: {:user, 77},
      key: "account:primary:permissions_changed",
      changes: %{
        "independent_learner" => %{"operation" => "set", "before" => false, "after" => true}
      }
    ]

  defp spec(:account_creation_rights_changed),
    do: [
      actor: :admin,
      entity: {:user, @instructor},
      affected: {:user, 41},
      key: "account:primary:creation_rights_changed",
      changes: %{
        "can_create_sections" => %{"operation" => "set", "before" => false, "after" => true}
      }
    ]

  defp spec(:account_recovery_requested),
    do: [
      actor: {:system, :provider_provisioning},
      source: :system,
      entity: {:author, @author},
      affected: {:author, 12},
      key: "account:primary:recovery_requested",
      details: %{"recovery_kind" => "password_reset"}
    ]

  defp spec(:account_credential_recovered),
    do: [
      actor: :author,
      entity: {:author, @author},
      affected: {:author, 12},
      key: "account:primary:credential_recovered",
      changes: %{"password" => Changes.secret_record()}
    ]

  defp spec(:user_deleted),
    do: [
      actor: :admin,
      entity: {:user, @learner},
      affected: {:user, 77},
      key: "account:primary:deleted",
      details: %{
        "email" => "ada.student@example.edu",
        "name" => "Ada Student",
        "deleted_by" => "alan.admin@example.edu"
      }
    ]

  defp spec(:author_deleted),
    do: [
      actor: :admin,
      entity: {:author, @author},
      affected: {:author, 12},
      key: "account:primary:deleted",
      details: %{
        "email" => "katherine.author@example.edu",
        "name" => "Katherine Author",
        "deleted_by" => "alan.admin@example.edu"
      }
    ]

  defp spec(:author_role_changed),
    do: [
      actor: :admin,
      entity: {:author, @author},
      affected: {:author, 12},
      key: "account:primary:author_role_changed",
      changes: %{"system_role_id" => %{"operation" => "set", "before" => 1, "after" => 2}},
      details: %{"previous_role" => "author", "new_role" => "admin"}
    ]

  defp spec(:account_internal_flag_changed),
    do: [
      actor: :admin,
      entity: {:user, @instructor},
      affected: {:user, 41},
      key: "account:primary:account_internal_flag_changed",
      changes: %{"is_internal" => %{"operation" => "set", "before" => false, "after" => true}},
      details: %{"account_type" => "user", "previous" => false, "is_internal" => true}
    ]

  # Project

  defp spec(:project_created),
    do: [
      actor: :author,
      entity: {:project, @project},
      scope: [project_id: 88],
      key: "project:88:created",
      details: %{"project_title" => "Intro Biology"}
    ]

  defp spec(:project_duplicated),
    do: [
      actor: :author,
      entity: {:project, %{id: 93, title: "Copy of Intro Biology", slug: "copy_intro_biology"}},
      scope: [project_id: 93],
      key: "project:93:duplicated",
      refs: [ref(:source, :project, 88, "Intro Biology")],
      details: %{"source_project_id" => 88}
    ]

  defp spec(:project_imported),
    do: [
      actor: :admin,
      entity: {:project, @project},
      scope: [project_id: 88],
      key: "project:88:imported",
      outcome: :partial,
      details: %{"project_title" => "Intro Biology"}
    ]

  defp spec(:project_deleted),
    do: [
      actor: :author,
      entity: {:project, @project},
      scope: [project_id: 88],
      key: "project:88:deleted"
    ]

  defp spec(:project_ownership_changed),
    do: [
      actor: :admin,
      entity: {:project, @project},
      scope: [project_id: 88],
      affected: {:author, 12},
      key: "project:88:ownership_changed:author:12"
    ]

  defp spec(:project_collaborator_changed),
    do: [
      actor: :author,
      entity: {:project, @project},
      scope: [project_id: 88],
      affected: {:author, 31},
      key: "project:88:collaborator:31:changed",
      changes: %{"status" => %{"operation" => "added", "after" => "accepted"}}
    ]

  defp spec(:project_published),
    do: [
      actor: :author,
      entity: {:project, @project},
      scope: [project_id: 88],
      key: "project:88:published",
      refs: [ref(:resulting, :publication, 1204, "1.4.0")],
      details: %{
        "project_title" => "Intro Biology",
        "publication_id" => 1204,
        "version" => "1.4.0",
        "description" => "Fix quiz feedback"
      }
    ]

  # Assessment settings

  defp spec(:assessment_settings_changed),
    do: [
      actor: :instructor,
      entity: {:resource, @resource},
      scope: [section_id: 301, resource_id: 4512],
      key: "assessment:4512:settings_changed",
      changes: %{
        "max_attempts" => %{"operation" => "set", "before" => 1, "after" => 3},
        "time_limit" => %{"operation" => "set", "before" => 0, "after" => 45, "unit" => "minutes"}
      }
    ]

  defp spec(:assessment_settings_reset),
    do: [
      actor: :instructor,
      entity: {:resource, @resource},
      scope: [section_id: 301, resource_id: 4512],
      key: "assessment:4512:settings_reset",
      changes: %{
        "max_attempts" => %{
          "operation" => "reset",
          "before" => 3,
          "after" => nil,
          "effective_before" => 3,
          "effective_after" => 1,
          "result_source" => "publication"
        }
      }
    ]

  defp spec(:assessment_setting_changed),
    do: [
      actor: :instructor,
      entity: {:resource, @resource},
      scope: [section_id: 301, resource_id: 4512],
      key: "assessment:4512:setting_changed",
      changes: %{"max_attempts" => %{"operation" => "set", "before" => 1, "after" => 2}},
      v1: [legacy_source: "settings_changes", legacy_id: 120_331]
    ]

  # Student exceptions

  defp spec(:student_exception_created),
    do: [
      actor: :instructor,
      entity: student_exception_entity(),
      scope: [section_id: 301, resource_id: 4512],
      affected: {:user, 77},
      key: "exception:77:created",
      changes: %{"end_date" => %{"operation" => "set", "after" => "2026-11-05T23:59:00Z"}}
    ]

  defp spec(:student_exception_updated),
    do: [
      actor: :instructor,
      entity: student_exception_entity(),
      scope: [section_id: 301, resource_id: 4512],
      affected: {:user, 77},
      key: "exception:77:updated",
      changes: %{
        "max_attempts" => %{"operation" => "set", "before" => 2, "after" => 3},
        "password" => Changes.secret_record()
      }
    ]

  defp spec(:student_exception_deleted),
    do: [
      actor: :instructor,
      entity: student_exception_entity(),
      scope: [section_id: 301, resource_id: 4512],
      affected: {:user, 77},
      key: "exception:77:deleted",
      changes: %{"max_attempts" => %{"operation" => "set", "before" => 3}}
    ]

  # DOT and activation points

  defp spec(:dot_settings_changed),
    do: [
      actor: :instructor,
      entity: {:section, @section},
      scope: [section_id: 301],
      key: "section:301:dot_settings_changed",
      changes: %{
        "assistant_enabled" => %{"operation" => "set", "before" => false, "after" => true}
      }
    ]

  defp spec(:activation_settings_changed),
    do: [
      actor: :author,
      entity: {:project, @project},
      scope: [project_id: 88],
      key: "project:88:activation_settings_changed",
      changes: %{"allow_triggers" => %{"operation" => "set", "before" => false, "after" => true}}
    ]

  defp spec(:instructor_ai_recommendation_changed),
    do: [
      actor: :instructor,
      entity: {:section, @section},
      scope: [section_id: 301],
      key: "section:301:ai_recommendation_changed",
      changes: %{
        "instructor_recommendations_enabled" => %{
          "operation" => "set",
          "before" => true,
          "after" => false
        }
      }
    ]

  # Remix

  defp spec(:section_remix_saved),
    do: [
      actor: :instructor,
      entity: {:curriculum_entry, EntityId.compose(section: 301, resource: 4512), @resource},
      scope: [section_id: 301, resource_id: 4512],
      key: "remix:4512:saved",
      refs: [ref(:source, :publication, 1204, "Intro Biology 1.4.0")],
      changes: %{
        "position" => %{"operation" => "set", "before" => 2, "after" => 5},
        "source_publication_id" => %{"operation" => "added", "after" => 1204}
      }
    ]

  # Destructive content

  defp spec(:authoring_content_removed),
    do: [
      actor: :author,
      entity: {:resource, @resource},
      scope: [project_id: 88, resource_id: 4512],
      key: "resource:4512:removed",
      changes: %{"deleted" => %{"operation" => "set", "before" => false, "after" => true}}
    ]

  defp spec(:authoring_content_replaced),
    do: [
      actor: :author,
      entity: {:resource, @resource},
      scope: [project_id: 88, resource_id: 4512],
      key: "resource:4512:replaced",
      refs: [ref(:previous, :revision, 99_100, nil), ref(:resulting, :revision, 99_101, nil)]
    ]

  defp spec(:bank_question_deleted),
    do: [
      actor: :author,
      entity: {:resource, %{id: 5120, title: "Cell membrane question"}},
      scope: [project_id: 88, resource_id: 5120],
      key: "resource:5120:removed"
    ]

  defp spec(:media_deleted),
    do: [
      actor: :author,
      entity: {:media_item, %{id: 703, title: "mitosis.png"}},
      scope: [project_id: 88],
      key: "media:703:deleted",
      details: %{"file_name" => "mitosis.png", "mime_type" => "image/png"}
    ]

  defp spec(:google_doc_imported),
    do: [
      actor: :author,
      entity: {:project, @project},
      scope: [project_id: 88, resource_id: 4600],
      key: "project:88:google_doc_imported",
      details: %{
        "page_title" => "Week 2 Reading",
        "page_resource_id" => 4600,
        "page_revision_id" => 99_230,
        "warning_count" => 1,
        "warning_codes" => %{"unsupported_table" => 1},
        "uploaded_media_count" => 2
      }
    ]

  # Discussion

  defp spec(:discussion_post_deleted),
    do: [
      actor: :instructor,
      entity: {:post, %{id: 5501}},
      scope: [section_id: 301],
      affected: {:user, 77},
      key: "post:5501:deleted",
      details: %{"cascade_count" => 2}
    ]

  defp spec(:discussion_thread_deleted),
    do: [
      actor: :instructor,
      entity: {:thread, %{id: 5500, title: "Week 2 questions"}},
      scope: [section_id: 301],
      key: "thread:5500:deleted",
      details: %{"cascade_count" => 14}
    ]

  defp spec(:discussion_moderated),
    do: [
      actor: :instructor,
      entity: {:post, %{id: 5502}},
      scope: [section_id: 301],
      affected: {:user, 77},
      key: "post:5502:moderated",
      changes: %{
        "status" => %{"operation" => "set", "before" => "submitted", "after" => "approved"}
      }
    ]

  # Learner intervention

  defp spec(:resource_attempt_deleted),
    do: [
      actor: :instructor,
      entity: {:resource_attempt, "attempt-3f9c2d", %{}},
      scope: [section_id: 301, resource_id: 4512],
      affected: {:user, 77},
      key: "attempt:attempt-3f9c2d:deleted",
      details: %{
        "attempt_guid" => "attempt-3f9c2d",
        "attempt_number" => 2,
        "resource_access_id" => 66_010,
        "grade_sync_triggered" => false
      }
    ]

  defp spec(:learner_attempt_reset),
    do: [
      actor: :instructor,
      entity: {:resource_access, "66010", %{}},
      scope: [section_id: 301, resource_id: 4512],
      affected: {:user, 77},
      key: "access:66010:reset",
      changes: %{"attempt_number" => %{"operation" => "reset", "before" => 3, "after" => 0}},
      details: %{"reason" => "technical issue"}
    ]

  defp spec(:learner_progress_restored),
    do: [
      actor: :admin,
      entity: {:enrollment, "8812", %{}},
      scope: [section_id: 301],
      affected: {:user, 77},
      key: "enrollment:8812:progress_restored",
      outcome: :partial
    ]

  defp spec(:manual_grade_changed),
    do: [
      actor: :instructor,
      entity: {:resource_attempt, "attempt-3f9c2d", %{}},
      scope: [section_id: 301, resource_id: 4512],
      affected: {:user, 77},
      key: "attempt:attempt-3f9c2d:manual_grade_changed",
      changes: %{
        "score" => %{"operation" => "set", "before" => 6.0, "after" => 8.5},
        "out_of" => %{"operation" => "set", "before" => 10.0, "after" => 10.0}
      }
    ]

  defp spec(:learner_regraded),
    do: [
      actor: :instructor,
      entity: {:resource_attempt, "attempt-3f9c2d", %{}},
      scope: [section_id: 301, resource_id: 4512],
      affected: {:user, 77},
      key: "attempt:attempt-3f9c2d:regraded",
      changes: %{"score" => %{"operation" => "set", "before" => 7.0, "after" => 7.5}}
    ]

  # Project settings

  defp spec(:project_settings_changed),
    do: [
      actor: :author,
      entity: {:project, @project},
      scope: [project_id: 88],
      key: "project:88:settings_changed",
      changes: %{
        "visibility" => %{"operation" => "set", "before" => "authors", "after" => "global"},
        "allow_duplication" => %{"operation" => "set", "before" => false, "after" => true}
      }
    ]

  # Authoring configuration

  defp spec(:authoring_settings_changed),
    do: [
      actor: :author,
      entity: {:resource, @resource},
      scope: [project_id: 88, resource_id: 4512],
      key: "resource:4512:authoring_settings_changed",
      changes: %{"graded" => %{"operation" => "set", "before" => false, "after" => true}}
    ]

  defp spec(:learning_objectives_changed),
    do: [
      actor: :author,
      entity: {:objective, %{id: 4700, title: "Explain diffusion"}},
      scope: [project_id: 88, resource_id: 4700],
      key: "objective:4700:changed",
      changes: %{"children" => %{"operation" => "added", "after" => [4701]}}
    ]

  defp spec(:curriculum_changed),
    do: [
      actor: :author,
      entity: {:container, %{id: 4400, title: "Unit 1"}},
      scope: [project_id: 88, resource_id: 4400],
      key: "container:4400:curriculum_changed",
      changes: %{
        "children" => %{"operation" => "set", "before" => [4512, 4600], "after" => [4600, 4512]}
      }
    ]

  # Section lifecycle and settings

  defp spec(:section_created),
    do: [
      actor: :instructor,
      entity: {:section, @section},
      scope: [section_id: 301, project_id: 88, institution_id: 9],
      key: "section:301:created",
      details: %{
        "section_title" => "Biology 101 - Fall 2026",
        "type" => "enrollable",
        "base_project_id" => 88,
        "creation_source" => "lti_launch",
        "blueprint_id" => 290
      }
    ]

  defp spec(:section_deleted),
    do: [
      actor: :admin,
      entity: {:section, @section},
      scope: [section_id: 301],
      key: "section:301:deleted"
    ]

  defp spec(:section_archived),
    do: [
      actor: :admin,
      entity: {:section, @section},
      scope: [section_id: 301],
      key: "section:301:archived",
      changes: %{"status" => %{"operation" => "set", "before" => "active", "after" => "archived"}}
    ]

  defp spec(:section_settings_changed),
    do: [
      actor: :instructor,
      entity: {:section, @section},
      scope: [section_id: 301],
      key: "section:301:settings_changed",
      changes: %{
        "end_date" => %{
          "operation" => "set",
          "before" => "2026-12-15T23:59:00Z",
          "after" => "2026-12-20T23:59:00Z"
        },
        "passcode" => Changes.secret_record()
      }
    ]

  defp spec(:product_created),
    do: [
      actor: :admin,
      entity: {:product, @product},
      scope: [section_id: 290, project_id: 88],
      key: "product:290:created",
      details: %{"section_title" => "Intro Biology Product", "base_project_id" => 88}
    ]

  defp spec(:product_deleted),
    do: [
      actor: :admin,
      entity: {:product, @product},
      scope: [section_id: 290],
      key: "product:290:deleted"
    ]

  defp spec(:product_archived),
    do: [
      actor: :admin,
      entity: {:product, @product},
      scope: [section_id: 290],
      key: "product:290:archived",
      changes: %{"status" => %{"operation" => "set", "before" => "active", "after" => "archived"}}
    ]

  defp spec(:product_settings_changed),
    do: [
      actor: :admin,
      entity: {:product, @product},
      scope: [section_id: 290],
      key: "product:290:settings_changed",
      changes: %{
        "title" => %{
          "operation" => "set",
          "before" => "Intro Bio Product",
          "after" => "Intro Biology Product"
        }
      }
    ]

  defp spec(:blueprint_created),
    do: [
      actor: :author,
      entity: {:blueprint, %{id: 295, title: "Biology Blueprint"}},
      scope: [section_id: 295, project_id: 88],
      key: "blueprint:295:created",
      details: %{"section_title" => "Biology Blueprint", "base_project_id" => 88}
    ]

  defp spec(:blueprint_deleted),
    do: [
      actor: :author,
      entity: {:blueprint, %{id: 295, title: "Biology Blueprint"}},
      scope: [section_id: 295],
      key: "blueprint:295:deleted"
    ]

  defp spec(:blueprint_archived),
    do: [
      actor: :author,
      entity: {:blueprint, %{id: 295, title: "Biology Blueprint"}},
      scope: [section_id: 295],
      key: "blueprint:295:archived",
      changes: %{"status" => %{"operation" => "set", "before" => "active", "after" => "archived"}}
    ]

  defp spec(:blueprint_settings_changed),
    do: [
      actor: :author,
      entity: {:blueprint, %{id: 295, title: "Biology Blueprint"}},
      scope: [section_id: 295],
      key: "blueprint:295:settings_changed",
      changes: %{
        "welcome_title" => %{"operation" => "set", "before" => nil, "after" => "Welcome!"}
      }
    ]

  # Enrollment and access

  defp spec(:invitation_created),
    do: [
      actor: :instructor,
      entity: {:invitation, "1907", %{}},
      scope: [section_id: 301],
      affected: {:user, 77},
      key: "invitation:1907:created",
      changes: %{"context_roles" => %{"operation" => "added", "after" => ["learner"]}}
    ]

  defp spec(:invitation_accepted),
    do: [
      actor: :learner,
      entity: {:invitation, "1907", %{}},
      scope: [section_id: 301],
      affected: {:user, 77},
      key: "invitation:1907:accepted",
      changes: %{
        "status" => %{
          "operation" => "set",
          "before" => "pending_confirmation",
          "after" => "enrolled"
        }
      }
    ]

  defp spec(:enrollment_changed),
    do: [
      actor: :instructor,
      entity: {:enrollment, "8812", %{}},
      scope: [section_id: 301],
      affected: {:user, 77},
      key: "enrollment:8812:changed",
      changes: %{
        "status" => %{"operation" => "set", "before" => "enrolled", "after" => "suspended"}
      }
    ]

  defp spec(:instructor_access_changed),
    do: [
      actor: :admin,
      entity: {:enrollment, "8813", %{}},
      scope: [section_id: 301],
      affected: {:user, 41},
      key: "enrollment:8813:instructor_access_changed",
      changes: %{"context_roles" => %{"operation" => "added", "after" => ["instructor"]}}
    ]

  # Publication application

  defp spec(:publication_applied),
    do: [
      actor: {:system, :scheduled_maintenance},
      source: :job,
      parent_operation_id: @parent_operation_id,
      entity: {:section, @section},
      scope: [section_id: 301, project_id: 88],
      key: "section:301:publication:1204:applied",
      refs: [
        ref(:previous, :publication, 1190, "1.3.2"),
        ref(:resulting, :publication, 1204, "1.4.0")
      ],
      changes: %{"publication_id" => %{"operation" => "set", "before" => 1190, "after" => 1204}}
    ]

  defp spec(:publication_update_policy_changed),
    do: [
      actor: :instructor,
      entity: {:section, @section},
      scope: [section_id: 301, project_id: 88],
      key: "section:301:update_policy_changed",
      changes: %{
        "apply_major_updates" => %{"operation" => "set", "before" => false, "after" => true}
      }
    ]

  # Gating and scheduling

  defp spec(:gating_changed),
    do: [
      actor: :instructor,
      entity: {:gating_condition, %{id: 702}},
      scope: [section_id: 301, resource_id: 4512],
      affected: {:user, 77},
      key: "gating:702:changed",
      changes: %{
        "end_datetime" => %{
          "operation" => "set",
          "before" => "2026-11-01T23:59:00Z",
          "after" => "2026-11-03T23:59:00Z"
        }
      }
    ]

  defp spec(:prerequisite_changed),
    do: [
      actor: :instructor,
      entity: {:gating_condition, %{id: 703}},
      scope: [section_id: 301, resource_id: 4512],
      key: "gating:703:prerequisite_changed",
      changes: %{"minimum_percentage" => %{"operation" => "set", "before" => 0.5, "after" => 0.7}}
    ]

  defp spec(:curriculum_schedule_changed),
    do: [
      actor: :instructor,
      entity: {:section_resource, EntityId.compose(section: 301, resource: 4512), @resource},
      scope: [section_id: 301, resource_id: 4512],
      key: "schedule:4512:changed",
      changes: %{
        "scheduling_type" => %{"operation" => "set", "before" => "read_by", "after" => "due_by"}
      }
    ]

  # Support configuration

  defp spec(:discussion_settings_changed),
    do: [
      actor: :instructor,
      entity: {:section, @section},
      scope: [section_id: 301],
      key: "section:301:discussion_settings_changed",
      changes: %{
        "anonymous_posting" => %{"operation" => "set", "before" => false, "after" => true}
      }
    ]

  defp spec(:notes_settings_changed),
    do: [
      actor: :instructor,
      entity: {:resource, @resource},
      scope: [section_id: 301, resource_id: 4512],
      key: "resource:4512:notes_settings_changed",
      changes: %{
        "status" => %{"operation" => "set", "before" => "disabled", "after" => "enabled"}
      }
    ]

  defp spec(:student_support_settings_changed),
    do: [
      actor: :instructor,
      entity: {:section, @section},
      scope: [section_id: 301],
      key: "section:301:student_support_settings_changed",
      changes: %{
        "contains_discussions" => %{"operation" => "set", "before" => false, "after" => true}
      }
    ]

  # Payments

  defp spec(:payment_settings_changed),
    do: [
      actor: :admin,
      entity: {:product, @product},
      scope: [section_id: 290],
      key: "product:290:payment_settings_changed",
      changes: %{
        "grace_period_days" => %{
          "operation" => "set",
          "before" => 7,
          "after" => 14,
          "unit" => "days"
        }
      }
    ]

  defp spec(:pricing_changed),
    do: [
      actor: :admin,
      entity: {:product, @product},
      scope: [section_id: 290],
      key: "product:290:pricing_changed",
      changes: %{
        "amount" => %{
          "operation" => "set",
          "before" => "25.00",
          "after" => "30.00",
          "currency" => "USD"
        }
      }
    ]

  defp spec(:discount_changed),
    do: [
      actor: :admin,
      entity: {:discount, %{id: 61}},
      scope: [section_id: 290, institution_id: 9],
      key: "discount:61:changed",
      changes: %{"percentage" => %{"operation" => "set", "before" => 10.0, "after" => 20.0}}
    ]

  defp spec(:payment_code_administered),
    do: [
      actor: :admin,
      entity: {:payment_code_batch, @operation_id, %{}},
      scope: [section_id: 290],
      key: "product:290:payment_codes:generated",
      details: %{"code_count" => 50}
    ]

  defp spec(:entitlement_changed),
    do: [
      actor: :admin,
      entity: {:enrollment, "8812", %{}},
      scope: [section_id: 301],
      affected: {:user, 77},
      key: "enrollment:8812:entitlement_changed",
      changes: %{"type" => %{"operation" => "set", "before" => nil, "after" => "bypass"}}
    ]

  # Certificates

  defp spec(:certificate_settings_changed),
    do: [
      actor: :instructor,
      entity: {:certificate, %{id: 41, title: "Biology Certificate"}},
      scope: [section_id: 301],
      key: "certificate:41:settings_changed",
      changes: %{
        "min_percentage_for_completion" => %{"operation" => "set", "before" => 70, "after" => 75}
      }
    ]

  defp spec(:certificate_granted),
    do: [
      actor: :instructor,
      entity: {:granted_certificate, %{id: 3301}},
      scope: [section_id: 301],
      affected: {:user, 77},
      key: "granted_certificate:3301:granted",
      changes: %{"state" => %{"operation" => "set", "before" => "pending", "after" => "earned"}}
    ]

  defp spec(:certificate_revoked),
    do: [
      actor: :instructor,
      entity: {:granted_certificate, %{id: 3301}},
      scope: [section_id: 301],
      affected: {:user, 77},
      key: "granted_certificate:3301:revoked",
      changes: %{"state" => %{"operation" => "set", "before" => "earned", "after" => "denied"}}
    ]

  # Organizations

  defp spec(:institution_settings_changed),
    do: [
      actor: :admin,
      entity: {:institution, @institution},
      scope: [institution_id: 9],
      key: "institution:9:settings_changed",
      changes: %{
        "research_consent" => %{
          "operation" => "set",
          "before" => "oli_form",
          "after" => "no_form"
        }
      }
    ]

  defp spec(:community_settings_changed),
    do: [
      actor: :admin,
      entity: {:community, %{id: 14, name: "Biology Educators"}},
      key: "community:14:settings_changed",
      refs: [ref(:scope, :community, 14, "Biology Educators")],
      changes: %{"members" => %{"operation" => "added", "after" => [%{"author_id" => 12}]}}
    ]

  defp spec(:publisher_settings_changed),
    do: [
      actor: :admin,
      entity: {:publisher, %{id: 3, name: "Open Learning Press"}},
      key: "publisher:3:settings_changed",
      changes: %{
        "available_via_api" => %{"operation" => "set", "before" => false, "after" => true}
      }
    ]

  defp spec(:research_consent_settings_changed),
    do: [
      actor: :admin,
      entity: {:research_consent, "global", %{}},
      key: "research_consent:global:changed",
      changes: %{
        "research_consent" => %{
          "operation" => "set",
          "before" => "oli_form",
          "after" => "no_form"
        }
      }
    ]

  # Integrations

  defp spec(:lms_registration_declined),
    do: [
      actor: :admin,
      entity: {:pending_registration, %{id: 23, name: "Example State University"}},
      key: "pending_registration:23:declined",
      details: %{
        "institution_url" => "https://example.edu",
        "country_code" => "US",
        "issuer" => "https://lms.example.edu",
        "client_id" => "10000000000042",
        "deployment_id" => "1:abc"
      }
    ]

  defp spec(:lms_settings_changed),
    do: [
      actor: :admin,
      entity: {:registration, %{id: 17}},
      scope: [institution_id: 9],
      key: "registration:17:changed",
      changes: %{
        "auth_login_url" => %{
          "operation" => "set",
          "before" => "https://lms.example.edu/old",
          "after" => "https://lms.example.edu/login"
        }
      }
    ]

  defp spec(:sso_settings_changed),
    do: [
      actor: :admin,
      entity: {:institution, @institution},
      scope: [institution_id: 9],
      key: "institution:9:sso_settings_changed",
      refs: [ref(:provider, :identity_provider, "cognito", "Cognito")],
      changes: %{"private_key" => Changes.secret_record()}
    ]

  defp spec(:lti_settings_changed),
    do: [
      actor: :admin,
      entity: {:deployment, %{id: 23}},
      scope: [institution_id: 9],
      key: "deployment:23:changed",
      changes: %{
        "deployment_id" => %{"operation" => "set", "before" => "dep-1", "after" => "dep-2"}
      }
    ]

  defp spec(:external_tool_settings_changed),
    do: [
      actor: :admin,
      entity: {:external_tool, %{id: 8, name: "Lab Simulator"}},
      scope: [institution_id: 9],
      key: "external_tool:8:changed",
      changes: %{
        "status" => %{"operation" => "set", "before" => "enabled", "after" => "disabled"}
      }
    ]

  defp spec(:roster_settings_changed),
    do: [
      actor: :instructor,
      entity: {:section, @section},
      scope: [section_id: 301],
      key: "section:301:roster_settings_changed",
      changes: %{"nrps_enabled" => %{"operation" => "set", "before" => false, "after" => true}}
    ]

  defp spec(:grade_passback_settings_changed),
    do: [
      actor: :instructor,
      entity: {:section, @section},
      scope: [section_id: 301],
      key: "section:301:grade_passback_settings_changed",
      changes: %{
        "grade_passback_enabled" => %{"operation" => "set", "before" => true, "after" => false}
      }
    ]

  # AI and credentials

  defp spec(:ai_service_settings_changed),
    do: [
      actor: :admin,
      entity: {:ai_service, %{id: 4, name: "Default completion service"}},
      key: "ai_service:4:changed",
      changes: %{
        "backup_model_id" => %{"operation" => "set", "before" => nil, "after" => 7},
        "api_key" => Changes.secret_record()
      }
    ]

  defp spec(:credential_lifecycle_changed),
    do: [
      actor: :admin,
      entity: {:mcp_token, %{id: 52}},
      affected: {:author, 12},
      key: "mcp_token:52:revoked",
      changes: %{
        "lifecycle" => %{"operation" => "set", "before" => "enabled", "after" => "revoked"}
      },
      details: %{"hint" => "…a91f"}
    ]

  # Feature flags

  defp spec(:feature_flag_enabled),
    do: [
      actor: :admin,
      entity: {:feature_flag, "mcp_authoring", %{}},
      scope: [project_id: 88],
      key: "flag:mcp_authoring:feature_flag_enabled",
      details: %{
        "feature_name" => "mcp_authoring",
        "enabled" => true,
        "resource_type" => "project",
        "project_title" => "Intro Biology"
      }
    ]

  defp spec(:feature_flag_disabled),
    do: [
      actor: :admin,
      entity: {:feature_flag, "mcp_authoring", %{}},
      scope: [section_id: 301],
      key: "flag:mcp_authoring:feature_flag_disabled",
      details: %{
        "feature_name" => "mcp_authoring",
        "enabled" => false,
        "resource_type" => "section",
        "section_title" => "Biology 101 - Fall 2026"
      }
    ]

  defp spec(:feature_flag_removed),
    do: [
      actor: :admin,
      entity: {:feature_flag, "mcp_authoring", %{}},
      scope: [project_id: 88],
      key: "flag:mcp_authoring:feature_flag_removed",
      details: %{"feature_name" => "mcp_authoring", "resource_type" => "project"}
    ]

  defp spec(:feature_rollout_stage_changed),
    do: [
      actor: :admin,
      entity: {:feature_rollout, "adaptive_dot", %{}},
      key: "rollout:adaptive_dot:global:stage_changed",
      refs: [ref(:scope, :global, "global", "All institutions")],
      details: %{
        "feature_name" => "adaptive_dot",
        "scope_type" => "global",
        "stage" => "five_percent",
        "rollout_percentage" => 5,
        "previous" => %{"stage" => "internal_only", "effect" => nil}
      }
    ]

  defp spec(:feature_rollout_stage_deleted),
    do: [
      actor: :admin,
      entity: {:feature_rollout, "adaptive_dot", %{}},
      key: "rollout:adaptive_dot:global:stage_deleted",
      refs: [ref(:scope, :global, "global", "All institutions")],
      details: %{"feature_name" => "adaptive_dot", "scope_type" => "global", "stage" => "full"}
    ]

  defp spec(:feature_rollout_exemption_upserted),
    do: [
      actor: :admin,
      entity: {:rollout_exemption, "adaptive_dot:publisher:3", %{}},
      key: "rollout:adaptive_dot:publisher_3:exemption_upserted",
      refs: [ref(:scope, :publisher, 3, "Open Learning Press")],
      details: %{"feature_name" => "adaptive_dot", "publisher_id" => 3, "effect" => "deny"}
    ]

  defp spec(:feature_rollout_exemption_deleted),
    do: [
      actor: :admin,
      entity: {:rollout_exemption, "adaptive_dot:publisher:3", %{}},
      key: "rollout:adaptive_dot:publisher_3:exemption_deleted",
      refs: [ref(:scope, :publisher, 3, "Open Learning Press")],
      details: %{"feature_name" => "adaptive_dot", "publisher_id" => 3, "effect" => "deny"}
    ]

  # Administrative operations

  defp spec(:administrative_operation),
    do: [
      actor: {:system, :scheduled_maintenance},
      source: :job,
      entity: {:administrative_operation, @operation_id, %{label: "Partition maintenance"}},
      key: "admin_operation:partition_maintenance:finished",
      details: %{"kind" => "partition_maintenance", "result_summary" => "1 partition created"}
    ]

  defp spec(:clickhouse_admin_operation_initiated),
    do: [
      actor: :admin,
      entity: {:clickhouse_operation, "512", %{label: "Run ClickHouse migrations"}},
      key: "clickhouse:migrate_up:initiated",
      outcome: :initiated,
      details: %{
        "operation_id" => 512,
        "kind" => "migrate_up",
        "operation_label" => "Run ClickHouse migrations",
        "message" => "Run ClickHouse migrations requested."
      }
    ]

  defp spec(:clickhouse_admin_operation_outcome),
    do: [
      actor: :admin,
      source: :job,
      entity: {:clickhouse_operation, "512", %{label: "Run ClickHouse migrations"}},
      key: "clickhouse:migrate_up:outcome",
      outcome: :failed,
      details: %{
        "operation_id" => 512,
        "kind" => "migrate_up",
        "result_summary" => "Migration 0042 timed out",
        "job_ref" => 99_812
      }
    ]

  # Preferences

  defp spec(:preferences_changed),
    do: [
      actor: :author,
      entity: {:author, @author},
      affected: {:author, 12},
      key: "account:primary:preferences_changed",
      changes: %{
        "timezone" => %{"operation" => "set", "before" => "UTC", "after" => "America/New_York"}
      }
    ]

  # Assembly

  defp build(spec, name) do
    {actor_columns, actor_snapshot} = actor(Keyword.fetch!(spec, :actor))
    {entity_type, entity_id, entity_snapshot} = entity(Keyword.fetch!(spec, :entity))
    refs = Keyword.get(spec, :refs, [])
    scope = Keyword.get(spec, :scope, [])

    {affected_user_id, affected_author_id} =
      case Keyword.get(spec, :affected) do
        {:user, id} -> {id, nil}
        {:author, id} -> {nil, id}
        nil -> {nil, nil}
      end

    search_snapshots =
      [actor_snapshot, entity_snapshot] ++
        for(%{"label" => label} <- refs, is_binary(label), do: %{"label" => label})

    actor_columns
    |> Map.merge(%{
      schema_version: 2,
      event_type: name,
      occurred_at: @occurred_at,
      inserted_at: @occurred_at,
      outcome: Keyword.get(spec, :outcome, :succeeded),
      actor_snapshot: actor_snapshot,
      entity_type: entity_type,
      entity_id: entity_id,
      entity_snapshot: entity_snapshot,
      affected_user_id: affected_user_id,
      affected_author_id: affected_author_id,
      project_id: Keyword.get(scope, :project_id),
      section_id: Keyword.get(scope, :section_id),
      resource_id: Keyword.get(scope, :resource_id),
      institution_id: Keyword.get(scope, :institution_id),
      refs: refs,
      changes: Keyword.get(spec, :changes, %{}),
      details: Keyword.get(spec, :details, %{}),
      source: Keyword.get(spec, :source, :ui),
      operation_id: @operation_id,
      parent_operation_id: Keyword.get(spec, :parent_operation_id),
      event_key: Keyword.fetch!(spec, :key),
      legacy_source: nil,
      legacy_id: nil,
      search_text: Snapshot.search_text(search_snapshots)
    })
    |> as_history(Keyword.get(spec, :v1))
  end

  # A v1-only name is documented as migrated history: provenance set, envelope fields unknown.
  defp as_history(row, nil), do: row

  defp as_history(row, provenance) do
    Map.merge(row, %{
      schema_version: 1,
      occurred_at: nil,
      outcome: nil,
      actor_snapshot: %{},
      source: nil,
      operation_id: nil,
      event_key: nil,
      legacy_source: Keyword.fetch!(provenance, :legacy_source),
      legacy_id: Keyword.fetch!(provenance, :legacy_id),
      search_text: Snapshot.search_text([row.entity_snapshot])
    })
  end

  defp actor({:system, key}) do
    {%{actor_type: :system, actor_key: Atom.to_string(key), user_id: nil, author_id: nil},
     %{"key" => Atom.to_string(key), "label" => Context.system_label(key)}}
  end

  defp actor(kind) do
    {type, account} =
      case kind do
        :learner -> {:user, @learner}
        :instructor -> {:user, @instructor}
        :admin -> {:author, @admin}
        :author -> {:author, @author}
      end

    columns =
      case type do
        :user -> %{actor_type: :user, user_id: account.id, author_id: nil, actor_key: nil}
        :author -> %{actor_type: :author, author_id: account.id, user_id: nil, actor_key: nil}
      end

    {columns, Snapshot.of(account)}
  end

  defp entity({type, id, snapshot}), do: {type, to_string(id), Snapshot.of(snapshot)}
  defp entity({type, %{id: id} = snapshot}), do: {type, to_string(id), Snapshot.of(snapshot)}

  defp student_exception_entity,
    do: {:student_exception, EntityId.compose(section: 301, resource: 4512, user: 77), @resource}

  defp ref(role, type, id, label) do
    %{"role" => Atom.to_string(role), "type" => Atom.to_string(type), "id" => id}
    |> put_label(label)
  end

  defp put_label(ref, nil), do: ref
  defp put_label(ref, label), do: Map.put(ref, "label", label)
end
