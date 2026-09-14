defmodule Oli.DeliveryTest do
  use Oli.DataCase

  import Oli.Factory
  import Oli.TestHelpers

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery
  alias Oli.Delivery.SectionCreationRequest
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{CopyOptions, Section, SectionSpecification}
  alias Oli.Authoring.Course.Project
  alias Oli.Repo

  describe "user_research_consent_required?/2" do
    setup do
      Delivery.update_system_research_consent_form_setting(:oli_form)
      :ok
    end

    test "returns false for a nil user" do
      refute Delivery.user_research_consent_required?(nil)
    end

    test "direct delivery section with a :no_form institution does not require consent (MER-5717)" do
      institution = insert(:institution, research_consent: :no_form)

      section =
        insert(:section,
          open_and_free: true,
          institution: institution,
          lti_1p3_deployment: nil,
          lti_1p3_deployment_id: nil
        )

      user = insert(:user, independent_learner: true)

      refute Delivery.user_research_consent_required?(user, section)
    end

    test "section institution is authoritative over the global setting" do
      Delivery.update_system_research_consent_form_setting(:no_form)
      institution = insert(:institution, research_consent: :oli_form)

      section =
        insert(:section,
          open_and_free: true,
          institution: institution,
          lti_1p3_deployment: nil,
          lti_1p3_deployment_id: nil
        )

      user = insert(:user, independent_learner: true)

      assert Delivery.user_research_consent_required?(user, section)
    end

    test "direct delivery section with no institution falls back to the global setting" do
      section =
        insert(:section,
          open_and_free: true,
          institution: nil,
          lti_1p3_deployment: nil,
          lti_1p3_deployment_id: nil
        )

      user = insert(:user, independent_learner: true)

      assert Delivery.user_research_consent_required?(user, section)

      Delivery.update_system_research_consent_form_setting(:no_form)
      refute Delivery.user_research_consent_required?(user, section)
    end

    test "without a section, a direct delivery user follows the global setting" do
      user = insert(:user, independent_learner: true)

      assert Delivery.user_research_consent_required?(user)

      Delivery.update_system_research_consent_form_setting(:no_form)
      refute Delivery.user_research_consent_required?(user)
    end

    test "for_slug?: section institution setting is authoritative" do
      for {setting, required?} <- [{:oli_form, true}, {:no_form, false}] do
        institution = insert(:institution, research_consent: setting)

        section =
          insert(:section,
            open_and_free: true,
            institution: institution,
            lti_1p3_deployment: nil,
            lti_1p3_deployment_id: nil
          )

        user = insert(:user, independent_learner: true)

        assert Delivery.user_research_consent_required_for_slug?(user, section.slug) == required?
      end
    end

    test "for_slug?: section with no institution falls back to the global setting" do
      section =
        insert(:section,
          open_and_free: true,
          institution: nil,
          lti_1p3_deployment: nil,
          lti_1p3_deployment_id: nil
        )

      user = insert(:user, independent_learner: true)

      assert Delivery.user_research_consent_required_for_slug?(user, section.slug)

      Delivery.update_system_research_consent_form_setting(:no_form)
      refute Delivery.user_research_consent_required_for_slug?(user, section.slug)
    end

    test "for_slug?: returns false for a nil user" do
      institution = insert(:institution, research_consent: :oli_form)

      section =
        insert(:section,
          open_and_free: true,
          institution: institution,
          lti_1p3_deployment: nil,
          lti_1p3_deployment_id: nil
        )

      refute Delivery.user_research_consent_required_for_slug?(nil, section.slug)
    end

    test "for_slug?: unknown or nil slug falls back to the user-level policy" do
      user = insert(:user, independent_learner: true)

      assert Delivery.user_research_consent_required_for_slug?(user, "does-not-exist")
      assert Delivery.user_research_consent_required_for_slug?(user, nil)

      Delivery.update_system_research_consent_form_setting(:no_form)
      refute Delivery.user_research_consent_required_for_slug?(user, "does-not-exist")
      refute Delivery.user_research_consent_required_for_slug?(user, nil)
    end

    test "LTI section honors its institution setting" do
      for {setting, required?} <- [{:oli_form, true}, {:no_form, false}] do
        institution = insert(:institution, research_consent: setting)
        deployment = insert(:lti_deployment, institution: institution)

        section =
          insert(:section, institution: institution, lti_1p3_deployment: deployment)

        user = insert(:user, independent_learner: false)
        Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

        assert Delivery.user_research_consent_required?(user, section) == required?
      end
    end
  end

  describe "delivery settings" do
    test "maybe_update_section_contains_explorations/1 update contains_explorations field" do
      {:ok,
       project: _project,
       section: section,
       page_revision: _page_revision,
       other_revision: other_revision} = project_section_revisions(%{})

      author = insert(:author)

      assert section.contains_explorations

      Oli.Resources.update_revision(other_revision, %{purpose: :foundation, author_id: author.id})

      Delivery.maybe_update_section_contains_explorations(section)
      section_without_explorations = Oli.Delivery.Sections.get_section_by_slug(section.slug)

      refute section_without_explorations.contains_explorations
    end
  end

  describe "create_section/4" do
    ## Course Hierarchy
    #
    # Root Container --> Page 1 --> Activity X
    #                |--> Unit Container --> Module Container 1 --> Page 2 --> Activity Y
    #                |                                                     |--> Activity Z
    #                |--> Module Container 2 --> Page 3 --> Activity W
    #
    ## Objectives Hierarchy
    #
    # Page 1 --> Objective A
    # Page 2 --> Objective B
    #
    # Activity Y --> Objective C
    #           |--> SubObjective C1
    # Activity Z --> Objective D
    # Activity W --> Objective E
    #           |--> Objective F
    #
    # Note: Activity X does not have objectives
    setup do
      map = create_full_project_with_objectives()
      %{authors: [project_author | _]} = Oli.Repo.preload(map.project, :authors)

      # Publish the publication so it can be found by get_latest_published_publication_by_slug
      {:ok, _published} =
        Oli.Publishing.publish_project(map.project, "ensure published", project_author.id)

      institution = insert(:institution)
      user = insert(:user, independent_learner: false)
      jwk = jwk_fixture()
      registration = registration_fixture(%{tool_jwk_id: jwk.id})

      deployment =
        deployment_fixture(%{institution_id: institution.id, registration_id: registration.id})

      lti_params =
        Oli.Lti.TestHelpers.all_default_claims()
        |> put_in(["iss"], registration.issuer)
        |> put_in(["aud"], registration.client_id)
        |> put_in(["https://purl.imsglobal.org/spec/lti/claim/roles"], [
          "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"
        ])

      product =
        insert(:section,
          base_project: map.project,
          open_and_free: false,
          registration_open: false,
          analytics_version: :v2,
          type: :blueprint,
          title: "Product 1",
          slug: "product_1"
        )

      {:ok, product} = Sections.create_section_resources(product, map.publication)

      {:ok,
       Map.merge(map, %{
         institution: institution,
         user: user,
         lti_params: lti_params,
         deployment: deployment,
         product: product
       })}
    end

    test "returns section if it already exists", context do
      section =
        insert(:section, %{
          institution: context.institution,
          base_project: context.project,
          lti_1p3_deployment: context.deployment,
          title: "Existing Section"
        })

      # Create LTI parameters with the section's context_id
      lti_params =
        context.lti_params
        |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.context_id)

      cache_lti_params(lti_params, context.user.id)

      section_spec = SectionSpecification.lti(context.user, section.context_id)

      assert {:ok, returned_section_id, returned_section_slug} =
               Delivery.create_section(
                 request!(
                   context.user,
                   "publication:#{context.publication.id}",
                   %{title: "New Section"},
                   section_spec
                 )
               )

      # Should return the existing section
      assert returned_section_id == section.id
      assert returned_section_slug == section.slug
    end

    test "copies and pins the Project learning model for a new Section", context do
      project = set_project_learning_model(context.project, :lkt_aoa)
      context_id = "project-learning-model-#{System.unique_integer([:positive])}"

      cache_lti_params(
        put_in(
          context.lti_params,
          ["https://purl.imsglobal.org/spec/lti/claim/context", "id"],
          context_id
        ),
        context.user.id
      )

      assert {:ok, section_id, _slug} =
               Delivery.create_section(
                 request!(
                   context.user,
                   "publication:#{context.publication.id}",
                   %{title: "Project model Section"},
                   SectionSpecification.lti(context.user, context_id)
                 )
               )

      assert Sections.get_section!(section_id).learning_model_version == :lkt_aoa

      set_project_learning_model(project, :naive)
      assert Sections.get_section!(section_id).learning_model_version == :lkt_aoa
    end

    test "copies the Project onboarding fields to a new Section", context do
      welcome_title = %{
        "type" => "p",
        "children" => [
          %{
            "id" => "project-welcome-title",
            "type" => "p",
            "children" => [%{"text" => "Welcome from the project"}]
          }
        ]
      }

      description = String.duplicate("Project description", 20)

      project =
        context.project
        |> Project.changeset(%{
          description: description,
          welcome_title: welcome_title,
          encouraging_subtitle: "Project subtitle"
        })
        |> Repo.update!()

      user = insert(:user, independent_learner: true, can_create_sections: true)

      publication = Oli.Publishing.get_latest_published_publication_by_slug(project.slug)

      assert {:ok, section_id, _slug} =
               Delivery.create_section(
                 request!(
                   user,
                   "publication:#{publication.id}",
                   %{title: "Project onboarding Section"},
                   SectionSpecification.direct()
                 )
               )

      section = Sections.get_section!(section_id)
      assert section.description == description
      assert section.welcome_title == welcome_title
      assert section.encouraging_subtitle == "Project subtitle"
    end

    test "preserves trusted legacy creation with no user", context do
      changeset = Sections.change_section(%Section{title: "Admin-created Section"})

      assert {:ok, section_id, _slug} =
               Delivery.create_section(
                 changeset,
                 "project:#{context.project.id}",
                 nil,
                 SectionSpecification.direct()
               )

      section = Sections.get_section!(section_id)

      assert section.title == "Admin-created Section"
      assert Sections.list_enrollments(section.slug) == []
    end

    test "copies the blueprint model even when it differs from its base Project", context do
      product = set_section_learning_model(context.product, :lkt_aoa)
      assert context.project.learning_model_version == :naive

      context_id = "product-learning-model-#{System.unique_integer([:positive])}"

      cache_lti_params(
        put_in(
          context.lti_params,
          ["https://purl.imsglobal.org/spec/lti/claim/context", "id"],
          context_id
        ),
        context.user.id
      )

      assert {:ok, section_id, _slug} =
               Delivery.create_section(
                 request!(
                   context.user,
                   "product:#{product.id}",
                   %{title: "Product model Section"},
                   SectionSpecification.lti(context.user, context_id)
                 )
               )

      section = Sections.get_section!(section_id)
      assert section.learning_model_version == :lkt_aoa
      assert section.blueprint_id == product.id

      set_section_learning_model(product, :naive)
      assert Sections.get_section!(section_id).learning_model_version == :lkt_aoa
    end

    test "creates an independent course from a section source identifier", context do
      user =
        context.user
        |> Ecto.Changeset.change(independent_learner: true)
        |> Repo.update!()

      {:ok, source} =
        Oli.Delivery.Sections.Blueprint.duplicate(context.product, %{
          type: :enrollable,
          title: "Existing Course",
          open_and_free: true,
          blueprint_id: context.product.id
        })

      {:ok, _} =
        Sections.enroll(user.id, source.id, [
          ContextRoles.get_role(:context_instructor)
        ])

      student = insert(:user)

      {:ok, _} =
        Sections.enroll(student.id, source.id, [ContextRoles.get_role(:context_learner)])

      changeset =
        Sections.change_section(%Section{
          title: "Copied Course",
          start_date: ~U[2026-08-01 12:00:00Z],
          end_date: ~U[2026-12-01 12:00:00Z]
        })

      {:ok, copy_options} =
        CopyOptions.for_previous_section([
          :content,
          :section_settings,
          :assessment_settings,
          :ai_settings
        ])

      assert {:ok, copied_section_id, _slug} =
               Delivery.create_section(%SectionCreationRequest{
                 changeset: changeset,
                 source: "section:#{source.id}",
                 user: user,
                 section_spec: SectionSpecification.direct(),
                 copy_options: copy_options
               })

      copy = Sections.get_section!(copied_section_id)

      assert copy.id != source.id
      assert copy.base_project_id == source.base_project_id
      assert copy.blueprint_id == source.blueprint_id
      assert copy.title == "Copied Course"
      assert copy.context_id != source.context_id
      assert copy.root_section_resource_id != source.root_section_resource_id

      destination_enrollments = Sections.list_enrollments(copy.slug)
      assert Enum.map(destination_enrollments, & &1.user_id) == [user.id]

      assert Enum.any?(hd(destination_enrollments).context_roles, fn role ->
               role.id == ContextRoles.get_role(:context_instructor).id
             end)
    end

    @tag capture_log: true
    test "refuses an identityless section-copy request", context do
      {:ok, source} =
        Oli.Delivery.Sections.Blueprint.duplicate(context.product, %{
          type: :enrollable,
          title: "Existing Course",
          open_and_free: true,
          blueprint_id: context.product.id
        })

      changeset = Sections.change_section(%Section{title: "Unauthorized Copy"})

      assert {:error, _message} =
               Delivery.create_section(
                 changeset,
                 "section:#{source.id}",
                 nil,
                 SectionSpecification.direct()
               )
    end

    test "creates section with contained objectives from publication if it does not exist",
         context do
      context_id = "123"
      title = "Intro to Math"

      # Create LTI parameters with the specific context_id for this test
      lti_params =
        context.lti_params
        |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], context_id)

      cache_lti_params(lti_params, context.user.id)

      section_spec = SectionSpecification.lti(context.user, context_id)

      assert {:ok, returned_section_id, _returned_section_slug} =
               Delivery.create_section(
                 request!(
                   context.user,
                   "publication:#{context.publication.id}",
                   %{title: title},
                   section_spec
                 )
               )

      # Get the created section for verification
      returned_section = Sections.get_section!(returned_section_id)

      # Check section fields
      assert returned_section.type == :enrollable
      assert returned_section.title == title
      assert returned_section.context_id == context_id
      assert returned_section.institution_id == context.institution.id
      assert returned_section.base_project_id == context.publication.project_id
      assert returned_section.lti_1p3_deployment_id == context.deployment.id
      assert returned_section.analytics_version == :v2

      # User is enrolled as instructor
      instructors = Sections.instructors_per_section([returned_section.id])
      assert [instructor] = instructors[returned_section.id]
      assert context.user.name == instructor

      # Check contained objectives
      # Check Module Container 1 objectives
      module_container_1_objectives =
        Sections.get_section_contained_objectives(
          returned_section.id,
          context.resources.module_resource_1.id
        )

      # B is attached to the page itself; C, C1 and D are attached to inner activities
      assert length(module_container_1_objectives) == 4

      assert Enum.sort(module_container_1_objectives) ==
               Enum.sort([
                 context.resources.obj_resource_b.id,
                 context.resources.obj_resource_c.id,
                 context.resources.obj_resource_c1.id,
                 context.resources.obj_resource_d.id
               ])

      # Check Unit Container objectives
      unit_container_objectives =
        Sections.get_section_contained_objectives(
          returned_section.id,
          context.resources.unit_resource.id
        )

      # B is attached to the page itself; C, C1 and D are attached to inner activities
      assert length(unit_container_objectives) == 4

      assert Enum.sort(unit_container_objectives) ==
               Enum.sort([
                 context.resources.obj_resource_b.id,
                 context.resources.obj_resource_c.id,
                 context.resources.obj_resource_c1.id,
                 context.resources.obj_resource_d.id
               ])

      # Check Module Container 2 objectives
      module_container_2_objectives =
        Sections.get_section_contained_objectives(
          returned_section.id,
          context.resources.module_resource_2.id
        )

      # E and F are the objectives attached to the inner activities
      assert length(module_container_2_objectives) == 2

      assert Enum.sort(module_container_2_objectives) ==
               Enum.sort([
                 context.resources.obj_resource_e.id,
                 context.resources.obj_resource_f.id
               ])

      # Check Root Container objectives
      root_container_objectives =
        Sections.get_section_contained_objectives(returned_section.id, nil)

      # A and B are attached to pages; C, C1, D, E and F are attached to inner activities
      assert length(root_container_objectives) == 7

      assert Enum.sort(root_container_objectives) ==
               Enum.sort([
                 context.resources.obj_resource_a.id,
                 context.resources.obj_resource_b.id,
                 context.resources.obj_resource_c.id,
                 context.resources.obj_resource_c1.id,
                 context.resources.obj_resource_d.id,
                 context.resources.obj_resource_e.id,
                 context.resources.obj_resource_f.id
               ])
    end

    test "creates section with contained objectives from product if it does not exist", context do
      # Create LTI parameters with the product's context_id
      lti_params =
        context.lti_params
        |> put_in(
          ["https://purl.imsglobal.org/spec/lti/claim/context", "id"],
          context.product.context_id
        )

      cache_lti_params(lti_params, context.user.id)

      section_spec = SectionSpecification.lti(context.user, context.product.context_id)

      assert {:ok, returned_section_id, _returned_section_slug} =
               Delivery.create_section(
                 request!(
                   context.user,
                   "product:#{context.product.id}",
                   %{title: context.product.title},
                   section_spec
                 )
               )

      # Get the created section for verification
      returned_section = Sections.get_section!(returned_section_id)

      # Check section fields
      assert returned_section.type == :enrollable
      assert returned_section.title == context.product.title
      assert returned_section.context_id == context.product.context_id
      assert returned_section.institution_id == context.institution.id
      assert returned_section.base_project_id == context.publication.project_id
      assert returned_section.lti_1p3_deployment_id == context.deployment.id

      # User is enrolled as instructor
      instructors = Sections.instructors_per_section([returned_section.id])
      assert [instructor] = instructors[returned_section.id]
      assert context.user.name == instructor

      # Check contained objectives
      # Check Module Container 1 objectives
      module_container_1_objectives =
        Sections.get_section_contained_objectives(
          returned_section.id,
          context.resources.module_resource_1.id
        )

      # B is attached to the page itself; C, C1 and D are attached to inner activities
      assert length(module_container_1_objectives) == 4

      assert Enum.sort(module_container_1_objectives) ==
               Enum.sort([
                 context.resources.obj_resource_b.id,
                 context.resources.obj_resource_c.id,
                 context.resources.obj_resource_c1.id,
                 context.resources.obj_resource_d.id
               ])

      # Check Unit Container objectives
      unit_container_objectives =
        Sections.get_section_contained_objectives(
          returned_section.id,
          context.resources.unit_resource.id
        )

      # B is attached to the page itself; C, C1 and D are attached to inner activities
      assert length(unit_container_objectives) == 4

      assert Enum.sort(unit_container_objectives) ==
               Enum.sort([
                 context.resources.obj_resource_b.id,
                 context.resources.obj_resource_c.id,
                 context.resources.obj_resource_c1.id,
                 context.resources.obj_resource_d.id
               ])

      # Check Module Container 2 objectives
      module_container_2_objectives =
        Sections.get_section_contained_objectives(
          returned_section.id,
          context.resources.module_resource_2.id
        )

      # E and F are the objectives attached to the inner activities
      assert length(module_container_2_objectives) == 2

      assert Enum.sort(module_container_2_objectives) ==
               Enum.sort([
                 context.resources.obj_resource_e.id,
                 context.resources.obj_resource_f.id
               ])

      # Check Root Container objectives
      root_container_objectives =
        Sections.get_section_contained_objectives(returned_section.id, nil)

      # A and B are attached to pages; C, C1, D, E and F are attached to inner activities
      assert length(root_container_objectives) == 7

      assert Enum.sort(root_container_objectives) ==
               Enum.sort([
                 context.resources.obj_resource_a.id,
                 context.resources.obj_resource_b.id,
                 context.resources.obj_resource_c.id,
                 context.resources.obj_resource_c1.id,
                 context.resources.obj_resource_d.id,
                 context.resources.obj_resource_e.id,
                 context.resources.obj_resource_f.id
               ])
    end
  end

  defp set_project_learning_model(project, learning_model_version) do
    project
    |> Project.trusted_learning_model_changeset(%{
      learning_model_version: learning_model_version
    })
    |> Repo.update!()
  end

  defp set_section_learning_model(section, learning_model_version) do
    section
    |> Section.trusted_learning_model_changeset(%{
      learning_model_version: learning_model_version
    })
    |> Repo.update!()
  end

  defp request!(actor, source, attrs, section_spec) do
    {:ok, request} = SectionCreationRequest.new(actor, source, attrs, section_spec)
    request
  end
end
