defmodule Oli.SectionsTest do
  use Oli.DataCase

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionResource
  alias Lti_1p3.Tool.ContextRoles

  describe "enrollments" do
    @valid_attrs %{
      end_date: ~U[2010-04-17 00:00:00.000000Z],
      open_and_free: true,
      registration_open: true,
      start_date: ~U[2010-04-17 00:00:00.000000Z],
      timezone: "some timezone",
      title: "some title",
      context_id: "context_id"
    }

    setup do
      map = Seeder.base_project_with_resource2()

      institution = Map.get(map, :institution)
      project = Map.get(map, :project)

      valid_attrs =
        Map.put(@valid_attrs, :institution_id, institution.id)
        |> Map.put(:base_project_id, project.id)

      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()

      {:ok, section} = valid_attrs |> Sections.create_section()

      {:ok, Map.merge(map, %{section: section, user1: user1, user2: user2, user3: user3})}
    end

    test "list_enrollments/1 returns valid enrollments", %{
      section: section,
      user1: user1,
      user2: user2,
      user3: user3
    } do
      assert Sections.list_enrollments(section.slug) == []

      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user2.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user3.id, section.id, [ContextRoles.get_role(:context_learner)])

      assert length(Sections.list_enrollments(section.slug)) == 3

      [one, two, three] = Sections.list_enrollments(section.slug)

      assert one.user_id == user1.id
      assert two.user_id == user2.id
      assert three.user_id == user3.id

      assert one.section_id == section.id
      assert two.section_id == section.id
      assert three.section_id == section.id

      assert ContextRoles.has_role?(
               user1,
               section.slug,
               ContextRoles.get_role(:context_instructor)
             )

      assert ContextRoles.has_role?(user2, section.slug, ContextRoles.get_role(:context_learner))
      assert ContextRoles.has_role?(user3, section.slug, ContextRoles.get_role(:context_learner))
    end

    test "enroll/3 upserts correctly", %{section: section, user1: user1} do
      assert Sections.list_enrollments(section.slug) == []

      # Enroll a user as instructor
      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_instructor)])

      assert ContextRoles.has_role?(
               user1,
               section.slug,
               ContextRoles.get_role(:context_instructor)
             )

      # Now enroll again as same role, this should be idempotent
      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_instructor)])

      assert ContextRoles.has_role?(
               user1,
               section.slug,
               ContextRoles.get_role(:context_instructor)
             )

      # Now enroll again with different role, this should update the role
      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_learner)])
      assert ContextRoles.has_role?(user1, section.slug, ContextRoles.get_role(:context_learner))
    end
  end

  describe "sections" do
    @valid_attrs %{
      end_date: ~U[2010-04-17 00:00:00.000000Z],
      open_and_free: true,
      registration_open: true,
      start_date: ~U[2010-04-17 00:00:00.000000Z],
      timezone: "some timezone",
      title: "some title",
      context_id: "some context_id"
    }
    @update_attrs %{
      end_date: ~U[2011-05-18 00:00:00.000000Z],
      open_and_free: false,
      registration_open: false,
      start_date: ~U[2011-05-18 00:00:00.000000Z],
      timezone: "some updated timezone",
      title: "some updated title",
      context_id: "some updated context_id"
    }
    @invalid_attrs %{
      end_date: nil,
      open_and_free: nil,
      registration_open: nil,
      start_date: nil,
      timezone: nil,
      title: nil,
      context_id: nil
    }

    setup do
      map = Seeder.base_project_with_resource2()

      institution = Map.get(map, :institution)
      project = Map.get(map, :project)
      publication = Map.get(map, :publication)

      valid_attrs =
        Map.put(@valid_attrs, :institution_id, institution.id)
        |> Map.put(:base_project_id, project.id)

      {:ok, section} = valid_attrs |> Sections.create_section()

      {:ok, section} = Sections.create_section_resources(section, publication)

      {:ok,
       Map.merge(map, %{section: section, institution: institution, valid_attrs: valid_attrs})}
    end

    test "create_section/1 with valid data creates a section", %{valid_attrs: valid_attrs} do
      assert {:ok, %Section{} = section} = Sections.create_section(valid_attrs)
      assert section.end_date == ~U[2010-04-17 00:00:00Z]
      assert section.registration_open == true
      assert section.start_date == ~U[2010-04-17 00:00:00Z]
      assert section.timezone == "some timezone"
      assert section.title == "some title"
    end

    test "list_sections/0 returns all sections", %{section: section} do
      assert Enum.map(Sections.list_sections(), & &1.id) == [section.id]
    end

    test "get_section!/1 returns the section with given id", %{section: section} do
      assert Sections.get_section!(section.id).id == section.id
    end

    test "get_section_by!/1 returns the section and preloaded associations using the criteria", %{
      section: section
    } do
      found_section = Sections.get_section_by(slug: section.slug)
      assert found_section.id == section.id
    end

    test "get_sections_by_publication/1 returns the sections which use the specified publication",
         %{
           section: section,
           publication: publication
         } do
      assert [section.id] ==
               Sections.get_sections_by_publication(publication) |> Enum.map(& &1.id)
    end

    test "get_section_from_lti_params/1 returns the section from the given lti params", %{
      section: section,
      institution: institution
    } do
      jwk = jwk_fixture()
      registration = registration_fixture(%{institution_id: institution.id, tool_jwk_id: jwk.id})
      deployment = deployment_fixture(%{registration_id: registration.id})
      {:ok, section} = Sections.update_section(section, %{lti_1p3_deployment_id: deployment.id})

      lti_params =
        Oli.Lti_1p3.TestHelpers.all_default_claims()
        |> put_in(["iss"], registration.issuer)
        |> put_in(["aud"], registration.client_id)
        |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.context_id)

      assert Sections.get_section_from_lti_params(lti_params).id == section.id
    end

    test "create_section/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sections.create_section(@invalid_attrs)
    end

    test "update_section/2 with valid data updates the section", %{section: section} do
      assert {:ok, %Section{} = section} = Sections.update_section(section, @update_attrs)
      assert section.end_date == ~U[2011-05-18 00:00:00Z]
      assert section.registration_open == false
      assert section.start_date == ~U[2011-05-18 00:00:00Z]
      assert section.timezone == "some updated timezone"
      assert section.title == "some updated title"
    end

    test "update_section/2 with invalid data returns error changeset", %{section: section} do
      assert {:error, %Ecto.Changeset{}} = Sections.update_section(section, @invalid_attrs)
      assert section.id == Sections.get_section!(section.id).id
    end

    test "soft_delete_section/1 marks the section as deleted", %{section: section} do
      assert {:ok, %Section{}} = Sections.soft_delete_section(section)
      assert Sections.get_section!(section.id).status == :deleted
    end

    test "change_section/1 returns a section changeset", %{section: section} do
      assert %Ecto.Changeset{} = Sections.change_section(section)
    end
  end

  describe "section resources" do
    setup do
      Seeder.base_project_with_resource4()
    end

    test "create_section_resources/1 creates a hierarchy of section resources", %{
      section_1: section,
      container: %{resource: root_resource},
      unit1_container: %{resource: unit1_resource},
      page1: page1,
      page2: page2,
      nested_page1: nested_page1,
      nested_page2: nested_page2,
      child1: %{resource: child1},
      parent2: %{resource: parent2},
      latest4: latest4,
      parent4: %{resource: parent4}
    } do
      section_resources =
        from(sr in SectionResource,
          as: :sr,
          join: s in Section,
          as: :s,
          on: s.id == sr.section_id,
          where: s.slug == ^section.slug,
          select: sr
        )
        |> Repo.all()

      assert Enum.count(section_resources) == 12

      root_sr = Enum.find(section_resources, &(&1.resource_id == root_resource.id))
      assert root_sr.numbering_index == 1
      assert root_sr.numbering_level == 0

      page1_sr = Enum.find(section_resources, &(&1.resource_id == page1.id))
      assert page1_sr.numbering_index == 1
      assert page1_sr.numbering_level == 1

      page2_sr = Enum.find(section_resources, &(&1.resource_id == page2.id))
      assert page2_sr.numbering_index == 2
      assert page2_sr.numbering_level == 1

      unit1_resource_sr = Enum.find(section_resources, &(&1.resource_id == unit1_resource.id))
      assert unit1_resource_sr.numbering_index == 3
      assert unit1_resource_sr.numbering_level == 1

      nested_page1_sr = Enum.find(section_resources, &(&1.resource_id == nested_page1.id))
      assert nested_page1_sr.numbering_index == 1
      assert nested_page1_sr.numbering_level == 2

      nested_page2_sr = Enum.find(section_resources, &(&1.resource_id == nested_page2.id))
      assert nested_page2_sr.numbering_index == 2
      assert nested_page2_sr.numbering_level == 2

      # objectives and other non-structural items are not numbered
      child1_sr = Enum.find(section_resources, &(&1.resource_id == child1.id))
      assert child1_sr.numbering_index == nil
      assert child1_sr.numbering_level == nil

      parent2_sr = Enum.find(section_resources, &(&1.resource_id == parent2.id))
      assert parent2_sr.numbering_index == nil
      assert parent2_sr.numbering_level == nil

      # unpublished items do not have section resources created for them
      assert Enum.find(section_resources, &(&1.resource_id == latest4.id)) == nil
      assert Enum.find(section_resources, &(&1.resource_id == parent4.id)) == nil
    end
  end
end
