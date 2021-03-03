defmodule Oli.SectionsTest do
  use Oli.DataCase

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Authoring.Course.Project
  alias Oli.Publishing.Publication
  alias Lti_1p3.Tool.ContextRoles

  describe "enrollments" do
    @valid_attrs %{end_date: ~D[2010-04-17], open_and_free: true, registration_open: true, start_date: ~D[2010-04-17], time_zone: "some time_zone", title: "some title", context_id: "context_id"}

    setup do
      map = Seeder.base_project_with_resource2()

      institution = Map.get(map, :institution)
      project = Map.get(map, :project)
      publication = Map.get(map, :publication)

      valid_attrs = Map.put(@valid_attrs, :institution_id, institution.id)
        |> Map.put(:project_id, project.id)
        |> Map.put(:publication_id, publication.id)

      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()

      {:ok, section} = valid_attrs |> Sections.create_section()

      {:ok, Map.merge(map, %{section: section, user1: user1, user2: user2, user3: user3})}

    end

    test "list_enrollments/1 returns valid enrollments", %{section: section, user1: user1, user2: user2, user3: user3} do

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

      assert ContextRoles.has_role?(user1, section.slug, ContextRoles.get_role(:context_instructor))
      assert ContextRoles.has_role?(user2, section.slug, ContextRoles.get_role(:context_learner))
      assert ContextRoles.has_role?(user3, section.slug, ContextRoles.get_role(:context_learner))

    end

    test "enroll/3 upserts correctly", %{section: section, user1: user1} do

      assert Sections.list_enrollments(section.slug) == []

      # Enroll a user as instructor
      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_instructor)])
      assert ContextRoles.has_role?(user1, section.slug, ContextRoles.get_role(:context_instructor))

      # Now enroll again as same role, this should be idempotent
      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_instructor)])
      assert ContextRoles.has_role?(user1, section.slug, ContextRoles.get_role(:context_instructor))

      # Now enroll again with different role, this should update the role
      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_learner)])
      assert ContextRoles.has_role?(user1, section.slug, ContextRoles.get_role(:context_learner))


    end

  end

  describe "sections" do
    @valid_attrs %{end_date: ~D[2010-04-17], open_and_free: true, registration_open: true, start_date: ~D[2010-04-17], time_zone: "some time_zone", title: "some title", context_id: "some context_id"}
    @update_attrs %{end_date: ~D[2011-05-18], open_and_free: false, registration_open: false, start_date: ~D[2011-05-18], time_zone: "some updated time_zone", title: "some updated title", context_id: "some updated context_id"}
    @invalid_attrs %{end_date: nil, open_and_free: nil, registration_open: nil, start_date: nil, time_zone: nil, title: nil, context_id: nil}

    setup do

      map = Seeder.base_project_with_resource2()

      institution = Map.get(map, :institution)
      project = Map.get(map, :project)
      publication = Map.get(map, :publication)


      valid_attrs = Map.put(@valid_attrs, :institution_id, institution.id)
        |> Map.put(:project_id, project.id)
        |> Map.put(:publication_id, publication.id)

      {:ok, section} = valid_attrs |> Sections.create_section()

      {:ok, Map.merge(map, %{section: section, institution: institution, valid_attrs: valid_attrs})}
    end


    test "create_section/1 with valid data creates a section", %{valid_attrs: valid_attrs} do
      assert {:ok, %Section{} = section} = Sections.create_section(valid_attrs)
      assert section.end_date == ~D[2010-04-17]
      assert section.registration_open == true
      assert section.start_date == ~D[2010-04-17]
      assert section.time_zone == "some time_zone"
      assert section.title == "some title"
    end

    test "list_sections/0 returns all sections", %{section: section} do
      assert Sections.list_sections() == [section]
    end

    test "get_section!/1 returns the section with given id", %{section: section} do
      assert Sections.get_section!(section.id) == section
    end

    test "get_section_by!/1 returns the section and preloaded associations using the criteria", %{section: section} do
      found_section = Sections.get_section_by(slug: section.slug)
      assert found_section.id == section.id
      {%Project{} = _project} = {found_section.project}
      {%Publication{} = _publication} = {found_section.publication}
    end

    test "get_section_from_lti_params/1 returns the section from the given lti params", %{section: section, institution: institution} do
      jwk = jwk_fixture()
      registration = registration_fixture(%{institution_id: institution.id, tool_jwk_id: jwk.id})
      deployment = deployment_fixture(%{registration_id: registration.id})
      {:ok, section} = Sections.update_section(section, %{lti_1p3_deployment_id: deployment.id})

      lti_params = Oli.Lti_1p3.TestHelpers.all_default_claims()
        |> put_in(["iss"], registration.issuer)
        |> put_in(["aud"], registration.client_id)
        |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.context_id)

      assert Sections.get_section_from_lti_params(lti_params) == section
    end

    test "create_section/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sections.create_section(@invalid_attrs)
    end

    test "update_section/2 with valid data updates the section", %{section: section}  do

      assert {:ok, %Section{} = section} = Sections.update_section(section, @update_attrs)
      assert section.end_date == ~D[2011-05-18]
      assert section.registration_open == false
      assert section.start_date == ~D[2011-05-18]
      assert section.time_zone == "some updated time_zone"
      assert section.title == "some updated title"
    end

    test "update_section/2 with invalid data returns error changeset", %{section: section} do
      assert {:error, %Ecto.Changeset{}} = Sections.update_section(section, @invalid_attrs)
      assert section == Sections.get_section!(section.id)
    end

    test "delete_section/1 deletes the section", %{section: section} do
      assert {:ok, %Section{}} = Sections.delete_section(section)
      assert_raise Ecto.NoResultsError, fn -> Sections.get_section!(section.id) end
    end

    test "change_section/1 returns a section changeset", %{section: section} do
      assert %Ecto.Changeset{} = Sections.change_section(section)
    end
  end
end
