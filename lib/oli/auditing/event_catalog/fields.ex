defmodule Oli.Auditing.EventCatalog.Fields do
  @moduledoc """
  Field policies for the `changes` map of each event family.

  Each policy lists the persisted fields, cast by the owning domain changesets, that an event
  may record. `:secret` fields are recorded only as a redaction marker. Fields that are derived
  by the system (indexes, timestamps of background syncs), large blobs, and personal data that
  is not needed to explain an administrative change are deliberately left out.

  ## Explicit yes and explicit no

  Policies are allowlists: `Oli.Auditing.Changes.diff/3` records only the listed fields, so an
  unlisted column is never audited and no new secret or personal field reaches the log by
  default. To keep an allowlist from silently missing a new column, every domain schema that
  feeds a policy is declared in `schema_sources/0` with:

    * `policies` - the policies that audit its fields. A field listed in any of them is audited,
      as `:value` or `:secret` (only a redaction marker is stored);
    * `excluded` - every other field, with the reason it is not audited;
    * `pseudo_keys` - keys of those policies that are not columns of the schema, with what they
      stand for (for example `late_policy`, or subfields of an embedded schema).

  One schema can feed several policies (`Section` feeds section, payment, pricing, DOT,
  integration, certificate, publication, and support configuration settings) and one policy can draw from several schemas
  (`dot_activation` uses `Section`, `SectionResource`, `Revision`, `Project`, and
  `FeatureConfig`), so each column is classified once, in its schema's declaration.

  `test/oli/auditing/field_policy_drift_test.exs` compares the declarations with the schemas.
  Adding a column fails CI until it is classified here; a `redact: true` column cannot be
  audited as `:value`; a policy field must exist in one of its schemas or be a pseudo key; and
  removed columns must be removed here too.

  The check matches field names, not their origin: when two schemas of the same policy share a
  name (for example `status`), a column of either counts as audited by that policy.
  """

  @typedoc "Field name to `:value` or `:secret`."
  @type policy :: %{optional(atom()) => :value | :secret}

  @typedoc "A domain schema, the policies it feeds, and the fields no policy audits."
  @type schema_source :: %{
          schema: module(),
          policies: [atom()],
          excluded: %{optional(atom()) => String.t()},
          pseudo_keys: %{optional(atom()) => String.t()}
        }

  @doc """
  Field names that match the secret-name pattern but hold no secret value. The catalog test
  requires every other matching field to be declared `:secret`.
  """
  @spec not_secret() :: [atom()]
  def not_secret, do: [:auth_token_url, :tool_jwk_id]

  @doc "User account fields (`Oli.Accounts.User` changesets)."
  @spec user_account() :: policy()
  def user_account do
    values(~w(email email_confirmed_at invitation_accepted_at name given_name family_name
      middle_name nickname preferred_username picture locale guest independent_learner
      research_opt_out locked_at can_create_sections age_verified hidden is_internal
      author_id lti_institution_id platform_roles)a)
    |> Map.merge(secrets(~w(password email_confirmation)a))
  end

  @doc "Author account fields (`Oli.Accounts.Author` changesets)."
  @spec author_account() :: policy()
  def author_account do
    values(~w(email email_confirmed_at invitation_accepted_at name given_name family_name
      locked_at system_role_id is_internal)a)
    |> Map.merge(secrets([:password]))
  end

  @doc "Fields of either account kind."
  @spec account() :: policy()
  def account, do: Map.merge(user_account(), author_account())

  @doc """
  Assessment settings shared by section resources and student exceptions
  (`Oli.Delivery.Sections.SectionResource`, `Oli.Delivery.Settings.StudentException`).
  `late_policy` is the bulk-update pseudo key of `Oli.Delivery.Settings.AssessmentSettings`.
  """
  @spec assessment_settings() :: policy()
  def assessment_settings do
    values(~w(start_date end_date max_attempts retake_mode assessment_mode late_submit
      late_start late_policy time_limit grace_period scoring_strategy_id review_submission
      feedback_mode feedback_scheduled_date batch_scoring replacement_strategy allow_hints
      secure_delivery explanation_strategy)a)
    |> Map.merge(secrets([:password]))
  end

  @doc "Per-student overrides (`Oli.Delivery.Settings.StudentException`)."
  @spec student_exception() :: policy()
  def student_exception do
    values(~w(start_date end_date max_attempts retake_mode assessment_mode late_submit
      late_start late_policy time_limit grace_period scoring_strategy_id review_submission
      feedback_mode feedback_scheduled_date batch_scoring replacement_strategy
      explanation_strategy)a)
    |> Map.merge(secrets([:password]))
  end

  @doc "DOT, activation points, and instructor AI recommendation settings."
  @spec dot_activation() :: policy()
  def dot_activation do
    values(~w(assistant_enabled triggers_enabled instructor_recommendations_enabled
      instructor_recommendation_prompt_template page_prompt_template ai_enabled allow_triggers
      service_config_id)a)
  end

  @doc "Curriculum entry fields rewritten by a saved remix."
  @spec remix() :: policy()
  def remix, do: values(~w(parent position hidden numbering_index source_publication_id)a)

  @doc "Revision-level fields changed by destructive authoring operations."
  @spec authoring_content() :: policy()
  def authoring_content, do: values(~w(deleted title revision_id)a)

  @doc "Discussion moderation state."
  @spec discussion() :: policy()
  def discussion, do: values(~w(status deleted)a)

  @doc "Learner-record fields (attempts, access, enrollment progress)."
  @spec learner_record() :: policy()
  def learner_record, do: values(~w(score out_of attempt_number lifecycle_state)a)

  @doc "Project settings (`Oli.Authoring.Course.Project` and its embedded attributes)."
  @spec project_settings() :: policy()
  def project_settings do
    values(~w(title description visibility status allow_duplication experiments_enabled
      alternatives_enabled allow_ecl_content_type allow_triggers analytics_version publisher_id
      required_survey_resource_id allow_transfer_payment_codes welcome_title encouraging_subtitle
      auto_update_sections learning_model_version customizations learning_language
      calculate_embeddings_on_publish coverage_formative_threshold coverage_summative_threshold
      license_type custom_license_details)a)
  end

  @doc "Authoring configuration: page settings, objectives, and curriculum structure."
  @spec authoring_configuration() :: policy()
  def authoring_configuration do
    values(~w(title graded purpose max_attempts recommended_attempts time_limit
      scoring_strategy_id retake_mode assessment_mode batch_scoring replacement_strategy
      explanation_strategy full_progress_pct duration_minutes learning_model_parameters
      objectives children parent_objective_id)a)
  end

  @doc "Section, product, and blueprint settings (`Oli.Delivery.Sections.Section`)."
  @spec section_settings() :: policy()
  def section_settings do
    values(~w(title description start_date end_date registration_open open_and_free
      requires_enrollment skip_email_verification status cover_image visibility
      display_curriculum_item_numbering contains_discussions contains_explorations
      contains_deliberate_practice required_survey_resource_id class_modality class_days
      course_section_number preferred_scheduling_time apply_major_updates welcome_title
      encouraging_subtitle agenda timezone brand_id publisher_id customizations)a)
    |> Map.merge(secrets(~w(invite_token passcode)a))
  end

  @doc "Enrollment and instructor access state."
  @spec enrollment() :: policy()
  def enrollment, do: values(~w(status context_roles date_expires)a)

  @doc "Publication application and update policy."
  @spec publication() :: policy()
  def publication, do: values(~w(publication_id apply_major_updates auto_update_sections)a)

  @doc "Gating conditions and scheduling (`GatingCondition`, `SectionResource` scheduling)."
  @spec gating() :: policy()
  def gating do
    values(~w(type graded_resource_policy parent_id start_datetime end_datetime
      source_resource_id minimum_percentage scheduling_type manually_scheduled start_date
      end_date removed_from_schedule)a)
  end

  @doc "Discussion, notes, and student support configuration (`CollabSpaceConfig`)."
  @spec support_configuration() :: policy()
  def support_configuration do
    values(~w(status threaded auto_accept show_full_history anonymous_posting
      participation_min_replies participation_min_posts contains_discussions)a)
  end

  @doc "Payment configuration of products and sections."
  @spec payment_settings() :: policy()
  def payment_settings do
    values(~w(requires_payment payment_options pay_by_institution has_grace_period
      grace_period_days grace_period_strategy)a)
  end

  @doc "Prices (`amount` records `currency`)."
  @spec pricing() :: policy()
  def pricing, do: values([:amount])

  @doc "Discounts (`Oli.Delivery.Paywall.Discount`)."
  @spec discount() :: policy()
  def discount, do: values(~w(type percentage amount bypass_paywall)a)

  @doc "Entitlement state of a learner's payment (`Oli.Delivery.Paywall.Payment`)."
  @spec entitlement() :: policy()
  def entitlement, do: values(~w(type application_date)a)

  @doc "Certificate settings (`Oli.Delivery.Sections.Certificate`); logos record a change only."
  @spec certificate_settings() :: policy()
  def certificate_settings do
    values(~w(certificate_enabled required_discussion_posts required_class_notes
      min_percentage_for_completion min_percentage_for_distinction assessments_apply_to
      custom_assessments requires_instructor_approval title description admin_name1
      admin_name2 admin_name3 admin_title1 admin_title2 admin_title3 logo1 logo2 logo3)a)
  end

  @doc "Granted certificate decision state."
  @spec certificate_decision() :: policy()
  def certificate_decision, do: values(~w(state with_distinction)a)

  @doc "Institution, community, publisher, and research consent settings."
  @spec organization() :: policy()
  def organization do
    values(~w(name description country_code institution_email institution_url
      default_brand_id research_consent status key_contact global_access email address
      main_contact website_url default available_via_api knowledge_base_link support_email
      members)a)
  end

  @doc "LMS, SSO, LTI, external tool, roster, and grade passback settings."
  @spec integration() :: policy()
  def integration do
    values(~w(issuer client_id key_set_url auth_token_url auth_login_url auth_server
      line_items_service_domain tool_jwk_id deployment_id institution_id status name
      description target_link_uri login_url keyset_url redirect_uris deep_linking_enabled
      grade_passback_enabled line_items_service_url nrps_enabled nrps_context_memberships_url
      url title text)a)
    |> Map.merge(secrets(~w(private_key custom_params custom)a))
  end

  @doc "AI service configuration (`RegisteredModel`, `ServiceConfig`, `FeatureConfig`)."
  @spec ai_service() :: policy()
  def ai_service do
    values(~w(name provider model url_template timeout recv_timeout pool_class
      max_concurrent routing_breaker_error_rate_threshold routing_breaker_429_threshold
      routing_breaker_latency_p95_ms routing_open_cooldown_ms routing_half_open_probe_count
      primary_model_id secondary_model_id backup_model_id feature service_config_id)a)
    |> Map.merge(secrets(~w(api_key secondary_api_key)a))
  end

  @doc "API key and MCP token lifecycle (no credential value or hash)."
  @spec credential() :: policy()
  def credential do
    values(~w(lifecycle status payments_enabled products_enabled registration_enabled
      registration_namespace automation_setup_enabled)a)
  end

  @doc "Persisted user and author preferences."
  @spec preferences() :: policy()
  def preferences do
    values(~w(timezone page_outline_panel_active? show_math_previews?
      assessment_settings_scoring_mode_warning_dismissed admin_show_all_projects
      admin_show_deleted_projects show_relative_dates editor)a)
  end

  @doc """
  Returns every domain schema that feeds a policy, the policies it feeds, and each field no
  policy audits, with the reason. See the moduledoc for how this keeps policies complete.
  """
  @spec schema_sources() :: [schema_source()]
  def schema_sources do
    [
      source(Oli.Accounts.User, [:user_account, :preferences],
        excluded:
          row(:user)
          |> Map.merge(
            excluded(
              ~w(profile website gender birthdate zoneinfo phone_number phone_number_verified address)a,
              "personal data from the identity provider, not needed to explain an administrative change"
            )
          )
          |> Map.merge(%{
            password_hash:
              "credential hash; a password change is recorded as the password marker",
            sub: "identity-provider subject; set by provisioning and never edited",
            email_verified:
              "identity-provider claim; confirmation is recorded through email_confirmed_at",
            state: "LTI launch state maintained by the system",
            invited_by_id: "set once with the invitation; recorded by invitation_created",
            preferences: "recorded through its subfields (see Oli.Accounts.UserPreferences)"
          }),
        pseudo_keys: %{
          platform_roles:
            "institution roles held through users_platform_roles, as sorted role URIs"
        }
      ),
      source(Oli.Accounts.Author, [:author_account, :preferences],
        excluded:
          row(:author)
          |> Map.merge(%{
            password_hash:
              "credential hash; a password change is recorded as the password marker",
            picture: "avatar URL from the identity provider",
            preferences: "recorded through its subfields (see Oli.Accounts.AuthorPreferences)"
          })
      ),
      source(Oli.Accounts.UserPreferences, [:preferences]),
      source(Oli.Accounts.AuthorPreferences, [:preferences]),
      source(
        Oli.Delivery.Sections.SectionResource,
        [:assessment_settings, :gating, :remix, :dot_activation],
        excluded:
          row(:section_resource)
          |> Map.merge(scope(~w(project_id section_id resource_id)a))
          |> Map.merge(
            excluded(
              ~w(title graded purpose duration_minutes intro_content intro_video poster_image
                objectives relates_to related_activities resource_type_id activity_type_id
                slug project_slug revision_slug)a,
              "copied from the published revision; changes arrive through publication_applied"
            )
          )
          |> Map.merge(%{
            revision_id:
              "published revision pointer; changes are recorded by publication_applied",
            children: "curriculum structure; remixes record parent and position instead",
            numbering_level: "derived by the system from the curriculum",
            contained_page_count: "derived by the system from the curriculum",
            delivery_policy_id: "internal delivery policy reference, not edited by users",
            collab_space_config:
              "recorded through its subfields by support_configuration (see CollabSpaceConfig)"
          }),
        pseudo_keys: %{
          late_policy:
            "bulk-update key of AssessmentSettings that sets late_submit and late_start",
          parent: "container that holds the entry, from the parent's children list",
          position: "index of the entry in its parent's children list",
          source_publication_id: "publication the entry comes from (SectionsProjectsPublications)"
        }
      ),
      source(Oli.Delivery.Settings.StudentException, [:student_exception],
        excluded:
          row(:student_exception)
          |> Map.merge(scope(~w(section_id resource_id)a))
          |> Map.merge(%{
            user_id: "the affected student; recorded in affected_user_id",
            collab_space_config:
              "discussion configuration; audited by discussion_settings_changed"
          }),
        pseudo_keys: %{
          late_policy:
            "bulk-update key of AssessmentSettings that sets late_submit and late_start"
        }
      ),
      source(
        Oli.Delivery.Sections.Section,
        [
          :section_settings,
          :payment_settings,
          :pricing,
          :dot_activation,
          :integration,
          :certificate_settings,
          :publication,
          :support_configuration
        ],
        excluded:
          row(:section)
          |> Map.merge(
            excluded(
              ~w(analytics_version learning_model_version section_resource_migration_version
                v25_migration)a,
              "data migration and version markers managed by the system"
            )
          )
          |> Map.merge(
            excluded(
              ~w(resource_gating_index previous_next_index unnumbered_unit_ids
                root_section_resource_id)a,
              "derived by the system from the curriculum"
            )
          )
          |> Map.merge(%{
            type: "section or blueprint, fixed at creation; recorded as the entity type",
            slug: "URL identity, not a setting",
            context_id: "LMS course context, set when the section is linked",
            lti_1p3_deployment_id: "LMS deployment link, set when the section is linked",
            base_project_id: "origin project, fixed at creation; recorded by section_created",
            blueprint_id: "origin product, fixed at creation; recorded by section_created",
            delivery_policy_id: "internal delivery policy reference, not edited by users"
          })
      ),
      source(
        Oli.Authoring.Course.Project,
        [:project_settings, :dot_activation, :publication],
        excluded:
          row(:project)
          |> Map.merge(
            excluded(
              ~w(latest_export_url latest_export_timestamp latest_analytics_snapshot_url
                latest_analytics_snapshot_timestamp latest_datashop_snapshot_url
                latest_datashop_snapshot_timestamp)a,
              "export and snapshot outputs written by background jobs"
            )
          )
          |> Map.merge(%{
            slug: "URL identity, not a setting",
            version: "publication version label; recorded by project_published",
            legacy_svn_root: "legacy import origin, never edited",
            lo_well_formed: "derived by the system from the learning objectives",
            project_id: "source project of a duplicate; recorded by project_duplicated",
            family_id: "project family link, fixed at creation",
            attributes: "recorded through its subfields (see ProjectAttributes)"
          })
      ),
      source(Oli.Authoring.Course.ProjectAttributes, [:project_settings],
        excluded: %{license: "recorded through license_type and custom_license_details"},
        pseudo_keys: %{
          license_type: "subfield of the license embed",
          custom_license_details: "subfield of the license embed"
        }
      ),
      source(
        Oli.Resources.Revision,
        [:authoring_configuration, :authoring_content, :dot_activation],
        excluded:
          row(:revision)
          |> Map.merge(
            excluded(
              ~w(content activity_refs relates_to parameters tags intro_content intro_video
                poster_image)a,
              "authored content; replacements are recorded by authoring_content_replaced without copying content"
            )
          )
          |> Map.merge(
            excluded(
              ~w(ids_added author_id previous_revision_id)a,
              "revision bookkeeping maintained by the system"
            )
          )
          |> Map.merge(
            excluded(
              ~w(resource_type_id activity_type_id primary_resource_id scope resource_scope)a,
              "kind and placement of the resource, fixed at creation"
            )
          )
          |> Map.merge(%{
            slug: "URL identity, not a setting",
            resource_id: "identity; recorded in resource_id",
            legacy: "legacy import data, never edited",
            collab_space_config:
              "recorded through its subfields by support_configuration (see CollabSpaceConfig)"
          }),
        pseudo_keys: %{
          revision_id: "revision replaced or created by a destructive operation",
          parent_objective_id: "objective that contains a sub-objective"
        }
      ),
      source(Oli.Delivery.Attempts.Core.ResourceAttempt, [:learner_record],
        excluded:
          row(:resource_attempt)
          |> Map.merge(
            excluded(
              ~w(state content errors)a,
              "learner response data, never copied to the audit log"
            )
          )
          |> Map.merge(%{
            attempt_guid: "attempt identity; recorded in entity_id",
            date_evaluated: "evaluation time set by the system",
            date_submitted: "submission time set by the system",
            was_late: "computed by the system at submission",
            auto_submit_job_id: "background job reference",
            resource_access_id: "parent access record; recorded in details",
            revision_id: "page version attempted, fixed at start"
          })
      ),
      source(Oli.Resources.Collaboration.Post, [:discussion],
        excluded:
          row(:post)
          |> Map.merge(scope(~w(section_id resource_id)a))
          |> Map.merge(
            excluded(
              ~w(parent_post_id thread_root_id annotated_resource_id annotated_block_id
                annotation_type visibility anonymous)a,
              "chosen when the post is written, not by moderation"
            )
          )
          |> Map.merge(%{
            content: "message body, never recorded",
            user_id: "the post author; recorded in affected_user_id"
          }),
        pseudo_keys: %{deleted: "the post or thread was removed"}
      ),
      source(Oli.Resources.Collaboration.CollabSpaceConfig, [:support_configuration]),
      source(Oli.Delivery.Gating.GatingCondition, [:gating],
        excluded:
          row(:gating_condition)
          |> Map.merge(scope([:section_id]))
          |> Map.merge(%{
            resource_id: "the gated resource; recorded in resource_id",
            user_id: "student of a per-student condition; recorded in affected_user_id",
            data: "recorded through its subfields (see GatingConditionData)"
          })
      ),
      source(Oli.Delivery.Gating.GatingConditionData, [:gating],
        excluded: %{resource_id: "recorded as source_resource_id"},
        pseudo_keys: %{
          source_resource_id: "prerequisite resource (GatingConditionData.resource_id)"
        }
      ),
      source(Oli.Delivery.Sections.Enrollment, [:enrollment],
        excluded:
          row(:enrollment)
          |> Map.merge(scope([:section_id]))
          |> Map.merge(%{
            user_id: "the enrolled learner; recorded in affected_user_id",
            most_recently_visited_resource_id: "navigation state, not access",
            state: "learner progress state maintained by the system"
          }),
        pseudo_keys: %{context_roles: "roles held through EnrollmentContextRole"}
      ),
      source(Oli.Delivery.Sections.SectionInvite, [:enrollment],
        excluded:
          row(:section_invite)
          |> Map.merge(scope([:section_id]))
          |> Map.merge(%{slug: "invitation link token, never recorded"})
      ),
      source(Oli.Delivery.Sections.SectionsProjectsPublications, [:publication],
        excluded:
          timestamps()
          |> Map.merge(scope(~w(section_id project_id)a))
      ),
      source(Oli.Delivery.Paywall.Discount, [:discount],
        excluded: row(:discount) |> Map.merge(scope(~w(section_id institution_id)a))
      ),
      source(Oli.Delivery.Paywall.Payment, [:entitlement],
        excluded:
          row(:payment)
          |> Map.merge(scope([:section_id]))
          |> Map.merge(
            excluded(
              ~w(provider_type provider_id provider_payload)a,
              "payment provider data, never recorded"
            )
          )
          |> Map.merge(
            excluded(
              ~w(pending_user_id pending_section_id)a,
              "checkout state of an unfinished payment"
            )
          )
          |> Map.merge(
            excluded(
              ~w(bypassed_by_user_id invalidated_by_user_id)a,
              "the acting admin; recorded as the event actor"
            )
          )
          |> Map.merge(%{
            code: "redeemable payment code, never recorded",
            generation_date:
              "set when codes are generated; recorded by payment_code_administered",
            amount: "amount charged by the provider, not edited by admins",
            enrollment_id: "the entitled enrollment; recorded in entity_id"
          })
      ),
      source(Oli.Delivery.Sections.Certificate, [:certificate_settings],
        excluded: row(:certificate) |> Map.merge(scope([:section_id]))
      ),
      source(Oli.Delivery.Sections.GrantedCertificate, [:certificate_decision],
        excluded:
          row(:granted_certificate)
          |> Map.merge(
            excluded(~w(issued_by issued_by_type)a, "the issuer; recorded as the event actor")
          )
          |> Map.merge(%{
            guid: "public certificate identifier, set when issued",
            issued_at: "set by the system when issued",
            url: "generated certificate file",
            student_email_sent: "notification bookkeeping",
            certificate_id: "certificate settings row, fixed at creation",
            user_id: "the certificate holder; recorded in affected_user_id"
          })
      ),
      source(Oli.Institutions.Institution, [:organization], excluded: row(:institution)),
      source(Oli.Groups.Community, [:organization],
        excluded: row(:community),
        pseudo_keys: %{
          members:
            "membership through CommunityAccount, CommunityVisibility, and CommunityInstitution"
        }
      ),
      source(Oli.Inventories.Publisher, [:organization], excluded: row(:publisher)),
      source(Oli.Lti.Tool.Registration, [:integration],
        excluded: row(:registration),
        pseudo_keys: %{
          private_key: "tool signing key (JWK); only its redaction marker is recorded"
        }
      ),
      source(Oli.Lti.Tool.Deployment, [:integration],
        excluded:
          row(:deployment)
          |> Map.merge(%{registration_id: "parent registration, fixed at creation"})
      ),
      source(Lti_1p3.DataProviders.EctoProvider.PlatformInstance, [:integration],
        excluded:
          row(:external_tool)
          |> Map.merge(%{guid: "stable tool identifier; recorded in entity_id"})
      ),
      source(Oli.Lti.PlatformExternalTools.LtiExternalToolActivityDeployment, [:integration],
        excluded:
          timestamps()
          |> Map.merge(
            excluded(
              ~w(activity_registration_id platform_instance_id)a,
              "links fixed when the tool is registered"
            )
          )
      ),
      source(Oli.Lti.PlatformExternalTools.LtiSectionResourceDeepLink, [:integration],
        excluded:
          row(:deep_link)
          |> Map.merge(scope([:section_id, :resource_id]))
          |> Map.merge(%{type: "kind of link the tool returned; the url records the choice"})
      ),
      source(Oli.GenAI.Completions.RegisteredModel, [:ai_service], excluded: row(:ai_service)),
      source(Oli.GenAI.Completions.ServiceConfig, [:ai_service], excluded: row(:ai_service)),
      source(Oli.GenAI.FeatureConfig, [:ai_service, :dot_activation],
        excluded: row(:feature_config) |> Map.merge(scope([:section_id]))
      ),
      source(Oli.Interop.ApiKey, [:credential],
        excluded:
          row(:api_key)
          |> Map.merge(%{
            hash: "credential hash, never recorded",
            hint: "partial key hint; recorded in details"
          }),
        pseudo_keys: %{lifecycle: "created, rotated, enabled, disabled, or revoked"}
      ),
      source(Oli.MCP.Auth.BearerToken, [:credential],
        excluded:
          row(:mcp_token)
          |> Map.merge(scope([:project_id]))
          |> Map.merge(%{
            hash: "credential hash, never recorded",
            hint: "partial token hint; recorded in details",
            last_used_at: "usage bookkeeping",
            author_id: "the token owner; recorded in affected_author_id"
          })
      )
    ]
  end

  defp source(schema, policies, opts \\ []) do
    %{
      schema: schema,
      policies: policies,
      excluded: Keyword.get(opts, :excluded, %{}),
      pseudo_keys: Keyword.get(opts, :pseudo_keys, %{})
    }
  end

  defp row(entity), do: Map.put(timestamps(), :id, "identity; recorded in entity_id (#{entity})")

  defp timestamps,
    do: excluded(~w(inserted_at updated_at)a, "row timestamps, not settings")

  defp scope(columns),
    do: Map.new(columns, &{&1, "scope; recorded in the #{&1} column"})

  defp excluded(fields, reason), do: Map.new(fields, &{&1, reason})

  defp values(fields), do: Map.new(fields, &{&1, :value})
  defp secrets(fields), do: Map.new(fields, &{&1, :secret})
end
