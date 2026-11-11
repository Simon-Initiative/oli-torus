defmodule Oli.Auditing.EventCatalog.Definitions do
  @moduledoc """
  Source data for `Oli.Auditing.EventCatalog`: every event family, its shared contract
  defaults, and its events.

  Rules for changing this file:

    * An event name is never removed or renamed once released; mark it `deprecated: true`.
    * `change_fields` and `detail_keys` are only ever extended; a new meaning needs a new key.
    * Every event needs an example in `Oli.Auditing.EventExamples` (test support), and
      `docs/design-docs/audit-log-events.md` must be regenerated in the same change.
  """

  alias Oli.Auditing.EventCatalog.Fields

  @admin [:user, :author]
  @lifecycle_outcomes [:succeeded]
  @job_outcomes [:succeeded, :partial, :failed]

  @doc "Returns `[{family, label, defaults, [{name, label, description, overrides}]}]`."
  @spec families() :: [{atom(), String.t(), keyword(), [tuple()]}]
  def families do
    [
      {:authentication, "Authentication",
       [
         entity_types: [:user, :author],
         affected_kinds: [:user, :author],
         affected_required: true,
         subject_is_affected: true,
         detail_keys: ~w(auth_method session_ref revoked_count)
       ],
       [
         {:user_logged_in, "User logged in",
          "A learner or instructor account started an authenticated session.",
          actor_kinds: [:user]},
         {:author_logged_in, "Author logged in",
          "An authoring account started an authenticated session.", actor_kinds: [:author]},
         {:user_logged_out, "User logged out",
          "A learner or instructor account ended its own session.", actor_kinds: [:user]},
         {:author_logged_out, "Author logged out", "An authoring account ended its own session.",
          actor_kinds: [:author]},
         {:session_revoked, "Session revoked",
          "Server-side session tokens of an account were invalidated; it does not imply the " <>
            "account was logged out of an external identity provider.",
          actor_kinds: [:user, :author, :system]}
       ]},
      {:account, "Account",
       [
         entity_types: [:user, :author],
         affected_kinds: [:user, :author],
         affected_required: true,
         subject_is_affected: true,
         change_fields: Fields.account()
       ],
       [
         {:account_created, "Account created",
          "A user or author account was created by registration, invitation, an admin, or " <>
            "identity-provider provisioning.",
          actor_kinds: [:user, :author, :system], detail_keys: ~w(creation_source)},
         {:account_updated, "Account updated",
          "Profile or access fields of an account were changed.",
          actor_kinds: [:user, :author, :system], no_op: :skip},
         {:account_locked, "Account locked",
          "An account was locked and can no longer sign in until unlocked.",
          change_fields: %{locked_at: :value}},
         {:account_unlocked, "Account unlocked", "A locked account was unlocked.",
          change_fields: %{locked_at: :value}},
         {:account_linked, "Account linked",
          "A user account was linked to an author account (or the link was removed).",
          actor_kinds: [:user, :author, :system],
          ref_roles: [:linked],
          change_fields: %{author_id: :value}},
         {:account_identity_linked, "Login provider connected",
          "A login provider (for example Google) was connected to an account, so it can sign " <>
            "in through that provider; the provider account identifier is not recorded.",
          detail_keys: ~w(provider), change_fields: %{}},
         {:account_identity_unlinked, "Login provider disconnected",
          "A login provider was disconnected from an account.",
          detail_keys: ~w(provider), change_fields: %{}},
         {:account_permissions_changed, "Account permissions changed",
          "Access flags or institution roles of an account, such as independent learner or " <>
            "hidden, were changed.", actor_kinds: [:user, :author, :system], no_op: :skip},
         {:account_creation_rights_changed, "Section creation rights changed",
          "The right of a user to create course sections was granted or removed.",
          actor_kinds: [:user, :author, :system],
          no_op: :skip,
          change_fields: %{can_create_sections: :value}},
         {:account_recovery_requested, "Account recovery requested",
          "A password reset or confirmation email was requested; it does not imply the " <>
            "account was recovered.",
          actor_kinds: [:user, :author, :system],
          detail_keys: ~w(recovery_kind),
          change_fields: %{}},
         {:account_credential_recovered, "Account credential recovered",
          "An account's password was reset through a recovery link.",
          change_fields: %{password: :secret}},
         {:user_deleted, "User deleted",
          "A user account was permanently deleted; the snapshot keeps its identity.",
          detail_keys: ~w(email name deleted_by), change_fields: %{}},
         {:author_deleted, "Author deleted",
          "An author account was permanently deleted; the snapshot keeps its identity.",
          detail_keys: ~w(email name deleted_by), change_fields: %{}},
         {:author_role_changed, "Author role changed",
          "The system role of an author account (for example, admin) was changed.",
          entity_types: [:author],
          affected_kinds: [:author],
          no_op: :skip,
          change_fields: %{system_role_id: :value},
          detail_keys:
            ~w(actor_name actor_email author_id author_name author_email previous_role_id new_role_id previous_role new_role)},
         {:account_internal_flag_changed, "Internal account flag changed",
          "An account was marked or unmarked as internal staff.",
          no_op: :skip,
          change_fields: %{is_internal: :value},
          detail_keys: ~w(account_type user_id author_id previous is_internal)}
       ]},
      {:project, "Project",
       [
         entity_types: [:project],
         required: [:project_id],
         detail_keys: ~w(project_title publication_id version description source_project_id)
       ],
       [
         {:project_created, "Project created", "A new authoring project was created.", []},
         {:project_duplicated, "Project duplicated",
          "A project was created as a copy of another project.", ref_roles: [:source]},
         {:project_imported, "Project imported",
          "A project was created from an imported course archive.", outcomes: @job_outcomes},
         {:project_deleted, "Project deleted",
          "A project was marked deleted and hidden from authors.", []},
         {:project_ownership_changed, "Project ownership changed",
          "Ownership of a project was transferred to another author.",
          affected_kinds: [:author], affected_required: true},
         {:project_collaborator_changed, "Project collaborator changed",
          "An author was added, removed, or changed as a project collaborator.",
          affected_kinds: [:author],
          affected_required: true,
          change_fields: %{role: :value, status: :value}},
         {:project_published, "Project published",
          "A new publication of a project was created; applying it to sections is separate.",
          ref_roles: [:previous, :resulting]}
       ]},
      {:assessment_settings, "Assessment settings",
       [
         entity_types: [:resource],
         required: [:section_id, :resource_id],
         no_op: :skip,
         change_fields: Fields.assessment_settings()
       ],
       [
         {:assessment_settings_changed, "Assessment settings changed",
          "Section-level settings of one assessment were changed.", []},
         {:assessment_settings_reset, "Assessment settings reset",
          "Section-level settings of one assessment were reset to the values inherited from " <>
            "the publication.", []},
         {:assessment_setting_changed, "Assessment setting changed (history)",
          "Migrated history of one assessment setting change; never written by the application.",
          v1_only: true}
       ]},
      {:student_exceptions, "Student exceptions",
       [
         entity_types: [:student_exception],
         required: [:section_id, :resource_id],
         affected_kinds: [:user],
         affected_required: true,
         no_op: :skip,
         change_fields: Fields.student_exception()
       ],
       [
         {:student_exception_created, "Student exception created",
          "An instructor or admin created a per-student override for one assessment.",
          no_op: :lifecycle},
         {:student_exception_updated, "Student exception updated",
          "An instructor or admin changed an existing per-student override (dates, attempts, " <>
            "time limit, password) for one assessment.", []},
         {:student_exception_deleted, "Student exception deleted",
          "A per-student override was removed; the student falls back to section settings.",
          no_op: :lifecycle}
       ]},
      {:dot_activation, "DOT and activation points",
       [
         entity_types: [:project, :section, :resource],
         required_one_of: [:project_id, :section_id],
         no_op: :skip,
         change_fields: Fields.dot_activation()
       ],
       [
         {:dot_settings_changed, "DOT settings changed",
          "The DOT AI assistant was enabled, disabled, or reconfigured.", []},
         {:activation_settings_changed, "Activation points changed",
          "Activation point (trigger) settings were enabled, disabled, or changed.", []},
         {:instructor_ai_recommendation_changed, "Instructor AI recommendations changed",
          "Instructor dashboard AI recommendation settings or prompts were changed.", []}
       ]},
      {:remix, "Remix",
       [
         entity_types: [:curriculum_entry],
         required: [:section_id, :resource_id],
         no_op: :skip,
         change_fields: Fields.remix(),
         ref_roles: [:source]
       ],
       [
         {:section_remix_saved, "Remix saved",
          "A saved remix added, removed, moved, or hid one curriculum entry of a section.", []}
       ]},
      {:destructive_content, "Destructive content",
       [
         entity_types: [:resource, :revision, :media_item],
         required: [:project_id],
         outcomes: @job_outcomes,
         change_fields: Fields.authoring_content(),
         ref_roles: [:previous, :resulting]
       ],
       [
         {:authoring_content_removed, "Content removed",
          "A page, activity, or container was deleted from a project.", []},
         {:authoring_content_replaced, "Content replaced",
          "The content of a resource was replaced wholesale, for example by a repair or import.",
          []},
         {:bank_question_deleted, "Bank question deleted",
          "A question was deleted from a project's activity bank.", []},
         {:media_deleted, "Media deleted", "A media library item was deleted from a project.",
          detail_keys: ~w(file_name mime_type)},
         {:google_doc_imported, "Google Doc imported",
          "A Google Doc was imported into a page, replacing its content.",
          entity_types: [:project],
          detail_keys:
            ~w(file_id_hash page_revision_id page_resource_id page_title warning_codes warning_count duration_ms duration_bucket download_bytes uploaded_media_count reused_media_count failed_media_count skipped_media_count media_bytes_uploaded)}
       ]},
      {:discussion, "Discussion",
       [
         entity_types: [:post, :thread],
         required: [:section_id],
         affected_kinds: [:user],
         change_fields: Fields.discussion(),
         detail_keys: ~w(cascade_count)
       ],
       [
         {:discussion_post_deleted, "Discussion post deleted",
          "A discussion post was deleted; the message body is never recorded.", []},
         {:discussion_thread_deleted, "Discussion thread deleted",
          "A discussion thread and its replies were deleted.", []},
         {:discussion_moderated, "Discussion moderated",
          "A post was approved, hidden, or otherwise moderated.", no_op: :skip}
       ]},
      {:learner_intervention, "Learner intervention",
       [
         entity_types: [:resource_attempt, :resource_access, :enrollment],
         required: [:section_id, :resource_id],
         affected_kinds: [:user],
         affected_required: true,
         outcomes: @job_outcomes,
         change_fields: Fields.learner_record(),
         detail_keys:
           ~w(attempt_guid attempt_number resource_access_id reason grade_sync_triggered)
       ],
       [
         {:resource_attempt_deleted, "Attempt deleted",
          "An instructor or admin deleted one of a student's assessment attempts.",
          detail_keys:
            ~w(attempt_guid attempt_number resource_access_id resource_id user_id section_id grade_sync_triggered)},
         {:learner_attempt_reset, "Attempt reset",
          "A student's attempts at one resource were reset so they can start again.", []},
         {:learner_progress_restored, "Progress restored",
          "A student's progress in a section was restored from earlier records.",
          required: [:section_id]},
         {:manual_grade_changed, "Manual grade changed",
          "An instructor set or changed a manually scored grade.", no_op: :skip},
         {:learner_regraded, "Learner regraded",
          "A student's attempt was re-evaluated and its score may have changed.", []}
       ]},
      {:project_settings, "Project settings",
       [
         entity_types: [:project],
         required: [:project_id],
         no_op: :skip,
         change_fields: Fields.project_settings()
       ],
       [
         {:project_settings_changed, "Project settings changed",
          "Persisted settings of a project, such as visibility or duplication, were changed.", []}
       ]},
      {:authoring_configuration, "Authoring configuration",
       [
         entity_types: [:resource, :objective, :container],
         required: [:project_id],
         no_op: :skip,
         change_fields: Fields.authoring_configuration()
       ],
       [
         {:authoring_settings_changed, "Authoring settings changed",
          "Authoring defaults of a page or assessment were changed.", []},
         {:learning_objectives_changed, "Learning objectives changed",
          "Learning objectives or their relationships were created, changed, or removed.", []},
         {:curriculum_changed, "Curriculum changed",
          "The authored curriculum structure of a project was reordered or restructured.", []}
       ]},
      {:section_lifecycle, "Section lifecycle and settings",
       [
         required: [:section_id],
         change_fields: Fields.section_settings(),
         detail_keys:
           ~w(section_title type base_project_id creation_source copied_groups blueprint_id)
       ], section_lifecycle_events()},
      {:enrollment, "Enrollment and access",
       [
         entity_types: [:invitation, :enrollment],
         required_one_of: [:section_id, :project_id],
         affected_kinds: [:user, :author],
         affected_required: true,
         change_fields: Fields.enrollment()
       ],
       [
         {:invitation_created, "Invitation created",
          "A person was invited to a section or project; the invitation token is never recorded.",
          []},
         {:invitation_accepted, "Invitation accepted", "A pending invitation was accepted.",
          actor_kinds: [:user, :author]},
         {:enrollment_changed, "Enrollment changed",
          "A learner's enrollment status or roles in a section were changed.", no_op: :skip},
         {:instructor_access_changed, "Instructor access changed",
          "Instructor access to a section was granted, changed, or removed.", no_op: :skip}
       ]},
      {:publication_application, "Publication application",
       [
         entity_types: [:section],
         required: [:section_id, :project_id],
         change_fields: Fields.publication(),
         ref_roles: [:previous, :resulting]
       ],
       [
         {:publication_applied, "Publication applied",
          "A project publication was applied to a section, updating its content.",
          outcomes: @job_outcomes, actor_kinds: [:user, :author, :system]},
         {:publication_update_policy_changed, "Publication update policy changed",
          "How a section receives publication updates was changed.", no_op: :skip}
       ]},
      {:gating, "Gating and scheduling",
       [
         entity_types: [:gating_condition, :section_resource],
         required: [:section_id],
         affected_kinds: [:user],
         no_op: :skip,
         change_fields: Fields.gating()
       ],
       [
         {:gating_changed, "Gating changed",
          "A gating condition was created, changed, or removed, for all students or one.", []},
         {:prerequisite_changed, "Prerequisite changed",
          "A prerequisite between resources was created, changed, or removed.", []},
         {:curriculum_schedule_changed, "Schedule changed",
          "Scheduled dates of curriculum items were changed.", []}
       ]},
      {:support_configuration, "Support configuration",
       [
         entity_types: [:section, :project, :resource],
         required_one_of: [:section_id, :project_id],
         no_op: :skip,
         change_fields: Fields.support_configuration()
       ],
       [
         {:discussion_settings_changed, "Discussion settings changed",
          "Discussion configuration of a page or section was changed.", []},
         {:notes_settings_changed, "Notes settings changed",
          "Class notes configuration was changed.", []},
         {:student_support_settings_changed, "Student support settings changed",
          "Student support options of a section were changed.", []}
       ]},
      {:payments, "Payments",
       [
         entity_types: [
           :product,
           :section,
           :institution,
           :discount,
           :payment_code_batch,
           :enrollment
         ],
         required_one_of: [:section_id, :institution_id],
         detail_keys: ~w(code_count)
       ],
       [
         {:payment_settings_changed, "Payment settings changed",
          "Payment requirements or grace periods of a product or section were changed.",
          no_op: :skip, change_fields: Fields.payment_settings()},
         {:pricing_changed, "Price changed", "The price of a product or section was changed.",
          no_op: :skip, change_fields: Fields.pricing()},
         {:discount_changed, "Discount changed",
          "An institution or section discount was created, changed, or removed.",
          change_fields: Fields.discount()},
         {:payment_code_administered, "Payment codes administered",
          "A batch of payment codes was generated or invalidated; codes are never recorded.", []},
         {:entitlement_changed, "Entitlement changed",
          "A learner's paid access was granted, bypassed, or invalidated by an admin.",
          affected_kinds: [:user], affected_required: true, change_fields: Fields.entitlement()}
       ]},
      {:certificates, "Certificates",
       [
         entity_types: [:certificate, :granted_certificate],
         required: [:section_id],
         affected_kinds: [:user]
       ],
       [
         {:certificate_settings_changed, "Certificate settings changed",
          "Certificate requirements or design of a section were changed.",
          no_op: :skip, change_fields: Fields.certificate_settings()},
         {:certificate_granted, "Certificate granted",
          "An instructor approved or granted a student's certificate.",
          affected_required: true, change_fields: Fields.certificate_decision()},
         {:certificate_revoked, "Certificate revoked",
          "An instructor denied or revoked a student's certificate.",
          affected_required: true, change_fields: Fields.certificate_decision()}
       ]},
      {:organizations, "Organizations",
       [
         entity_types: [:institution, :community, :publisher],
         no_op: :skip,
         change_fields: Fields.organization()
       ],
       [
         {:institution_settings_changed, "Institution settings changed",
          "Settings of an institution were created or changed.", required: [:institution_id]},
         {:community_settings_changed, "Community settings changed",
          "Settings or membership of a community were changed.", ref_roles: [:scope]},
         {:publisher_settings_changed, "Publisher settings changed",
          "Settings of a publisher were created or changed.", ref_roles: [:scope]},
         {:research_consent_settings_changed, "Research consent settings changed",
          "The research consent form configuration was changed.",
          entity_types: [:research_consent]}
       ]},
      {:integrations, "Integrations",
       [
         entity_types: [:registration, :deployment, :external_tool, :institution, :section],
         required_one_of: [:institution_id, :section_id],
         no_op: :skip,
         change_fields: Fields.integration(),
         ref_roles: [:provider]
       ],
       [
         {:lms_settings_changed, "LMS settings changed",
          "LMS registration or deployment settings were changed.", []},
         {:sso_settings_changed, "SSO settings changed",
          "Single sign-on configuration was changed; keys are never recorded.", []},
         {:lti_settings_changed, "LTI settings changed", "LTI 1.3 tool settings were changed.",
          []},
         {:external_tool_settings_changed, "External tool settings changed",
          "An external LTI tool was registered, enabled, disabled, or reconfigured.", []},
         {:roster_settings_changed, "Roster settings changed",
          "Roster synchronization (NRPS) settings of a section were changed.", []},
         {:grade_passback_settings_changed, "Grade passback settings changed",
          "Grade passback settings of a section were changed.", []}
       ]},
      {:ai_credentials, "AI and credentials",
       [
         affected_kinds: [:author],
         detail_keys: ~w(hint)
       ],
       [
         {:ai_service_settings_changed, "AI service settings changed",
          "A registered AI model or service configuration was created, changed, or removed; " <>
            "API keys are never recorded.",
          entity_types: [:ai_service], no_op: :skip, change_fields: Fields.ai_service()},
         {:credential_lifecycle_changed, "Credential lifecycle changed",
          "An API key or MCP token was created, rotated, enabled, disabled, or revoked; its " <>
            "value and hash are never recorded.",
          entity_types: [:api_key, :mcp_token], change_fields: Fields.credential()}
       ]},
      {:feature_flags, "Feature flags",
       [
         entity_types: [:feature_flag, :feature_rollout, :rollout_exemption],
         ref_roles: [:scope],
         detail_keys:
           ~w(feature_name enabled resource_type project_title section_title scope_type scope_id stage rollout_percentage previous effect publisher_id note)
       ],
       [
         {:feature_flag_enabled, "Feature flag enabled",
          "A scoped feature flag was enabled for a project or section.", []},
         {:feature_flag_disabled, "Feature flag disabled",
          "A scoped feature flag was disabled for a project or section.", []},
         {:feature_flag_removed, "Feature flag removed",
          "A scoped feature flag setting was removed from a project or section.", []},
         {:feature_rollout_stage_changed, "Rollout stage changed",
          "The rollout stage of a feature was changed for a scope.", []},
         {:feature_rollout_stage_deleted, "Rollout stage deleted",
          "The rollout of a feature was removed for a scope.", []},
         {:feature_rollout_exemption_upserted, "Rollout exemption set",
          "A publisher exemption from a feature rollout was created or changed.", []},
         {:feature_rollout_exemption_deleted, "Rollout exemption deleted",
          "A publisher exemption from a feature rollout was removed.", []}
       ]},
      {:administrative_operations, "Administrative operations",
       [
         entity_types: [:administrative_operation, :clickhouse_operation],
         actor_kinds: [:user, :author, :system],
         detail_keys:
           ~w(operation_id kind operation_label message actor_name result_summary job_ref)
       ],
       [
         {:administrative_operation, "Administrative operation",
          "A maintenance operation run by an admin or the system finished with the recorded " <>
            "outcome.", outcomes: [:succeeded, :failed, :canceled, :partial, :unknown]},
         {:clickhouse_admin_operation_initiated, "ClickHouse operation initiated",
          "An admin requested a ClickHouse setup or migration; initiation does not imply it " <>
            "completed.", actor_kinds: [:author], outcomes: [:initiated]},
         {:clickhouse_admin_operation_outcome, "ClickHouse operation finished",
          "A requested ClickHouse operation reached a terminal outcome.",
          outcomes: [:succeeded, :failed, :canceled, :partial, :unknown]}
       ]},
      {:preferences, "Preferences",
       [
         entity_types: [:user, :author],
         affected_kinds: [:user, :author],
         affected_required: true,
         subject_is_affected: true,
         no_op: :skip,
         change_fields: Fields.preferences()
       ],
       [
         {:preferences_changed, "Preferences changed",
          "Persisted preferences of an account, such as timezone or editor, were changed.", []}
       ]}
    ]
  end

  @doc "Defaults applied to every family before its own defaults."
  @spec base_defaults() :: keyword()
  def base_defaults do
    [actor_kinds: @admin, outcomes: @lifecycle_outcomes, no_op: :lifecycle]
  end

  defp section_lifecycle_events do
    for {kind, noun} <- [section: "Section", product: "Product", blueprint: "Blueprint"],
        {verb, label_verb, description, overrides} <- section_lifecycle_verbs(noun) do
      {:"#{kind}_#{verb}", "#{noun} #{label_verb}", description,
       Keyword.put(overrides, :entity_types, [kind])}
    end
  end

  defp section_lifecycle_verbs(noun) do
    lower = String.downcase(noun)

    [
      {:created, "created", "A #{lower} was created.",
       [actor_kinds: [:user, :author, :system], change_fields: %{}]},
      {:deleted, "deleted", "A #{lower} was deleted.", [change_fields: %{}]},
      {:archived, "archived", "A #{lower} was archived and closed to new activity.",
       [change_fields: %{status: :value}]},
      {:settings_changed, "settings changed", "Settings of a #{lower} were changed.",
       [no_op: :skip]}
    ]
  end
end
