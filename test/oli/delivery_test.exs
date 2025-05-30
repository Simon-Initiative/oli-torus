defmodule Oli.DeliveryTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Section, SectionSpecification}

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
    # Note: the objectives above are not considered since they are attached to the pages
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
      institution = insert(:institution)
      user = insert(:user)
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
          lti_1p3_deployment: context.deployment
        })

      changeset = Sections.change_section(%Section{})

      section_spec = SectionSpecification.lti(context.user, section.context_id)

      assert {:ok, returned_section} =
               Delivery.create_section(
                 changeset,
                 "publication:#{context.publication.id}",
                 context.user,
                 section_spec
               )

      assert returned_section.id == section.id
    end

    test "creates section with contained objectives from publication if it does not exist",
         context do
      context_id = "123"
      title = "Intro to Math"

      changeset = Sections.change_section(%Section{title: title})

      section_spec = SectionSpecification.lti(context.user, context_id)

      assert {:ok, returned_section} =
               Delivery.create_section(
                 changeset,
                 "publication:#{context.publication.id}",
                 context.user,
                 section_spec
               )

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

      # C, C1 and D are the objectives attached to the inner activities
      assert length(module_container_1_objectives) == 3

      assert Enum.sort(module_container_1_objectives) ==
               Enum.sort([
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

      # C, C1 and D are the objectives attached to the inner activities
      assert length(unit_container_objectives) == 3

      assert Enum.sort(unit_container_objectives) ==
               Enum.sort([
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

      # C, C1, D, E and F are the objectives attached to the inner activities
      assert length(root_container_objectives) == 5

      assert Enum.sort(root_container_objectives) ==
               Enum.sort([
                 context.resources.obj_resource_c.id,
                 context.resources.obj_resource_c1.id,
                 context.resources.obj_resource_d.id,
                 context.resources.obj_resource_e.id,
                 context.resources.obj_resource_f.id
               ])
    end

    test "creates section with contained objectives from product if it does not exist", context do
      changeset = Sections.change_section(%Section{title: context.product.title})

      section_spec = SectionSpecification.lti(context.user, context.product.context_id)

      assert {:ok, returned_section} =
               Delivery.create_section(
                 changeset,
                 "publication:#{context.publication.id}",
                 context.user,
                 section_spec
               )

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

      # C, C1 and D are the objectives attached to the inner activities
      assert length(module_container_1_objectives) == 3

      assert Enum.sort(module_container_1_objectives) ==
               Enum.sort([
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

      # C, C1 and D are the objectives attached to the inner activities
      assert length(unit_container_objectives) == 3

      assert Enum.sort(unit_container_objectives) ==
               Enum.sort([
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

      # C, C1, D, E and F are the objectives attached to the inner activities
      assert length(root_container_objectives) == 5

      assert Enum.sort(root_container_objectives) ==
               Enum.sort([
                 context.resources.obj_resource_c.id,
                 context.resources.obj_resource_c1.id,
                 context.resources.obj_resource_d.id,
                 context.resources.obj_resource_e.id,
                 context.resources.obj_resource_f.id
               ])
    end
  end
end
