defmodule Oli.Delivery.Sections.SectionCopyTest do
  use Oli.DataCase

  import Ecto.Query, warn: false
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Gating
  alias Oli.Delivery.Gating.GatingCondition
  alias Oli.Delivery.SectionCreationRequest
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.CopyOptions
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionCopy
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionSpecification
  alias Oli.Delivery.Sections.SectionsProjectsPublications

  @all_groups [:content, :schedule, :section_settings, :assessment_settings, :ai_settings]

  setup do
    seed = Seeder.base_project_with_resource2()

    {:ok, source} =
      Sections.create_section(%{
        type: :enrollable,
        title: "Source Section",
        registration_open: true,
        context_id: UUID.uuid4(),
        institution_id: seed.institution.id,
        base_project_id: seed.project.id
      })
      |> then(fn {:ok, section} -> section end)
      |> Sections.create_section_resources(seed.publication)

    {:ok, Map.merge(seed, %{source: source})}
  end

  # ---------------------------------------------------------------------------
  # Structural independence
  # ---------------------------------------------------------------------------

  describe "structural independence" do
    test "the copy is a distinct section with fresh identity", %{source: source} do
      {:ok, copy} = copy(source, @all_groups)

      assert copy.id != source.id
      assert copy.slug != source.slug
      assert copy.context_id != source.context_id
      assert copy.status == :active
      assert copy.type == :enrollable
    end

    test "copied section resources are disjoint from the source's", %{source: source} do
      {:ok, copy} = copy(source, @all_groups)

      source_ids = section_resource_ids(source)
      copy_ids = section_resource_ids(copy)

      assert length(copy_ids) == length(source_ids)
      assert MapSet.disjoint?(MapSet.new(source_ids), MapSet.new(copy_ids))
    end

    test "children point only at destination section resources", %{source: source} do
      {:ok, copy} = copy(source, @all_groups)

      copy_ids = copy |> section_resource_ids() |> MapSet.new()

      all_children =
        copy
        |> section_resources()
        |> Enum.flat_map(& &1.children)

      # The seeded project has a container with two pages, so this must not be
      # a vacuous assertion over an empty list.
      assert all_children != []
      assert Enum.all?(all_children, &MapSet.member?(copy_ids, &1))
    end

    test "the root section resource belongs to the copy", %{source: source} do
      {:ok, copy} = copy(source, @all_groups)

      root = Repo.get(SectionResource, copy.root_section_resource_id)

      assert root.section_id == copy.id
      assert copy.root_section_resource_id != source.root_section_resource_id
    end

    test "publication pins are duplicated as destination-owned rows", %{source: source} do
      other_publication = insert(:publication)

      {:ok, _} =
        Sections.create_section_project_publication(%{
          section_id: source.id,
          project_id: other_publication.project_id,
          publication_id: other_publication.id
        })

      {:ok, copy} = copy(source, @all_groups)

      source_pins = publication_pins(source)
      copy_pins = publication_pins(copy)

      assert length(source_pins) == 2
      assert length(copy_pins) == length(source_pins)
      assert Enum.all?(copy_pins, &(&1.section_id == copy.id))

      assert Enum.map(source_pins, & &1.publication_id) |> Enum.sort() ==
               Enum.map(copy_pins, & &1.publication_id) |> Enum.sort()
    end

    test "copied section resources are stamped with their own timestamps", %{source: source} do
      # Age the source rows so an inherited timestamp would be unmistakable.
      past = DateTime.utc_now() |> DateTime.add(-30, :day) |> DateTime.truncate(:second)

      from(sr in SectionResource, where: sr.section_id == ^source.id)
      |> Repo.update_all(set: [inserted_at: past])

      {:ok, copy} = copy(source, @all_groups)

      assert copy
             |> section_resources()
             |> Enum.all?(&(DateTime.compare(&1.inserted_at, past) == :gt))
    end
  end

  # ---------------------------------------------------------------------------
  # Lineage
  # ---------------------------------------------------------------------------

  describe "lineage" do
    test "a nil source blueprint_id stays nil", %{source: source} do
      assert is_nil(source.blueprint_id)

      {:ok, copy} = copy(source, @all_groups)

      assert is_nil(copy.blueprint_id)
    end

    test "the source's blueprint is inherited, and the source is never the blueprint",
         %{source: source, project: project, publication: publication} do
      {:ok, product} =
        Sections.create_section(%{
          type: :blueprint,
          title: "A Product",
          registration_open: true,
          context_id: UUID.uuid4(),
          base_project_id: project.id,
          publisher_id: project.publisher_id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(publication)

      {:ok, seeded} = Sections.update_section(source, %{blueprint_id: product.id})

      {:ok, copy} = copy(seeded, @all_groups)

      assert copy.blueprint_id == product.id
      refute copy.blueprint_id == seeded.id
    end

    test "base_project_id is carried over", %{source: source} do
      {:ok, copy} = copy(source, @all_groups)

      assert copy.base_project_id == source.base_project_id
    end

    test "no section column references the source section", %{source: source} do
      {:ok, copy} = copy(source, @all_groups)

      referencing =
        copy
        |> Map.from_struct()
        |> Enum.filter(fn {key, value} ->
          is_integer(value) and value == source.id and
            String.ends_with?(Atom.to_string(key), "_id")
        end)

      assert referencing == []
    end
  end

  # ---------------------------------------------------------------------------
  # Always-new section fields
  # ---------------------------------------------------------------------------

  describe "always-new section fields" do
    test "identity, integration and payment state are never inherited", %{source: source} do
      {:ok, source} =
        Sections.update_section(source, %{
          invite_token: "a-token",
          passcode: "a-passcode",
          grade_passback_enabled: true,
          line_items_service_url: "https://lms.example.com/line_items",
          nrps_enabled: true,
          nrps_context_memberships_url: "https://lms.example.com/memberships",
          requires_payment: false,
          amount: Money.new(100, "USD"),
          grace_period_days: 3,
          pay_by_institution: true,
          visibility: :selected,
          apply_major_updates: true,
          previous_next_index: %{"1" => %{}}
        })

      {:ok, copy} = copy(source, @all_groups)

      assert is_nil(copy.invite_token)
      assert is_nil(copy.passcode)
      refute copy.grade_passback_enabled
      assert is_nil(copy.line_items_service_url)
      refute copy.nrps_enabled
      assert is_nil(copy.nrps_context_memberships_url)
      refute copy.requires_payment
      refute copy.pay_by_institution
      assert is_nil(copy.grace_period_days)
      assert copy.visibility == :global
      refute copy.apply_major_updates
      assert is_nil(copy.previous_next_index)
      assert is_nil(copy.lti_1p3_deployment_id)
      assert is_nil(copy.institution_id)
    end

    test "copying a paid course does not remove its paywall", %{source: source, project: project} do
      price = Money.new(1000, "USD")

      product =
        insert(:section,
          type: :blueprint,
          base_project: project,
          requires_payment: true,
          amount: price,
          has_grace_period: false
        )

      {:ok, source} =
        Sections.update_section(source, %{
          blueprint_id: product.id,
          requires_payment: true,
          amount: price,
          has_grace_period: false
        })

      instructor = insert(:user, can_create_sections: true)

      {:ok, _} =
        Sections.enroll(instructor.id, source.id, [
          ContextRoles.get_role(:context_instructor)
        ])

      {:ok, request} =
        SectionCreationRequest.new(
          instructor,
          "section:#{source.id}",
          %{title: "Paid course copy"},
          SectionSpecification.direct()
        )

      {:ok, copy_id, _slug} = Oli.Delivery.create_section(request)
      copied = Sections.get_section!(copy_id)

      student = insert(:user)

      {:ok, _} =
        Sections.enroll(student.id, copied.id, [
          ContextRoles.get_role(:context_learner)
        ])

      access = Oli.Delivery.Paywall.summarize_access(student, copied)
      refute access.reason == :not_paywalled
      assert copied.requires_payment
    end

    test "an archived source produces an active copy", %{source: source} do
      {:ok, source} = Sections.update_section(source, %{status: :archived})

      {:ok, copy} = copy(source, @all_groups)

      assert copy.status == :active
    end

    test "a legacy analytics version does not propagate", %{source: source} do
      {:ok, source} = Sections.update_section(source, %{analytics_version: :v1})

      {:ok, copy} = copy(source, @all_groups)

      assert copy.analytics_version == :v2
    end

    test "preserves the source learning model", %{source: source} do
      source =
        source
        |> Section.trusted_learning_model_changeset(%{learning_model_version: :lkt_aoa})
        |> Repo.update!()

      {:ok, copy} = copy(source, @all_groups)

      assert copy.learning_model_version == :lkt_aoa
    end

    test "rejects destination attempts to override protected fields", %{source: source} do
      sections_before = Repo.aggregate(Section, :count, :id)

      assert {:error, {:invalid_destination_fields, rejected}} =
               copy(source, @all_groups, %{
                 "type" => "blueprint",
                 base_project_id: insert(:project).id,
                 requires_payment: true
               })

      assert MapSet.new(rejected) == MapSet.new([:base_project_id, "type", :requires_payment])
      assert Repo.aggregate(Section, :count, :id) == sections_before
    end

    test "destination attributes provide fresh course identity", %{source: source} do
      {:ok, copy} =
        copy(source, @all_groups, %{
          title: "Fall 2026 Section",
          course_section_number: "42"
        })

      assert copy.title == "Fall 2026 Section"
      assert copy.course_section_number == "42"
    end
  end

  # ---------------------------------------------------------------------------
  # Group policies
  # ---------------------------------------------------------------------------

  describe ":schedule" do
    test "selected: absolute dates are preserved exactly", %{source: source, page1: page1} do
      start_date = ~U[2026-02-01 12:00:00Z]
      end_date = ~U[2026-02-08 12:00:00Z]

      update_page_settings(source, page1, %{
        start_date: start_date,
        end_date: end_date,
        manually_scheduled: true,
        removed_from_schedule: true
      })

      {:ok, copy} = copy(source, [:content, :schedule])
      copied = page_resource(copy, page1)

      assert copied.start_date == start_date
      assert copied.end_date == end_date
      assert copied.manually_scheduled
      assert copied.removed_from_schedule
    end

    test "unselected: dates are reset and no source date leaks", %{source: source, page1: page1} do
      update_page_settings(source, page1, %{
        start_date: ~U[2026-02-01 12:00:00Z],
        end_date: ~U[2026-02-08 12:00:00Z],
        manually_scheduled: true,
        removed_from_schedule: true
      })

      {:ok, copy} = copy(source, [:content])
      copied = page_resource(copy, page1)

      assert is_nil(copied.start_date)
      assert is_nil(copied.end_date)
      refute copied.manually_scheduled
      refute copied.removed_from_schedule
    end

    test "unselected: scheduling type resets with the rest of the schedule",
         %{source: source, page1: page1} do
      update_page_settings(source, page1, %{scheduling_type: :due_by})

      {:ok, copy} = copy(source, [:content])

      assert page_resource(copy, page1).scheduling_type == :read_by
    end
  end

  describe "destination billing" do
    test "a paid course without a product fails without creating a section", %{source: source} do
      {:ok, source} =
        Sections.update_section(source, %{
          requires_payment: true,
          amount: Money.new(1000, "USD"),
          has_grace_period: false
        })

      before = Repo.aggregate(Section, :count)
      assert {:error, :billing_source_not_found} = copy(source, [:content])
      assert Repo.aggregate(Section, :count) == before
    end

    test "billing uses destination discounts and product policy, not source payment state",
         %{source: source, project: project, institution: source_institution} do
      price = Money.new(1000, "USD")

      product =
        insert(:section,
          type: :blueprint,
          base_project: project,
          requires_payment: true,
          amount: price,
          has_grace_period: true,
          grace_period_days: 7,
          payment_options: :direct
        )

      insert(:discount, section: product, institution: source_institution, percentage: 90)
      destination_institution = insert(:institution)
      insert(:discount, section: product, institution: destination_institution, percentage: 25)

      {:ok, source} =
        Sections.update_section(source, %{
          blueprint_id: product.id,
          requires_payment: true,
          amount: Money.new(100, "USD"),
          has_grace_period: false
        })

      enrollment = insert(:enrollment, section: source)
      payment = insert(:payment, section: source, enrollment: enrollment)

      {:ok, copied} = copy(source, [:content], %{institution_id: destination_institution.id})

      assert copied.requires_payment
      assert copied.amount == Money.new(750, "USD")
      assert copied.payment_options == :direct
      assert copied.has_grace_period
      assert copied.grace_period_days == 7
      assert count_for_section("payments", copied.id) == 0
      assert count_for_section("enrollments", copied.id) == 0
      assert Repo.get!(Oli.Delivery.Paywall.Payment, payment.id).section_id == source.id

      {:ok, direct_copy} = copy(source, [:content])
      assert direct_copy.amount == price
      assert direct_copy.requires_payment
    end

    test "an institution paywall bypass is not carried into a direct course",
         %{source: source, project: project, institution: institution} do
      price = Money.new(1000, "USD")

      product =
        insert(:section,
          type: :blueprint,
          base_project: project,
          requires_payment: true,
          amount: price,
          has_grace_period: false
        )

      insert(:discount, section: product, institution: institution, bypass_paywall: true)
      {:ok, source} = Sections.update_section(source, %{blueprint_id: product.id})

      {:ok, institutional_copy} = copy(source, [:content], %{institution_id: institution.id})
      refute institutional_copy.requires_payment

      {:ok, direct_copy} = copy(source, [:content])
      assert direct_copy.requires_payment
      assert direct_copy.amount == price
    end

    test "a paid product missing its price fails closed", %{source: source, project: project} do
      product =
        insert(:section,
          type: :blueprint,
          base_project: project,
          requires_payment: true,
          amount: nil,
          has_grace_period: false
        )

      {:ok, source} = Sections.update_section(source, %{blueprint_id: product.id})
      assert {:error, :billing_amount_missing} = copy(source, [:content])
    end
  end

  describe ":assessment_settings" do
    @assessment_overrides %{
      max_attempts: 7,
      retake_mode: :targeted,
      assessment_mode: :one_at_a_time,
      late_submit: :disallow,
      late_start: :disallow,
      time_limit: 45,
      grace_period: 10,
      password: "hunter2",
      review_submission: :disallow,
      allow_hints: true
    }

    test "selected: assessment configuration is carried", %{source: source, page1: page1} do
      update_page_settings(source, page1, @assessment_overrides)

      {:ok, copy} = copy(source, [:content, :assessment_settings])
      copied = page_resource(copy, page1)

      for {field, value} <- @assessment_overrides do
        assert Map.get(copied, field) == value, "expected #{field} to be copied"
      end
    end

    test "unselected: settings reset to what a fresh section would have",
         %{source: source, page1: page1} do
      update_page_settings(source, page1, @assessment_overrides)

      {:ok, copy} = copy(source, [:content])
      copied = page_resource(copy, page1)
      revision = pinned_revision(copy, page1)

      assert copied.max_attempts == (revision.max_attempts || 0)
      assert copied.retake_mode == revision.retake_mode
      assert copied.assessment_mode == revision.assessment_mode
      assert copied.scoring_strategy_id == revision.scoring_strategy_id
      assert copied.late_submit == :allow
      assert copied.late_start == :allow
      assert copied.time_limit == 0
      assert copied.grace_period == 0
      assert is_nil(copied.password)
      assert copied.review_submission == :allow
      refute copied.allow_hints
    end

    test "assessment settings copy independently of the schedule",
         %{source: source, page1: page1} do
      update_page_settings(source, page1, %{
        max_attempts: 7,
        start_date: ~U[2026-02-01 12:00:00Z]
      })

      {:ok, copy} = copy(source, [:content, :assessment_settings])
      copied = page_resource(copy, page1)

      assert copied.max_attempts == 7
      assert is_nil(copied.start_date)
    end

    test "feedback_scheduled_date needs both assessment settings and schedule",
         %{source: source, page1: page1} do
      scheduled = ~U[2026-03-01 12:00:00Z]

      update_page_settings(source, page1, %{
        feedback_mode: :scheduled,
        feedback_scheduled_date: scheduled,
        start_date: ~U[2026-02-01 12:00:00Z]
      })

      {:ok, both} = copy(source, [:content, :assessment_settings, :schedule])
      assert page_resource(both, page1).feedback_scheduled_date == scheduled
      assert page_resource(both, page1).feedback_mode == :scheduled

      {:ok, assessment_only} = copy(source, [:content, :assessment_settings])
      assert is_nil(page_resource(assessment_only, page1).feedback_scheduled_date)
      assert page_resource(assessment_only, page1).feedback_mode == :disallow

      refute Oli.Delivery.Settings.show_feedback?(
               Oli.Delivery.Settings.combine(
                 pinned_revision(assessment_only, page1),
                 page_resource(assessment_only, page1),
                 nil
               )
             )

      {:ok, schedule_only} = copy(source, [:content, :schedule])
      assert is_nil(page_resource(schedule_only, page1).feedback_scheduled_date)
      assert page_resource(schedule_only, page1).feedback_mode == :allow
    end

    test "non-scheduled feedback modes remain unchanged without schedule",
         %{source: source, page1: page1} do
      for mode <- [:allow, :disallow] do
        update_page_settings(source, page1, %{feedback_mode: mode})
        {:ok, copied} = copy(source, [:content, :assessment_settings])
        assert page_resource(copied, page1).feedback_mode == mode
      end
    end

    test "scheduled feedback remains evaluable when assessment settings are copied without schedule",
         %{source: source, page1: page1} do
      update_page_settings(source, page1, %{
        feedback_mode: :scheduled,
        feedback_scheduled_date: ~U[2026-03-01 12:00:00Z]
      })

      {:ok, copy} = copy(source, [:content, :assessment_settings])
      copied = page_resource(copy, page1)

      assert is_nil(copied.feedback_scheduled_date)

      effective_settings =
        Oli.Delivery.Settings.combine(pinned_revision(copy, page1), copied, nil)

      # Learner page delivery evaluates these settings when building its page context.
      assert is_boolean(Oli.Delivery.Settings.show_feedback?(effective_settings))
    end
  end

  describe "required survey snapshot" do
    test "an existing required survey is retained and resolves from copied publication pins",
         %{project: project, author: author} do
      survey = Oli.Authoring.Course.create_project_survey(project, author.id)
      project = Oli.Authoring.Course.get_project!(project.id)
      {:ok, publication} = Oli.Publishing.publish_project(project, "With survey", author.id)

      {:ok, source} =
        Sections.create_section(%{
          title: "Course requiring a survey",
          type: :enrollable,
          base_project_id: project.id,
          required_survey_resource_id: survey.resource_id
        })

      {:ok, source} = Sections.create_section_resources(source, publication)
      {:ok, copied} = copy(source, [:content])

      assert copied.required_survey_resource_id == survey.resource_id
      assert Sections.get_survey(copied.slug).resource_id == survey.resource_id
      assert publication_pins(copied) |> Enum.map(& &1.publication_id) == [publication.id]

      {:ok, _} = Sections.update_section(source, %{required_survey_resource_id: nil})
      assert reload(copied).required_survey_resource_id == survey.resource_id
    end
  end

  describe "required survey" do
    test "copying an older publication does not require a subsequently authored survey",
         %{source: source, project: project, author: author} do
      # The source keeps this publication while later authoring uses a new working publication.
      {:ok, _publication} = Oli.Publishing.publish_project(project, "Source snapshot", author.id)
      survey = Oli.Authoring.Course.create_project_survey(project, author.id)

      assert survey.resource_id
      assert is_nil(source.required_survey_resource_id)

      instructor = insert(:user, can_create_sections: true)

      {:ok, _enrollment} =
        Sections.enroll(instructor.id, source.id, [
          ContextRoles.get_role(:context_instructor)
        ])

      {:ok, request} =
        SectionCreationRequest.new(
          instructor,
          "section:#{source.id}",
          %{title: "Copied older course"},
          SectionSpecification.direct()
        )

      {:ok, copy_id, copy_slug} = Oli.Delivery.create_section(request)
      copied = Sections.get_section!(copy_id)
      required_survey = Sections.get_survey(copy_slug)

      # Onboarding must be able to resolve any survey that the destination requires.
      assert is_nil(copied.required_survey_resource_id) or not is_nil(required_survey)
      assert copied.required_survey_resource_id == source.required_survey_resource_id
    end
  end

  describe ":ai_settings" do
    test "selected: a per-page override survives the section resource migration",
         %{source: source, page1: page1} do
      # This is the regression guard for the ordering bug: migrate/1 rewrites
      # ai_enabled from the pinned revision after the rows are inserted, so an
      # override is only preserved if it is re-applied afterwards.
      revision = pinned_revision(source, page1)
      override = !revision.ai_enabled

      update_page_settings(source, page1, %{ai_enabled: override})

      {:ok, copy} = copy(source, [:content, :ai_settings])

      assert page_resource(copy, page1).ai_enabled == override
    end

    test "selected: a per-page override survives the whole creation path",
         %{source: source, page1: page1} do
      # SectionCopy.copy/3 is not the last thing that touches ai_enabled: the
      # creation path runs contained-page and contained-objective rebuilds and a
      # second post-processing pass afterwards. Assert through all of it.
      revision = pinned_revision(source, page1)
      override = !revision.ai_enabled

      update_page_settings(source, page1, %{ai_enabled: override})

      {:ok, options} = CopyOptions.for_previous_section([:content, :ai_settings])
      instructor = insert(:user)

      {:ok, _enrollment} =
        Sections.enroll(instructor.id, source.id, [
          ContextRoles.get_role(:context_instructor)
        ])

      {:ok, request} =
        SectionCreationRequest.new(
          instructor,
          "section:#{source.id}",
          %{title: "Copied Section"},
          SectionSpecification.direct()
        )

      {:ok, copy_id, _slug} =
        Oli.Delivery.create_section(%{request | copy_options: options})

      copy = Sections.get_section!(copy_id)

      assert page_resource(copy, page1).ai_enabled == override
    end

    test "unselected: per-page ai_enabled falls back to the pinned revision",
         %{source: source, page1: page1} do
      revision = pinned_revision(source, page1)
      update_page_settings(source, page1, %{ai_enabled: !revision.ai_enabled})

      {:ok, copy} = copy(source, [:content])

      assert page_resource(copy, page1).ai_enabled == revision.ai_enabled
    end

    test "selected: section level assistant configuration is carried", %{source: source} do
      {:ok, source} =
        Sections.update_section(source, %{
          assistant_enabled: true,
          triggers_enabled: true,
          page_prompt_template: "a template",
          instructor_recommendations_enabled: false,
          instructor_recommendation_prompt_template: "another template"
        })

      {:ok, copy} = copy(source, [:content, :ai_settings])

      assert copy.assistant_enabled
      assert copy.triggers_enabled
      assert copy.page_prompt_template == "a template"
      refute copy.instructor_recommendations_enabled
      assert copy.instructor_recommendation_prompt_template == "another template"
    end

    test "unselected: section level assistant configuration resets", %{source: source} do
      {:ok, source} =
        Sections.update_section(source, %{
          assistant_enabled: true,
          triggers_enabled: true,
          page_prompt_template: "a template"
        })

      {:ok, copy} = copy(source, [:content])

      refute copy.assistant_enabled
      refute copy.triggers_enabled
      assert is_nil(copy.page_prompt_template)
    end
  end

  describe ":section_settings" do
    test "selected: instructor-owned section configuration is carried", %{source: source} do
      {:ok, source} =
        Sections.update_section(source, %{
          display_curriculum_item_numbering: false,
          agenda: false,
          welcome_title: %{"type" => "p", "children" => []},
          encouraging_subtitle: "Let us begin",
          cover_image: "https://example.com/cover.png"
        })

      {:ok, copy} = copy(source, [:content, :section_settings])

      refute copy.display_curriculum_item_numbering
      refute copy.agenda
      assert copy.welcome_title == %{"type" => "p", "children" => []}
      assert copy.encouraging_subtitle == "Let us begin"
      assert copy.cover_image == "https://example.com/cover.png"
    end

    test "unselected: section configuration resets to defaults", %{source: source} do
      {:ok, source} =
        Sections.update_section(source, %{
          display_curriculum_item_numbering: false,
          agenda: false,
          encouraging_subtitle: "Let us begin"
        })

      {:ok, copy} = copy(source, [:content])

      assert copy.display_curriculum_item_numbering
      assert copy.agenda
      assert is_nil(copy.encouraging_subtitle)
    end
  end

  # ---------------------------------------------------------------------------
  # Gating
  # ---------------------------------------------------------------------------

  describe "gates" do
    test "a copied gate is actually enforced, not merely present",
         %{source: source, page1: page1} do
      {:ok, _gate} = create_schedule_gate(source, page1)
      {:ok, source} = set_gating_index(source, page1)

      {:ok, copy} = copy(source, [:content, :schedule])

      assert [_ | _] = Gating.list_gating_conditions(copy.id)

      # The index is what makes blocked_by/3 evaluate a gate at all; a copy with
      # gate rows and an empty index has gates that never run.
      refute copy.resource_gating_index == %{}

      user = insert(:user)
      assert Gating.blocked_by(reload(copy), user, page1.id) != []
    end

    test "student specific exceptions are not copied", %{source: source, page1: page1} do
      {:ok, gate} = create_schedule_gate(source, page1)
      user = insert(:user)

      {:ok, _exception} =
        Gating.create_gating_condition(%{
          type: :schedule,
          section_id: source.id,
          resource_id: page1.id,
          parent_id: gate.id,
          user_id: user.id,
          graded_resource_policy: :allows_review,
          data: %{end_datetime: ~U[2026-05-01 12:00:00Z]}
        })

      {:ok, copy} = copy(source, [:content, :schedule])

      copied = Gating.list_gating_conditions(copy.id)

      assert length(copied) == 1
      assert Enum.all?(copied, &is_nil(&1.parent_id))
      assert Enum.all?(copied, &is_nil(&1.user_id))
    end

    test "schedule-shaped gates follow the schedule group", %{source: source, page1: page1} do
      {:ok, _gate} = create_schedule_gate(source, page1)
      {:ok, source} = set_gating_index(source, page1)

      {:ok, without_schedule} = copy(source, [:content])

      # A date gate copied into a section that deliberately took no schedule
      # would gate the course on the source term's dates.
      assert Gating.list_gating_conditions(without_schedule.id) == []
      assert without_schedule.resource_gating_index == %{}
    end

    test "non-schedule gates follow the content group", %{
      source: source,
      page1: page1,
      page2: page2
    } do
      {:ok, _gate} =
        Gating.create_gating_condition(%{
          type: :finished,
          section_id: source.id,
          resource_id: page2.id,
          graded_resource_policy: :allows_review,
          data: %{resource_id: page1.id}
        })

      {:ok, source} = set_gating_index(source, page2)

      {:ok, copy} = copy(source, [:content])

      assert [copied] = Gating.list_gating_conditions(copy.id)
      assert copied.type == :finished
      refute copy.resource_gating_index == %{}
    end

    test "a gate that cannot be written rolls the entire copy back",
         %{source: source, page1: page1} do
      # A legacy row whose data fails present-day validation: end before start.
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Repo.insert_all(GatingCondition, [
        %{
          type: :schedule,
          section_id: source.id,
          resource_id: page1.id,
          graded_resource_policy: :allows_review,
          data: %Oli.Delivery.Gating.GatingConditionData{
            start_datetime: ~U[2026-05-01 12:00:00Z],
            end_datetime: ~U[2026-04-01 12:00:00Z]
          },
          inserted_at: now,
          updated_at: now
        }
      ])

      sections_before = Repo.aggregate(Section, :count, :id)

      assert {:error, _reason} = copy(source, [:content, :schedule])

      assert Repo.aggregate(Section, :count, :id) == sections_before
    end
  end

  # ---------------------------------------------------------------------------
  # Learner data isolation
  # ---------------------------------------------------------------------------

  describe "learner data" do
    test "no enrollment is copied", %{source: source} do
      student = insert(:user)
      instructor = insert(:user)

      {:ok, _} = Sections.enroll(student.id, source.id, [ContextRoles.get_role(:context_learner)])

      {:ok, _} =
        Sections.enroll(instructor.id, source.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, copy} = copy(source, @all_groups)

      assert Repo.aggregate(from(e in Enrollment, where: e.section_id == ^copy.id), :count, :id) ==
               0

      # The source keeps its roster.
      assert Repo.aggregate(
               from(e in Enrollment, where: e.section_id == ^source.id),
               :count,
               :id
             ) == 2
    end

    test "learner-owned tables gain no rows for the copy", %{source: source} do
      student = insert(:user)
      {:ok, _} = Sections.enroll(student.id, source.id, [ContextRoles.get_role(:context_learner)])

      {:ok, copy} = copy(source, @all_groups)

      for table <- ["enrollments", "resource_accesses", "delivery_settings", "posts"] do
        assert count_for_section(table, copy.id) == 0,
               "expected no #{table} rows for the copied section"
      end

      # Attempt rows hang off resource_accesses, which the copy has none of, so
      # there is no path by which learner attempt data can reach it.
      assert count_for_section("resource_accesses", copy.id) == 0
    end
  end

  # ---------------------------------------------------------------------------
  # Independence after editing
  # ---------------------------------------------------------------------------

  describe "independence after creation" do
    test "later source changes do not reach the copy", %{source: source, page1: page1} do
      update_page_settings(source, page1, %{max_attempts: 3})
      {:ok, copy} = copy(source, @all_groups)

      {:ok, _} = Sections.update_section(reload(source), %{title: "Renamed Source"})
      update_page_settings(source, page1, %{max_attempts: 99})

      reloaded = reload(copy)

      assert reloaded.title != "Renamed Source"
      assert page_resource(reloaded, page1).max_attempts == 3
    end

    test "later copy changes do not reach the source", %{source: source, page1: page1} do
      update_page_settings(source, page1, %{max_attempts: 3})
      {:ok, copy} = copy(source, @all_groups)

      {:ok, _} = Sections.update_section(copy, %{title: "Renamed Copy"})
      update_page_settings(copy, page1, %{max_attempts: 99})

      reloaded = reload(source)

      assert reloaded.title == "Source Section"
      assert page_resource(reloaded, page1).max_attempts == 3
    end

    test "removing a page from the copy leaves the source intact",
         %{source: source, page1: page1} do
      {:ok, copy} = copy(source, @all_groups)

      copied_page = page_resource(copy, page1)
      {:ok, _} = Sections.update_section_resource(copied_page, %{hidden: true})

      refute page_resource(source, page1).hidden
    end
  end

  # ---------------------------------------------------------------------------
  # Failure handling
  # ---------------------------------------------------------------------------

  describe "failure handling" do
    test "an invalid destination leaves no partial section behind", %{source: source} do
      sections_before = Repo.aggregate(Section, :count, :id)

      assert {:error, _} = copy(source, @all_groups, %{title: String.duplicate("x", 300)})

      assert Repo.aggregate(Section, :count, :id) == sections_before
    end

    test "a retry after a failure succeeds", %{source: source} do
      assert {:error, _} = copy(source, @all_groups, %{title: String.duplicate("x", 300)})
      assert {:ok, copy} = copy(source, @all_groups, %{title: "Second Attempt"})

      assert copy.title == "Second Attempt"
      assert length(section_resource_ids(copy)) == length(section_resource_ids(source))
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp copy(source, groups, attrs \\ %{}) do
    {:ok, options} = CopyOptions.for_previous_section(groups)

    destination_attrs =
      Map.merge(%{title: "Copied Section"}, attrs)

    SectionCopy.copy(source, destination_attrs, options)
  end

  defp reload(%Section{id: id}), do: Repo.get(Section, id)

  defp section_resources(%Section{id: id}) do
    from(sr in SectionResource, where: sr.section_id == ^id, order_by: sr.id) |> Repo.all()
  end

  defp section_resource_ids(section), do: section |> section_resources() |> Enum.map(& &1.id)

  defp publication_pins(%Section{id: id}) do
    from(spp in SectionsProjectsPublications, where: spp.section_id == ^id) |> Repo.all()
  end

  defp page_resource(%Section{id: id}, page) do
    Repo.one!(
      from(sr in SectionResource, where: sr.section_id == ^id and sr.resource_id == ^page.id)
    )
  end

  defp update_page_settings(section, page, attrs) do
    {:ok, _} = section |> page_resource(page) |> Sections.update_section_resource(attrs)
  end

  defp pinned_revision(%Section{id: id}, page) do
    Repo.one!(
      from(spp in SectionsProjectsPublications,
        join: pr in Oli.Publishing.PublishedResource,
        on: pr.publication_id == spp.publication_id,
        join: r in Oli.Resources.Revision,
        on: r.id == pr.revision_id,
        where: spp.section_id == ^id and r.resource_id == ^page.id,
        select: r
      )
    )
  end

  # `blocked_by/3` looks resources up in this index by string key, and returns
  # early for anything absent. Set it explicitly rather than regenerating it,
  # which would require a warm section resource depot.
  defp set_gating_index(section, page) do
    Sections.update_section(reload(section), %{
      resource_gating_index: %{Integer.to_string(page.id) => [page.id]}
    })
  end

  defp create_schedule_gate(section, page) do
    Gating.create_gating_condition(%{
      type: :schedule,
      section_id: section.id,
      resource_id: page.id,
      graded_resource_policy: :allows_review,
      data: %{
        start_datetime: ~U[2026-04-01 12:00:00Z],
        end_datetime: ~U[2026-05-01 12:00:00Z]
      }
    })
  end

  defp count_for_section(table, section_id) do
    %{rows: [[count]]} =
      Ecto.Adapters.SQL.query!(
        Repo,
        "SELECT count(*) FROM #{table} WHERE section_id = $1",
        [section_id]
      )

    count
  end
end
