defmodule Oli.Auditing.EventCatalogTest do
  use ExUnit.Case, async: true

  alias Oli.Auditing.{EventCatalog, Sensitive}
  alias Oli.Auditing.EventCatalog.{Contract, Fields}

  # Mirrors the family contract table of the approved PR-01 design, plus the events later
  # coverage designs add.
  @expected %{
    authentication:
      ~w(user_logged_in author_logged_in user_logged_out author_logged_out session_revoked)a,
    account: ~w(account_created account_updated account_locked account_unlocked account_linked
        account_identity_linked account_identity_unlinked account_permissions_changed account_creation_rights_changed account_recovery_requested
        account_credential_recovered user_deleted author_deleted author_role_changed
        account_internal_flag_changed)a,
    project: ~w(project_created project_duplicated project_imported project_deleted
        project_ownership_changed project_collaborator_changed project_published)a,
    assessment_settings:
      ~w(assessment_settings_changed assessment_settings_reset assessment_setting_changed)a,
    student_exceptions:
      ~w(student_exception_created student_exception_updated student_exception_deleted)a,
    dot_activation:
      ~w(dot_settings_changed activation_settings_changed instructor_ai_recommendation_changed)a,
    remix: ~w(section_remix_saved)a,
    destructive_content:
      ~w(authoring_content_removed authoring_content_replaced bank_question_deleted
        media_deleted google_doc_imported)a,
    discussion: ~w(discussion_post_deleted discussion_thread_deleted discussion_moderated)a,
    learner_intervention:
      ~w(resource_attempt_deleted learner_attempt_reset learner_progress_restored
        manual_grade_changed learner_regraded)a,
    project_settings: ~w(project_settings_changed)a,
    authoring_configuration:
      ~w(authoring_settings_changed learning_objectives_changed curriculum_changed)a,
    section_lifecycle:
      ~w(section_created section_deleted section_archived section_settings_changed
        product_created product_deleted product_archived product_settings_changed
        blueprint_created blueprint_deleted blueprint_archived blueprint_settings_changed)a,
    enrollment:
      ~w(invitation_created invitation_accepted enrollment_changed instructor_access_changed)a,
    publication_application: ~w(publication_applied publication_update_policy_changed)a,
    gating: ~w(gating_changed prerequisite_changed curriculum_schedule_changed)a,
    support_configuration:
      ~w(discussion_settings_changed notes_settings_changed student_support_settings_changed)a,
    payments:
      ~w(payment_settings_changed pricing_changed discount_changed payment_code_administered
        entitlement_changed)a,
    certificates: ~w(certificate_settings_changed certificate_granted certificate_revoked)a,
    organizations:
      ~w(institution_settings_changed community_settings_changed publisher_settings_changed
        research_consent_settings_changed)a,
    integrations: ~w(lms_settings_changed sso_settings_changed lti_settings_changed
        external_tool_settings_changed roster_settings_changed grade_passback_settings_changed)a,
    ai_credentials: ~w(ai_service_settings_changed credential_lifecycle_changed)a,
    feature_flags: ~w(feature_flag_enabled feature_flag_disabled feature_flag_removed
        feature_rollout_stage_changed feature_rollout_stage_deleted
        feature_rollout_exemption_upserted feature_rollout_exemption_deleted)a,
    administrative_operations: ~w(administrative_operation clickhouse_admin_operation_initiated
        clickhouse_admin_operation_outcome)a,
    preferences: ~w(preferences_changed)a
  }

  # Names the database checks treat as affected-learner events (section, resource, and
  # affected user required). Kept here so the catalog cannot drift from the DDL silently.
  @db_learner_events ~w(student_exception_created student_exception_updated
    student_exception_deleted resource_attempt_deleted
    learner_attempt_reset manual_grade_changed learner_regraded)a

  @existing_events ~w(user_deleted author_deleted author_role_changed project_published
    section_created feature_flag_enabled feature_flag_disabled feature_flag_removed
    google_doc_imported feature_rollout_stage_changed feature_rollout_stage_deleted
    feature_rollout_exemption_upserted feature_rollout_exemption_deleted
    account_internal_flag_changed clickhouse_admin_operation_initiated
    resource_attempt_deleted)a

  test "the registry matches the approved family table in both directions" do
    actual =
      Map.new(EventCatalog.families(), fn family ->
        {family, EventCatalog.family_events(family)}
      end)

    assert actual == @expected
    assert length(EventCatalog.names()) == 109
    assert length(EventCatalog.families()) == 25
  end

  test "includes every event type written today" do
    assert @existing_events -- EventCatalog.names() == []
  end

  test "released event names are never removed or renamed" do
    released =
      "test/support/audit/released_event_names.txt"
      |> File.read!()
      |> String.split("\n", trim: true)

    catalog = Enum.map(EventCatalog.names(), &Atom.to_string/1)

    assert released -- catalog == []
  end

  test "event names fit the database format check" do
    for name <- EventCatalog.names() do
      assert Regex.match?(~r/^[a-z][a-z0-9_]{2,79}$/, Atom.to_string(name))
    end
  end

  test "every contract is documented and complete" do
    for %Contract{} = contract <- EventCatalog.contracts() do
      assert is_binary(contract.label) and contract.label != "", "#{contract.name} label"

      assert is_binary(contract.description) and String.length(contract.description) > 20,
             "#{contract.name} description"

      assert String.ends_with?(contract.description, "."), "#{contract.name} description"

      assert contract.actor_kinds != [] and
               contract.actor_kinds -- [:user, :author, :system] == []

      assert contract.entity_types != [], "#{contract.name} entity types"
      assert contract.outcomes != [], "#{contract.name} outcomes"
      assert contract.no_op in [:skip, :lifecycle]
      assert is_binary(EventCatalog.family_label(contract.family))

      for entity_type <- contract.entity_types do
        assert Regex.match?(~r/^[a-z][a-z0-9_]{1,63}$/, Atom.to_string(entity_type))
      end
    end
  end

  test "skip contracts declare change fields" do
    for %Contract{no_op: :skip} = contract <- EventCatalog.contracts() do
      assert map_size(contract.change_fields) > 0, "#{contract.name} has no change fields"
    end
  end

  test "fields with secret-looking names are declared secret" do
    for %Contract{} = contract <- EventCatalog.contracts(),
        {field, kind} <- contract.change_fields,
        Sensitive.key?(field),
        field not in Fields.not_secret() do
      assert kind == :secret, "#{contract.name}.#{field} must be secret"
    end

    for %Contract{} = contract <- EventCatalog.contracts(), key <- contract.detail_keys do
      refute Sensitive.key?(key), "#{contract.name} detail key #{key} looks secret"
    end
  end

  test "only the initiation event may record an initiated outcome" do
    initiated =
      for %Contract{outcomes: o, name: n} <- EventCatalog.contracts(), :initiated in o, do: n

    assert initiated == [:clickhouse_admin_operation_initiated]
  end

  test "affected-learner contracts agree with the database check" do
    for name <- @db_learner_events do
      contract = EventCatalog.contract!(name)
      assert contract.required -- [:section_id, :resource_id] == []
      assert :section_id in contract.required and :resource_id in contract.required
      assert contract.affected_required and contract.affected_kinds == [:user]
    end

    progress = EventCatalog.contract!(:learner_progress_restored)
    assert progress.required == [:section_id]
    assert progress.affected_required and progress.affected_kinds == [:user]
  end

  test "assessment_setting_changed is reserved for migrated history" do
    assert EventCatalog.contract!(:assessment_setting_changed).v1_only

    assert [:assessment_setting_changed] ==
             for(%Contract{v1_only: true, name: name} <- EventCatalog.contracts(), do: name)
  end

  test "labels fall back to a humanized name for unknown values" do
    assert EventCatalog.label(:student_exception_updated) == "Student exception updated"
    assert EventCatalog.label("section_created") == "Section created"
    assert EventCatalog.label("retired_event_name") == "Retired event name"
  end
end
