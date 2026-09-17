defmodule Oli.Delivery.SectionCreationTest.FailingAuditor do
  @moduledoc false
  @behaviour Oli.Delivery.SectionCreationAuditor

  @impl true
  def capture(_actor, _event_type, _resource, _details),
    do: {:error, Oli.Auditing.LogEvent.changeset(%Oli.Auditing.LogEvent{}, %{})}
end

defmodule Oli.Delivery.SectionCreationTest do
  use Oli.DataCase

  import Oli.Factory
  import Oli.TestHelpers

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Accounts.SystemRole
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery
  alias Oli.Delivery.{SectionCreation, SectionCreationRequest}
  alias Oli.Delivery.Sections

  alias Oli.Delivery.Sections.{
    Enrollment,
    Section,
    SectionsProjectsPublications,
    SectionSpecification
  }

  alias Oli.Publishing
  alias Oli.Repo

  @instructor_role "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"
  @learner_role "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"
  @context_claims "https://purl.imsglobal.org/spec/lti/claim/context"
  @deployment_claims "https://purl.imsglobal.org/spec/lti/claim/deployment_id"
  @ags_claim "https://purl.imsglobal.org/spec/lti-ags/claim/endpoint"
  @nrps_claim "https://purl.imsglobal.org/spec/lti-nrps/claim/namesroleservice"
  @roles_claim "https://purl.imsglobal.org/spec/lti/claim/roles"

  describe "actor authorization" do
    setup [:publishable_source]

    test "T3 refuses a user without the creation right, on a source it is entitled to", %{
      publication: publication
    } do
      student = insert(:user, independent_learner: true, can_create_sections: false)

      assert {:ok, {:publication, _}} =
               SectionCreation.resolve_source(student, {:publication, publication.id}, nil)

      before = section_count()

      assert {:error, :unauthorized} =
               Delivery.create_section(
                 request!(student, "publication:#{publication.id}", %{title: "Student Section"})
               )

      assert section_count() == before
    end

    test "T5 admin author, LTI instructor and independent learner each create", %{
      project: project,
      publication: publication
    } do
      product = product_from(project, publication)

      assert {:ok, _id, _slug} =
               Delivery.create_section(
                 request!(admin_author(), "product:#{product.id}", %{title: "Admin Section"})
               )

      lms_user = insert(:user, independent_learner: false, can_create_sections: false)
      %{spec: lti_spec} = lti_launch(lms_user, unique_context_id(), [@instructor_role])

      assert {:ok, _id, _slug} =
               Delivery.create_section(
                 request!(
                   lms_user,
                   "publication:#{publication.id}",
                   %{title: "LTI Section"},
                   lti_spec
                 )
               )

      independent = insert(:user, independent_learner: true, can_create_sections: true)

      assert {:ok, _id, _slug} =
               Delivery.create_section(
                 request!(independent, "publication:#{publication.id}", %{title: "Direct Section"})
               )
    end

    test "T23 refuses an LTI learner for every source kind, whatever the direct right", %{
      project: project,
      publication: publication,
      section: enrollable_section
    } do
      product = product_from(project, publication)
      learner = insert(:user, independent_learner: false, can_create_sections: true)
      %{spec: lti_spec} = lti_launch(learner, unique_context_id(), [@learner_role])

      before = section_count()

      for source <- [
            "publication:#{publication.id}",
            "product:#{product.id}",
            "section:#{enrollable_section.id}"
          ] do
        assert {:error, :unauthorized} =
                 Delivery.create_section(
                   request!(learner, source, %{title: "Learner Section"}, lti_spec)
                 )
      end

      assert section_count() == before
    end

    test "T22 refuses an actor deleted after the request was built", %{publication: publication} do
      user = insert(:user, independent_learner: true, can_create_sections: true)
      request = request!(user, "publication:#{publication.id}", %{title: "Ghost Section"})

      Repo.delete!(user)
      before = section_count()

      assert {:error, :unauthorized} = Delivery.create_section(request)
      assert section_count() == before
    end
  end

  describe "source entitlement" do
    setup [:publishable_source]

    test "T1 refuses a section the actor does not teach, and resolves it for its instructor", %{
      section: source_section
    } do
      stranger = insert(:user, independent_learner: true, can_create_sections: true)
      before = section_count()

      assert {:error, :unauthorized} =
               Delivery.create_section(
                 request!(stranger, "section:#{source_section.id}", %{title: "Stolen Copy"})
               )

      assert section_count() == before

      instructor = insert(:user, independent_learner: true, can_create_sections: true)

      {:ok, _} =
        Sections.enroll(instructor.id, source_section.id, [
          ContextRoles.get_role(:context_instructor)
        ])

      assert {:ok, {:section, %Section{id: resolved_id}}} =
               SectionCreation.resolve_source(instructor, {:section, source_section.id}, nil)

      assert resolved_id == source_section.id
    end

    test "T2 refuses an enrollable section addressed as a product", %{section: source_section} do
      stranger = insert(:user, independent_learner: true, can_create_sections: true)
      before = section_count()

      assert {:error, :unauthorized} =
               Delivery.create_section(
                 request!(stranger, "product:#{source_section.id}", %{title: "Stolen Copy"})
               )

      assert section_count() == before
    end

    test "T10 refuses an archived product", %{project: project, publication: publication} do
      product = product_from(project, publication, status: :archived)

      assert {:error, :unauthorized} =
               Delivery.create_section(
                 request!(admin_author(), "product:#{product.id}", %{title: "Archived Source"})
               )
    end

    test "T4 refuses a publication whose project has a paid product the actor cannot see", %{
      publication: free_publication
    } do
      user = insert(:user, independent_learner: true, can_create_sections: true)

      # The project reaches this actor only through their community; the paid product on it
      # is not community associated, so the actor cannot see the product itself.
      paid_project = insert(:project, visibility: :selected)
      paid_publication = insert(:publication, project: paid_project)
      community = insert(:community, global_access: true)
      insert(:community_user_account, community: community, user: user)
      insert(:community_visibility, community: community, project: paid_project)

      paid_product =
        insert(:section,
          base_project: paid_project,
          type: :blueprint,
          status: :active,
          requires_payment: true,
          amount: Money.new(:USD, 25)
        )

      user = Repo.preload(user, :author)

      refute paid_product.id in Enum.map(SectionCreation.permitted_products(user, nil), & &1.id)

      assert {:error, :unauthorized} =
               Delivery.create_section(
                 request!(user, "publication:#{paid_publication.id}", %{title: "Free Ride"})
               )

      # The refusal is the paywall, not visibility: the same actor resolves the same
      # publication once the product stops requiring payment.
      paid_product |> Ecto.Changeset.change(requires_payment: false) |> Repo.update!()

      assert {:ok, {:publication, _}} =
               SectionCreation.resolve_source(user, {:publication, paid_publication.id}, nil)

      assert {:ok, _id, _slug} =
               Delivery.create_section(
                 request!(user, "publication:#{free_publication.id}", %{title: "Paid For"})
               )
    end

    test "T21 resolves any active enrollable section for an admin", %{section: source_section} do
      assert {:ok, {:section, %Section{id: resolved_id}}} =
               SectionCreation.resolve_source(admin_author(), {:section, source_section.id}, nil)

      assert resolved_id == source_section.id
    end

    test "T18 refuses malformed, retired and nonexistent identifiers, and drops forged attributes",
         %{publication: publication} do
      user = insert(:user, independent_learner: true, can_create_sections: true)
      spec = SectionSpecification.direct()

      for source <- ["garbage", "product:abc", "project:1", "publication:", "product:-1"] do
        assert {:error, :unauthorized} =
                 SectionCreationRequest.new(user, source, %{title: "Bad"}, spec)
      end

      before = section_count()

      assert {:error, :unauthorized} =
               Delivery.create_section(request!(user, "product:999999", %{title: "Nonexistent"}))

      assert {:error, :unauthorized} =
               Delivery.create_section(
                 request!(user, "publication:999999", %{title: "Nonexistent"})
               )

      assert section_count() == before

      forged = %SectionCreationRequest{
        actor: {:user, user.id},
        source: {:publication, publication.id},
        attrs: %{
          title: "Forged Section",
          institution_id: insert(:institution).id,
          blueprint_id: 1,
          requires_payment: true,
          amount: Money.new(:USD, 99),
          status: :archived,
          skip_email_verification: true
        },
        section_spec: spec
      }

      assert {:ok, section_id, _slug} = Delivery.create_section(forged)

      section = Sections.get_section!(section_id)
      assert section.title == "Forged Section"
      assert is_nil(section.institution_id)
      assert is_nil(section.blueprint_id)
      refute section.requires_payment
      assert is_nil(section.amount)
      assert section.status == :active
      refute section.skip_email_verification
    end

    test "T24 pins the chosen publication even when a newer one is published", %{
      project: project,
      publication: chosen
    } do
      user = insert(:user, independent_learner: true, can_create_sections: true)
      request = request!(user, "publication:#{chosen.id}", %{title: "Pinned Section"})

      newer =
        insert(:publication,
          project: project,
          published: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      assert newer.id != chosen.id

      assert {:ok, section_id, _slug} = Delivery.create_section(request)

      pins =
        Repo.all(
          from(spp in SectionsProjectsPublications,
            where: spp.section_id == ^section_id,
            select: spp.publication_id
          )
        )

      assert pins == [chosen.id]
      refute newer.id in pins
    end
  end

  describe "the source list and the gate" do
    test "T6 offers no source the gate refuses, for an author linked user (P3, N9)" do
      author = insert(:author)
      user = insert(:user, independent_learner: true, can_create_sections: true, author: author)

      author_project = insert(:project, visibility: :selected, authors: [author])
      author_publication = insert(:publication, project: author_project)

      global_project = insert(:project, visibility: :global)
      global_publication = insert(:publication, project: global_project)

      community_project = insert(:project, visibility: :selected)
      community_product = insert(:section, base_project: community_project, type: :blueprint)
      community = insert(:community, global_access: true)
      insert(:community_user_account, community: community, user: user)
      insert(:community_product_visibility, community: community, section: community_product)

      hidden_project = insert(:project, visibility: :selected)
      hidden_publication = insert(:publication, project: hidden_project)

      paid_project = insert(:project, visibility: :global)
      paid_publication = insert(:publication, project: paid_project)

      insert(:section,
        base_project: paid_project,
        type: :blueprint,
        status: :active,
        requires_payment: true
      )

      {:ok, opts} = section_with_assessment(nil)
      foreign_section = opts[:section]

      user = Repo.preload(user, :author)
      publications = SectionCreation.permitted_publications(user, nil)
      products = SectionCreation.permitted_products(user, nil)

      publication_ids = Enum.map(publications, & &1.id)
      product_ids = Enum.map(products, & &1.id)

      assert author_publication.id in publication_ids
      assert global_publication.id in publication_ids
      assert community_product.id in product_ids

      refute hidden_publication.id in publication_ids
      refute paid_publication.id in publication_ids
      refute foreign_section.id in product_ids

      refute publications == []
      refute products == []

      for publication <- publications do
        assert {:ok, {:publication, _}} =
                 SectionCreation.resolve_source(user, {:publication, publication.id}, nil)
      end

      for product <- products do
        assert {:ok, {:product, _}} =
                 SectionCreation.resolve_source(user, {:product, product.id}, nil)
      end
    end
  end

  describe "audit and enrollment" do
    setup [:publishable_source]

    test "T7 audits an admin created section with the author, and enrolls nobody", %{
      project: project,
      publication: publication
    } do
      admin = admin_author()
      product = product_from(project, publication)

      assert {:ok, section_id, _slug} =
               Delivery.create_section(
                 request!(admin, "product:#{product.id}", %{title: "Admin Audited"})
               )

      event =
        Repo.one!(
          from(event in Oli.Auditing.LogEvent,
            where: event.section_id == ^section_id and event.event_type == :section_created
          )
        )

      assert event.author_id == admin.id
      assert is_nil(event.user_id)

      assert Repo.aggregate(
               from(e in Enrollment, where: e.section_id == ^section_id),
               :count
             ) == 0
    end

    test "T7 audits a user created section with the user, and enrolls it as instructor", %{
      publication: publication
    } do
      user = insert(:user, independent_learner: true, can_create_sections: true)

      assert {:ok, section_id, _slug} =
               Delivery.create_section(
                 request!(user, "publication:#{publication.id}", %{title: "User Audited"})
               )

      event =
        Repo.one!(
          from(event in Oli.Auditing.LogEvent,
            where: event.section_id == ^section_id and event.event_type == :section_created
          )
        )

      assert event.user_id == user.id
      assert is_nil(event.author_id)

      assert [enrollment] =
               Repo.all(from(e in Enrollment, where: e.section_id == ^section_id))

      assert enrollment.user_id == user.id
    end
  end

  describe "LTI early return" do
    setup [:publishable_source]

    test "T8 returns the existing section before the source is resolved, and refuses a learner",
         %{
           project: project
         } do
      user = insert(:user, independent_learner: false, can_create_sections: false)
      context_id = unique_context_id()

      %{spec: spec, institution: institution, deployment: deployment} =
        lti_launch(user, context_id, [@instructor_role])

      existing =
        insert(:section,
          type: :enrollable,
          context_id: context_id,
          base_project: project,
          institution: institution,
          lti_1p3_deployment: deployment,
          open_and_free: false
        )

      # A source this actor may not use: its project is sold as a paid product.
      paid_project = insert(:project, visibility: :global)
      paid_publication = insert(:publication, project: paid_project)

      insert(:section,
        base_project: paid_project,
        type: :blueprint,
        status: :active,
        requires_payment: true
      )

      before = section_count()

      assert {:ok, section_id, section_slug} =
               Delivery.create_section(
                 request!(user, "publication:#{paid_publication.id}", %{title: "Retry"}, spec)
               )

      assert section_id == existing.id
      assert section_slug == existing.slug
      assert section_count() == before

      learner = insert(:user, independent_learner: false, can_create_sections: false)
      learner_context_id = unique_context_id()

      %{spec: learner_spec, institution: learner_institution, deployment: learner_deployment} =
        lti_launch(learner, learner_context_id, [@learner_role])

      # A section the early-return would hand back if it ran before the actor check.
      insert(:section,
        type: :enrollable,
        context_id: learner_context_id,
        base_project: project,
        institution: learner_institution,
        lti_1p3_deployment: learner_deployment,
        open_and_free: false
      )

      assert {:error, :unauthorized} =
               Delivery.create_section(
                 request!(
                   learner,
                   "publication:#{paid_publication.id}",
                   %{title: "Learner Retry"},
                   learner_spec
                 )
               )
    end
  end

  describe "creation contract" do
    setup [:publishable_source]

    test "T9 no longer exports the product creation bypass" do
      Code.ensure_loaded!(Oli.Delivery)
      refute function_exported?(Oli.Delivery, :create_from_product, 3)
    end

    test "T14 leaves nothing behind when a step after the section row fails", %{
      publication: publication
    } do
      # An independent learner cannot be enrolled in an LTI section, so enrollment fails
      # after the section and its resources have been written.
      user = insert(:user, independent_learner: true, can_create_sections: true)
      %{spec: spec} = lti_launch(user, unique_context_id(), [@instructor_role])

      before = section_count()

      assert {:error, _reason} =
               Delivery.create_section(
                 request!(
                   user,
                   "publication:#{publication.id}",
                   %{title: "Partial Section"},
                   spec
                 )
               )

      assert section_count() == before
      assert Repo.all(from(s in Section, where: s.title == "Partial Section")) == []

      assert Repo.aggregate(
               from(e in Enrollment, where: e.user_id == ^user.id),
               :count
             ) == 0
    end

    test "T15 a replayed request yields two complete, independent sections", %{
      publication: publication,
      section: section
    } do
      user = insert(:user, independent_learner: true, can_create_sections: true)

      assert {:ok, first_id, first_slug} =
               Delivery.create_section(
                 request!(user, "publication:#{publication.id}", %{title: "Replayed"})
               )

      assert {:ok, second_id, second_slug} =
               Delivery.create_section(
                 request!(user, "publication:#{publication.id}", %{title: "Replayed"})
               )

      assert first_id != second_id
      assert first_slug != second_slug

      source_resources = section_resource_count(section.id)
      assert source_resources > 0
      assert section_resource_count(first_id) == source_resources
      assert section_resource_count(second_id) == source_resources

      assert publication_pins(first_id) == [publication.id]
      assert publication_pins(second_id) == [publication.id]

      first = Sections.get_section!(first_id)
      second = Sections.get_section!(second_id)

      assert is_nil(first.blueprint_id)
      assert is_nil(second.blueprint_id)
    end

    test "T12 copies no learner data from the source", %{
      project: project,
      publication: publication
    } do
      product = product_from(project, publication)
      student = insert(:user, independent_learner: true)
      resource = insert(:resource)

      {:ok, _} =
        Sections.enroll(student.id, product.id, [ContextRoles.get_role(:context_learner)])

      enrollment =
        Repo.one!(
          from(e in Enrollment, where: e.section_id == ^product.id and e.user_id == ^student.id)
        )

      resource_access =
        insert(:resource_access, user: student, section: product, resource: resource)

      resource_attempt = insert(:resource_attempt, resource_access: resource_access)
      activity_attempt = insert(:activity_attempt, resource_attempt: resource_attempt)
      insert(:part_attempt, activity_attempt: activity_attempt)
      insert(:lms_grade_update, resource_access: resource_access)

      # A non-FK family: resource_summary names its section with a plain integer column.
      insert(:resource_summary,
        section_id: product.id,
        user_id: student.id,
        resource: resource,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        part_id: "1"
      )

      insert(:post, user: student, section: product, resource: resource)
      insert(:student_exception, user: student, section: product, resource: resource)
      insert(:payment, section: product, enrollment: enrollment)

      # A top-level gate (copied by contract) and a student exception hanging off it
      # (learner-owned, never copied).
      top_level_gate =
        insert(:gating_condition, user: nil, section: product, resource: resource)

      insert(:gating_condition,
        user: student,
        section: product,
        resource: resource,
        parent_id: top_level_gate.id
      )

      # The source really carries learner data in every family asserted below.
      assert learner_row_counts(product.id) == %{
               enrollments: 1,
               resource_accesses: 1,
               resource_attempts: 1,
               activity_attempts: 1,
               part_attempts: 1,
               lms_grade_updates: 1,
               posts: 1,
               student_exceptions: 1,
               student_gating_conditions: 1,
               payments: 1,
               resource_summaries: 1
             }

      source_tables = section_row_counts(product.id)

      creator = insert(:user, independent_learner: true, can_create_sections: true)

      assert {:ok, section_id, _slug} =
               Delivery.create_section(
                 request!(creator, "product:#{product.id}", %{title: "Clean Copy"})
               )

      # Only the creating instructor's own enrollment.
      assert learner_row_counts(section_id) == %{
               enrollments: 1,
               resource_accesses: 0,
               resource_attempts: 0,
               activity_attempts: 0,
               part_attempts: 0,
               lms_grade_updates: 0,
               posts: 0,
               student_exceptions: 0,
               student_gating_conditions: 0,
               payments: 0,
               resource_summaries: 0
             }

      # The top-level gate is instructor configuration and does come across, so the zero
      # above is the student exception being dropped, not the whole family missing.
      assert Repo.aggregate(
               from(gc in Oli.Delivery.Gating.GatingCondition,
                 where: gc.section_id == ^section_id and is_nil(gc.user_id)
               ),
               :count
             ) == 1

      # Every table in the schema that names a section, not a hand-written family list: a
      # copy that ever writes a row in a table not named here fails this assertion.
      counts = section_row_counts(section_id)

      assert counts |> Map.keys() |> Enum.sort() == [
               "audit_log_events",
               "contained_pages",
               "enrollments",
               "gating_conditions",
               "section_resources",
               "sections_projects_publications"
             ]

      assert counts["enrollments"] == 1
      assert counts["audit_log_events"] == 1
      assert counts["gating_conditions"] == 1
      assert counts["contained_pages"] > 0
      assert counts["section_resources"] == source_tables["section_resources"]

      assert counts["sections_projects_publications"] ==
               source_tables["sections_projects_publications"]

      assert [enrollment] = Repo.all(from(e in Enrollment, where: e.section_id == ^section_id))
      assert enrollment.user_id == creator.id

      # enrollments_context_roles names an enrollment, not a section, so the sweep cannot
      # see it: the one enrollment the copy may carry is the creator's, as instructor only.
      assert enrollment_context_role_ids(enrollment.id) == [
               ContextRoles.get_role(:context_instructor).id
             ]
    end

    @tag capture_log: true
    test "T16 rolls the creation back when the audit record cannot be written", %{
      project: project,
      publication: publication
    } do
      Application.put_env(
        :oli,
        :section_creation_auditor,
        Oli.Delivery.SectionCreationTest.FailingAuditor
      )

      on_exit(fn -> Application.delete_env(:oli, :section_creation_auditor) end)

      product = product_from(project, publication)
      user = insert(:user, independent_learner: true, can_create_sections: true)
      before = section_count()

      assert {:error, _reason} =
               Delivery.create_section(
                 request!(user, "publication:#{publication.id}", %{title: "Unaudited Publication"})
               )

      assert {:error, _reason} =
               Delivery.create_section(
                 request!(user, "product:#{product.id}", %{title: "Unaudited Product"})
               )

      assert section_count() == before

      assert Repo.all(
               from(s in Section,
                 where: s.title in ["Unaudited Publication", "Unaudited Product"]
               )
             ) == []

      assert Repo.aggregate(from(e in Enrollment, where: e.user_id == ^user.id), :count) == 0

      assert Repo.aggregate(
               from(event in Oli.Auditing.LogEvent, where: event.user_id == ^user.id),
               :count
             ) == 0
    end
  end

  describe "the authorized launch decides the destination" do
    setup [:publishable_source]

    test "T25 writes the section under the launch that was authorized, not the one supplied", %{
      publication: publication
    } do
      user = insert(:user, independent_learner: false, can_create_sections: false)

      registration =
        new_registration(line_items_service_domain: "https://canonical.example.edu")

      authorized_institution = insert(:institution)

      %{spec: authorized_spec, deployment: authorized_deployment} =
        lti_launch(user, unique_context_id(), [@instructor_role],
          registration: registration,
          institution: authorized_institution,
          ags_scopes: [
            "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem",
            "https://purl.imsglobal.org/spec/lti-ags/scope/score"
          ]
        )

      other_institution = insert(:institution)

      other_registration =
        new_registration(line_items_service_domain: "https://forged.example.edu")

      other_deployment =
        deployment_fixture(%{
          institution_id: other_institution.id,
          registration_id: other_registration.id,
          deployment_id: "other-#{System.unique_integer([:positive])}"
        })

      # Everything a caller could substitute: the destination structs and the service
      # claims the section's LMS wiring is derived from.
      forged_spec = %SectionSpecification.Lti{
        authorized_spec
        | institution: other_institution,
          registration: other_registration,
          deployment: other_deployment,
          lti_params: Map.drop(authorized_spec.lti_params, [@ags_claim, @nrps_claim])
      }

      assert {:ok, section_id, _slug} =
               Delivery.create_section(
                 request!(
                   user,
                   "publication:#{publication.id}",
                   %{title: "Forged Destination"},
                   forged_spec
                 )
               )

      section = Sections.get_section!(section_id)

      assert section.institution_id == authorized_institution.id
      assert section.lti_1p3_deployment_id == authorized_deployment.id
      refute section.institution_id == other_institution.id
      refute section.lti_1p3_deployment_id == other_deployment.id

      # The LMS service wiring comes from the authorized launch's claims and registration,
      # not from the ones the request carried.
      assert section.grade_passback_enabled
      assert section.nrps_enabled

      assert section.nrps_context_memberships_url ==
               authorized_spec.lti_params[@nrps_claim]["context_memberships_url"]

      refute is_nil(section.nrps_context_memberships_url)
      assert section.line_items_service_url =~ "canonical.example.edu"
      refute section.line_items_service_url =~ "forged.example.edu"
    end

    test "T26 does not return a section belonging to another deployment of the same registration",
         %{project: project, publication: publication} do
      registration = new_registration()
      institution = insert(:institution)
      context_id = unique_context_id()

      other_deployment =
        deployment_fixture(%{
          institution_id: institution.id,
          registration_id: registration.id,
          deployment_id: "other-#{System.unique_integer([:positive])}"
        })

      other_section =
        insert(:section,
          type: :enrollable,
          context_id: context_id,
          base_project: project,
          institution: institution,
          lti_1p3_deployment: other_deployment,
          open_and_free: false
        )

      user = insert(:user, independent_learner: false, can_create_sections: false)

      %{deployment: deployment} =
        lti_launch(user, context_id, [@instructor_role],
          registration: registration,
          institution: institution,
          deployment_id: "mine-#{System.unique_integer([:positive])}"
        )

      # The wizard's specification is rebuilt from the persisted launch, so pass the one
      # the route would have built.
      spec = SectionSpecification.lti(user, context_id)

      assert {:ok, section_id, _slug} =
               Delivery.create_section(
                 request!(user, "publication:#{publication.id}", %{title: "My Deployment"}, spec)
               )

      refute section_id == other_section.id
      assert Sections.get_section!(section_id).lti_1p3_deployment_id == deployment.id
    end

    test "T31 canonicalises an admin author's LTI specification from its own claims", %{
      publication: publication
    } do
      admin = admin_author()
      registration = new_registration()
      claimed_institution = insert(:institution)

      claimed_deployment =
        deployment_fixture(%{
          institution_id: claimed_institution.id,
          registration_id: registration.id,
          deployment_id: "claimed-#{System.unique_integer([:positive])}"
        })

      other_institution = insert(:institution)
      other_registration = new_registration()

      other_deployment =
        deployment_fixture(%{
          institution_id: other_institution.id,
          registration_id: other_registration.id,
          deployment_id: "other-#{System.unique_integer([:positive])}"
        })

      claims =
        Oli.Lti.TestHelpers.all_default_claims()
        |> put_in(["iss"], registration.issuer)
        |> put_in(["aud"], registration.client_id)
        |> put_in([@deployment_claims], claimed_deployment.deployment_id)
        |> put_in([@context_claims, "id"], unique_context_id())

      # Four identities, all different: claims from one launch, structs from another.
      inconsistent_spec = %SectionSpecification.Lti{
        lti_params: claims,
        institution: other_institution,
        registration: other_registration,
        deployment: other_deployment
      }

      assert {:ok, section_id, _slug} =
               Delivery.create_section(
                 request!(
                   admin,
                   "publication:#{publication.id}",
                   %{title: "Admin LTI Section"},
                   inconsistent_spec
                 )
               )

      section = Sections.get_section!(section_id)
      assert section.institution_id == claimed_institution.id
      assert section.lti_1p3_deployment_id == claimed_deployment.id

      # Claims that name no registered deployment are refused rather than written.
      unresolvable_spec = %SectionSpecification.Lti{
        inconsistent_spec
        | lti_params: put_in(claims, [@deployment_claims], "no-such-deployment")
      }

      before = section_count()

      assert {:error, :unauthorized} =
               Delivery.create_section(
                 request!(
                   admin,
                   "publication:#{publication.id}",
                   %{title: "Admin LTI Refused"},
                   unresolvable_spec
                 )
               )

      assert section_count() == before
    end

    test "T33 refuses an LTI specification whose identity claims are malformed", %{
      publication: publication
    } do
      admin = admin_author()
      institution = insert(:institution)
      registration = new_registration()

      deployment =
        deployment_fixture(%{
          institution_id: institution.id,
          registration_id: registration.id,
          deployment_id: "D-#{System.unique_integer([:positive])}"
        })

      well_formed =
        Oli.Lti.TestHelpers.all_default_claims()
        |> put_in(["iss"], registration.issuer)
        |> put_in(["aud"], registration.client_id)
        |> put_in([@deployment_claims], deployment.deployment_id)
        |> put_in([@context_claims, "id"], unique_context_id())

      spec = %SectionSpecification.Lti{
        lti_params: well_formed,
        institution: institution,
        registration: registration,
        deployment: deployment
      }

      # Control: the same request with well formed claims creates.
      assert {:ok, _id, _slug} =
               Delivery.create_section(
                 request!(admin, "publication:#{publication.id}", %{title: "Well Formed"}, spec)
               )

      malformed = [
        {"missing context", Map.delete(well_formed, @context_claims)},
        {"list context", Map.put(well_formed, @context_claims, [])},
        {"non binary context id", put_in(well_formed, [@context_claims, "id"], 7)},
        {"missing deployment", Map.delete(well_formed, @deployment_claims)},
        {"nil deployment", put_in(well_formed, [@deployment_claims], nil)},
        {"integer deployment", put_in(well_formed, [@deployment_claims], 123)},
        {"empty issuer", put_in(well_formed, ["iss"], "")}
      ]

      before = section_count()

      for {label, claims} <- malformed do
        assert {:error, :unauthorized} =
                 Delivery.create_section(
                   request!(
                     admin,
                     "publication:#{publication.id}",
                     %{title: "Malformed #{label}"},
                     %SectionSpecification.Lti{spec | lti_params: claims}
                   )
                 ),
               "expected a refusal for a #{label} claim"
      end

      assert section_count() == before
    end

    @tag capture_log: true
    test "T34 refuses an ambiguous deployment identity instead of raising", %{
      publication: publication
    } do
      admin = admin_author()
      institution = insert(:institution)
      registration = new_registration()
      external_id = "DUP-#{System.unique_integer([:positive])}"

      first =
        deployment_fixture(%{
          institution_id: institution.id,
          registration_id: registration.id,
          deployment_id: external_id
        })

      second =
        deployment_fixture(%{
          institution_id: institution.id,
          registration_id: registration.id,
          deployment_id: external_id
        })

      # The schema accepts the ambiguity today, so the boundary must survive it.
      assert first.id != second.id

      assert Oli.Institutions.get_institution_registration_deployment(
               registration.issuer,
               registration.client_id,
               external_id
             ) == nil

      claims =
        Oli.Lti.TestHelpers.all_default_claims()
        |> put_in(["iss"], registration.issuer)
        |> put_in(["aud"], registration.client_id)
        |> put_in([@deployment_claims], external_id)
        |> put_in([@context_claims, "id"], unique_context_id())

      spec = %SectionSpecification.Lti{
        lti_params: claims,
        institution: institution,
        registration: registration,
        deployment: first
      }

      before = section_count()

      assert {:error, :unauthorized} =
               Delivery.create_section(
                 request!(admin, "publication:#{publication.id}", %{title: "Ambiguous"}, spec)
               )

      assert section_count() == before
    end

    test "T32 an administrator acts as the author when both sessions are mounted" do
      admin = admin_author()
      plain_author = insert(:author)
      user = insert(:user)

      assert SectionCreationRequest.actor_account(admin, user) == admin
      assert SectionCreationRequest.actor_account(admin, nil) == admin
      assert SectionCreationRequest.actor_account(plain_author, user) == user
      assert SectionCreationRequest.actor_account(nil, user) == user
      assert SectionCreationRequest.actor_account(plain_author, nil) == plain_author
      assert SectionCreationRequest.actor_account(nil, nil) == nil
    end

    test "T27 refuses source ids larger than the database can hold, without raising", %{
      publication: publication
    } do
      user = insert(:user, independent_learner: true, can_create_sections: true)
      huge = String.duplicate("9", 100)

      for kind <- ["publication", "product", "section"] do
        assert {:error, :unauthorized} =
                 SectionCreationRequest.new(
                   user,
                   "#{kind}:#{huge}",
                   %{title: "Too Big"},
                   SectionSpecification.direct()
                 )
      end

      forged = %SectionCreationRequest{
        actor: {:user, user.id},
        source: {:publication, String.to_integer(huge)},
        attrs: %{title: "Too Big"},
        section_spec: SectionSpecification.direct()
      }

      before = section_count()
      assert {:error, :unauthorized} = Delivery.create_section(forged)
      assert section_count() == before

      # The same request with a real id still works, so the guard is the size, not the shape.
      assert {:ok, _id, _slug} =
               Delivery.create_section(%{forged | source: {:publication, publication.id}})
    end
  end

  defp publishable_source(_context) do
    {:ok, opts} = section_with_assessment(nil)
    section = opts[:section]
    project = Repo.get!(Project, section.base_project_id)
    publication = Publishing.get_latest_published_publication_by_slug(project.slug)

    [section: section, project: project, publication: publication]
  end

  defp request!(actor, source, attrs, section_spec \\ SectionSpecification.direct()) do
    {:ok, request} = SectionCreationRequest.new(actor, source, attrs, section_spec)
    request
  end

  defp admin_author,
    do: insert(:author, system_role_id: SystemRole.role_id().system_admin)

  defp product_from(project, publication, attrs \\ []) do
    product =
      insert(
        :section,
        Keyword.merge([base_project: project, type: :blueprint, open_and_free: false], attrs)
      )

    {:ok, product} = Sections.create_section_resources(product, publication)
    product
  end

  defp lti_launch(user, context_id, roles, opts \\ []) do
    registration = opts[:registration] || new_registration()
    institution = opts[:institution] || insert(:institution)

    deployment =
      opts[:deployment] ||
        deployment_fixture(%{
          institution_id: institution.id,
          registration_id: registration.id,
          deployment_id: opts[:deployment_id] || "1"
        })

    lti_params =
      Oli.Lti.TestHelpers.all_default_claims()
      |> put_in(["iss"], registration.issuer)
      |> put_in(["aud"], registration.client_id)
      |> put_in([@deployment_claims], deployment.deployment_id)
      |> put_in([@roles_claim], roles)
      |> put_in([@context_claims, "id"], context_id)
      |> put_ags_scopes(opts[:ags_scopes])

    cache_lti_params(lti_params, user.id)

    %{
      spec: SectionSpecification.lti(user, context_id),
      lti_params: lti_params,
      institution: institution,
      deployment: deployment,
      registration: registration
    }
  end

  defp put_ags_scopes(lti_params, nil), do: lti_params
  defp put_ags_scopes(lti_params, scopes), do: put_in(lti_params, [@ags_claim, "scope"], scopes)

  defp new_registration(attrs \\ []) do
    jwk = jwk_fixture()

    registration_fixture(
      Enum.into(attrs, %{
        tool_jwk_id: jwk.id,
        issuer: "issuer-#{System.unique_integer([:positive])}",
        client_id: "client-#{System.unique_integer([:positive])}"
      })
    )
  end

  defp unique_context_id, do: "context-#{System.unique_integer([:positive])}"

  defp section_count, do: Repo.aggregate(Section, :count)

  defp section_resource_count(section_id) do
    Repo.aggregate(
      from(sr in Oli.Delivery.Sections.SectionResource, where: sr.section_id == ^section_id),
      :count
    )
  end

  defp publication_pins(section_id) do
    Repo.all(
      from(spp in SectionsProjectsPublications,
        where: spp.section_id == ^section_id,
        select: spp.publication_id
      )
    )
  end

  defp learner_row_counts(section_id) do
    %{
      enrollments:
        Repo.aggregate(from(e in Enrollment, where: e.section_id == ^section_id), :count),
      resource_accesses: Repo.aggregate(resource_access_query(section_id), :count),
      resource_attempts: Repo.aggregate(resource_attempt_query(section_id), :count),
      activity_attempts: Repo.aggregate(activity_attempt_query(section_id), :count),
      part_attempts:
        Repo.aggregate(
          from(pa in Oli.Delivery.Attempts.Core.PartAttempt,
            join: attempt in subquery(activity_attempt_query(section_id)),
            on: pa.activity_attempt_id == attempt.id
          ),
          :count
        ),
      resource_summaries:
        Repo.aggregate(
          from(rs in Oli.Analytics.Summary.ResourceSummary,
            where: rs.section_id == ^section_id
          ),
          :count
        ),
      lms_grade_updates:
        Repo.aggregate(
          from(gu in Oli.Delivery.Attempts.Core.LMSGradeUpdate,
            join: access in subquery(resource_access_query(section_id)),
            on: gu.resource_access_id == access.id
          ),
          :count
        ),
      posts:
        Repo.aggregate(
          from(p in Oli.Resources.Collaboration.Post, where: p.section_id == ^section_id),
          :count
        ),
      student_exceptions:
        Repo.aggregate(
          from(se in Oli.Delivery.Settings.StudentException,
            where: se.section_id == ^section_id
          ),
          :count
        ),
      student_gating_conditions:
        Repo.aggregate(
          from(gc in Oli.Delivery.Gating.GatingCondition,
            where: gc.section_id == ^section_id and not is_nil(gc.user_id)
          ),
          :count
        ),
      payments:
        Repo.aggregate(
          from(p in Oli.Delivery.Paywall.Payment, where: p.section_id == ^section_id),
          :count
        )
    }
  end

  # Non-zero row counts for every table in the schema with a section_id column.
  defp section_row_counts(section_id) do
    {:ok, %{rows: tables}} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        select table_name
        from information_schema.columns
        where column_name = 'section_id' and table_schema = 'public'
        order by table_name
        """,
        []
      )

    tables
    |> Enum.map(fn [table] ->
      {:ok, %{rows: [[count]]}} =
        Ecto.Adapters.SQL.query(
          Repo,
          "select count(*) from \"#{table}\" where section_id = $1",
          [section_id]
        )

      {table, count}
    end)
    |> Enum.reject(fn {_table, count} -> count == 0 end)
    |> Map.new()
  end

  defp resource_attempt_query(section_id) do
    from(ra in Oli.Delivery.Attempts.Core.ResourceAttempt,
      join: access in subquery(resource_access_query(section_id)),
      on: ra.resource_access_id == access.id
    )
  end

  defp activity_attempt_query(section_id) do
    from(aa in Oli.Delivery.Attempts.Core.ActivityAttempt,
      join: attempt in subquery(resource_attempt_query(section_id)),
      on: aa.resource_attempt_id == attempt.id
    )
  end

  defp enrollment_context_role_ids(enrollment_id) do
    Repo.all(
      from(ecr in "enrollments_context_roles",
        where: ecr.enrollment_id == ^enrollment_id,
        select: ecr.context_role_id,
        order_by: ecr.context_role_id
      )
    )
  end

  defp resource_access_query(section_id) do
    from(ra in Oli.Delivery.Attempts.Core.ResourceAccess, where: ra.section_id == ^section_id)
  end
end
