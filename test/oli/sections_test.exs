defmodule Oli.SectionsTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  import Oli.Factory
  import Oli.Utils.Seeder.Utils

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionResource
  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Publishing
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Transfer
  alias Oli.Resources.ResourceType
  alias Oli.Publishing.DeliveryResolver

  describe "get_resources_scheduled_dates_for_student/2" do
    # SE: Student exception
    # GCwS: Hard scheduled dates for student
    # GCnS: Hard scheduled dates
    # SR: Soft scheduled_dates
    # Arrow pointing down indicates the dominant datetime per resource
    #      res_1 res_2 res_3 res_4 res_5 res_6 res_7
    #                          ↓                 ↓
    # SE                 ↓   04/08         ↓   04/21
    # GCwS         ↓   03/17 03/18   ↓   03/20
    # GCnS   ↓   02/16 02/17 03/18 02/19
    # SR   01/15 01/16 01/17 01/18 01/19 01/20 01/21
    test "returns correct datetime/type order" do
      sec = insert(:section, slug: "section_slug")

      %{project: proj} =
        insert(:publication, project: insert(:project, authors: [insert(:author)]))

      [res_1, res_2, res_3, res_4, res_5, res_6, res_7] = res_list = insert_list(7, :resource)

      res_ids_end_dates = [
        {res_1.id, ~U[2000-01-15 12:00:00Z]},
        {res_2.id, ~U[2000-01-16 12:00:00Z]},
        {res_3.id, ~U[2000-01-17 12:00:00Z]},
        {res_4.id, ~U[2000-01-18 12:00:00Z]},
        {res_5.id, ~U[2000-01-19 12:00:00Z]},
        {res_6.id, ~U[2000-01-20 12:00:00Z]},
        {res_7.id, ~U[2000-01-21 12:00:00Z]}
      ]

      Enum.each(res_ids_end_dates, fn {res_id, dt} ->
        insert(:section_resource, section: sec, resource_id: res_id, project: proj, end_date: dt)
      end)

      dt = %{start_datetime: ~U[2000-01-01 12:00:00Z], end_datetime: ~U[2000-01-01 12:00:00Z]}
      data = Map.put(dt, :end_datetime, ~U[2000-02-16 12:00:00Z])
      _gc = insert(:gating_condition, user: nil, section: sec, resource: res_2, data: data)
      data = Map.put(dt, :end_datetime, ~U[2000-02-17 12:00:00Z])
      _gc = insert(:gating_condition, user: nil, section: sec, resource: res_3, data: data)
      data = Map.put(dt, :end_datetime, ~U[2000-02-18 12:00:00Z])
      _gc = insert(:gating_condition, user: nil, section: sec, resource: res_4, data: data)

      user = insert(:user)
      data = Map.put(dt, :end_datetime, ~U[2000-03-17 12:00:00Z])
      _gc = insert(:gating_condition, user: user, section: sec, resource: res_3, data: data)
      data = Map.put(dt, :end_datetime, ~U[2000-03-18 12:00:00Z])
      _gc = insert(:gating_condition, user: user, section: sec, resource: res_4, data: data)

      se_dt = ~U[2000-04-18 12:00:00Z]
      _se = insert(:student_exception, user: user, section: sec, resource: res_4, end_date: se_dt)

      data = Map.put(dt, :end_datetime, ~U[2000-02-19 12:00:00Z])
      _gc = insert(:gating_condition, user: nil, section: sec, resource: res_5, data: data)
      data = Map.put(dt, :end_datetime, ~U[2000-03-20 12:00:00Z])
      _gc = insert(:gating_condition, user: user, section: sec, resource: res_6, data: data)
      se_dt = ~U[2000-04-21 12:00:00Z]

      _se =
        insert(:student_exception, user: user, section: sec, resource: res_7, end_date: se_dt)

      [res_1_id, res_2_id, res_3_id, res_4_id, res_5_id, res_6_id, res_7_id] =
        Enum.map(res_list, & &1.id)

      assert %{
               ^res_1_id => %{end_date: ~U[2000-01-15 12:00:00Z], scheduled_type: :read_by},
               ^res_2_id => %{end_date: ~U[2000-02-16 12:00:00Z], scheduled_type: :schedule},
               ^res_3_id => %{end_date: ~U[2000-03-17 12:00:00Z], scheduled_type: :schedule},
               ^res_4_id => %{end_date: ~U[2000-04-18 12:00:00Z], scheduled_type: :read_by},
               ^res_5_id => %{end_date: ~U[2000-02-19 12:00:00Z], scheduled_type: :schedule},
               ^res_6_id => %{end_date: ~U[2000-03-20 12:00:00Z], scheduled_type: :schedule},
               ^res_7_id => %{end_date: ~U[2000-04-21 12:00:00Z], scheduled_type: :read_by}
             } =
               Sections.get_resources_scheduled_dates_for_student(sec.slug, user.id)
    end
  end

  describe "enrollments" do
    @valid_attrs %{
      end_date: ~U[2010-04-17 00:00:00.000000Z],
      open_and_free: true,
      registration_open: true,
      start_date: ~U[2010-04-17 00:00:00.000000Z],
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

      enrollments = Sections.list_enrollments(section.slug)

      assert enrollments |> Enum.map(& &1.user_id) |> Enum.sort() ==
               [user1, user2, user3] |> Enum.map(& &1.id) |> Enum.sort()

      assert enrollments |> Enum.map(& &1.section_id) |> Enum.uniq() == [section.id]

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

    test "enroll/3 upserts correctly for multiple users", %{
      section: section,
      user1: user1,
      user2: user2
    } do
      assert Sections.list_enrollments(section.slug) == []

      # Enroll a user as instructor
      Sections.enroll([user1.id, user2.id], section.id, [
        ContextRoles.get_role(:context_instructor)
      ])

      assert ContextRoles.has_role?(
               user1,
               section.slug,
               ContextRoles.get_role(:context_instructor)
             )

      assert ContextRoles.has_role?(
               user2,
               section.slug,
               ContextRoles.get_role(:context_instructor)
             )

      # Now enroll again as same role, this should be idempotent
      Sections.enroll([user1.id, user2.id], section.id, [
        ContextRoles.get_role(:context_instructor)
      ])

      assert ContextRoles.has_role?(
               user1,
               section.slug,
               ContextRoles.get_role(:context_instructor)
             )

      assert ContextRoles.has_role?(
               user2,
               section.slug,
               ContextRoles.get_role(:context_instructor)
             )

      # Now enroll again with different role, this should update the role
      Sections.enroll([user1.id, user2.id], section.id, [ContextRoles.get_role(:context_learner)])
      assert ContextRoles.has_role?(user1, section.slug, ContextRoles.get_role(:context_learner))
      assert ContextRoles.has_role?(user2, section.slug, ContextRoles.get_role(:context_learner))
    end

    test "unenroll/3 removes context roles", %{section: section, user1: user1} do
      Sections.enroll(user1.id, section.id, [
        ContextRoles.get_role(:context_instructor),
        ContextRoles.get_role(:context_learner)
      ])

      Sections.unenroll(user1.id, section.id, [ContextRoles.get_role(:context_instructor)])

      refute ContextRoles.has_role?(
               user1,
               section.slug,
               ContextRoles.get_role(:context_instructor)
             )

      assert ContextRoles.has_role?(
               user1,
               section.slug,
               ContextRoles.get_role(:context_learner)
             )

      # unenroll does not remove the enrollment if there are remaining
      # context roles
      assert length(Sections.list_enrollments(section.slug)) > 0
    end

    test "unenroll/3 soft delete an enrollment if all context roles are removed", %{
      section: section,
      user1: user1
    } do
      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_instructor)])

      Sections.unenroll(user1.id, section.id, [ContextRoles.get_role(:context_instructor)])

      assert Sections.list_enrollments(section.slug) == []
    end

    test "unenroll_learner/2 soft delete an enrollment if the user is only a student", %{
      section: section,
      user1: user1
    } do
      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_learner)])

      Sections.unenroll_learner(user1.id, section.id)

      assert Sections.list_enrollments(section.slug) == []
    end

    test "unenroll/3 changes enrollment status if all context roles are removed", %{
      section: section,
      user1: user1
    } do
      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_instructor)])

      Sections.unenroll(user1.id, section.id, [ContextRoles.get_role(:context_instructor)])

      [head | _] = Sections.enrolled_students(section.slug)

      assert head.enrollment_status == :suspended
    end

    test "unenroll_learner/2 changes enrollment status if the user is only a student", %{
      section: section,
      user1: user1
    } do
      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_learner)])

      Sections.unenroll_learner(user1.id, section.id)

      [head | _] = Sections.enrolled_students(section.slug)

      assert head.enrollment_status == :suspended
    end
  end

  describe "sections" do
    @valid_attrs %{
      end_date: ~U[2010-04-17 00:00:00.000000Z],
      open_and_free: true,
      registration_open: true,
      start_date: ~U[2010-04-17 00:00:00.000000Z],
      title: "some title",
      context_id: "some context_id"
    }
    @update_attrs %{
      end_date: ~U[2011-05-18 00:00:00.000000Z],
      open_and_free: false,
      registration_open: false,
      start_date: ~U[2011-05-18 00:00:00.000000Z],
      title: "some updated title",
      context_id: "some updated context_id"
    }
    @invalid_attrs %{
      end_date: nil,
      open_and_free: nil,
      registration_open: nil,
      start_date: nil,
      title: nil,
      context_id: nil
    }

    @invalid_title %{
      end_date: ~U[2011-05-18 00:00:00.000000Z],
      open_and_free: false,
      registration_open: false,
      start_date: ~U[2011-05-18 00:00:00.000000Z],
      title:
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
      context_id: "some updated context_id"
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

    test "create_section/1 with valid data creates a section", %{section: section} do
      assert section.end_date == ~U[2010-04-17 00:00:00Z]
      assert section.registration_open == true
      assert section.start_date == ~U[2010-04-17 00:00:00Z]
      assert section.title == "some title"
      refute section.pay_by_institution
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
      registration = registration_fixture(%{tool_jwk_id: jwk.id})

      deployment =
        deployment_fixture(%{institution_id: institution.id, registration_id: registration.id})

      {:ok, section} = Sections.update_section(section, %{lti_1p3_deployment_id: deployment.id})

      lti_params =
        Oli.Lti.TestHelpers.all_default_claims()
        |> put_in(["iss"], registration.issuer)
        |> put_in(["aud"], registration.client_id)
        |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.context_id)

      assert Sections.get_section_from_lti_params(lti_params).id == section.id
    end

    test "get_section_from_lti_params/1 returns the section from the given lti params when aud claim is a list",
         %{
           section: section,
           institution: institution
         } do
      jwk = jwk_fixture()
      registration = registration_fixture(%{tool_jwk_id: jwk.id})

      deployment =
        deployment_fixture(%{institution_id: institution.id, registration_id: registration.id})

      {:ok, section} = Sections.update_section(section, %{lti_1p3_deployment_id: deployment.id})

      lti_params =
        Oli.Lti.TestHelpers.all_default_claims()
        |> put_in(["iss"], registration.issuer)
        |> put_in(["aud"], [registration.client_id])
        |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.context_id)

      assert Sections.get_section_from_lti_params(lti_params).id == section.id
    end

    test "create_section/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sections.create_section(@invalid_attrs)
    end

    test "create_section/1 with long title returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sections.create_section(@invalid_title)
    end

    test "update_section/2 with valid data updates the section", %{section: section} do
      assert {:ok, %Section{} = section} = Sections.update_section(section, @update_attrs)
      assert section.end_date == ~U[2011-05-18 00:00:00Z]
      assert section.registration_open == false
      assert section.start_date == ~U[2011-05-18 00:00:00Z]
      assert section.title == "some updated title"
    end

    test "update_section/2 with long title returns error changeset", %{section: section} do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Sections.update_section(section, @invalid_title)

      {error_message, opts} = changeset.errors[:title]

      assert error_message == "should be at most %{count} character(s)"
      assert opts[:count] == 255
    end

    test "update_section/2 with invalid data returns error changeset", %{section: section} do
      assert {:error, %Ecto.Changeset{}} = Sections.update_section(section, @invalid_attrs)
      assert section.id == Sections.get_section!(section.id).id
    end

    test "soft_delete_section/1 marks the section as deleted", %{section: section} do
      assert {:ok, %Section{}} = Sections.soft_delete_section(section)
      assert Sections.get_section!(section.id).status == :deleted
    end

    test "delete_section/1 deletes the section", %{section: section} do
      assert {:ok, %Section{}} = Sections.delete_section(section)
      refute Sections.get_section_by_slug(section.slug)
    end

    test "change_section/1 returns a section changeset", %{section: section} do
      assert %Ecto.Changeset{} = Sections.change_section(section)
    end

    test "has_student_data?/1 returns false when section has no data", %{section: section} do
      refute Sections.has_student_data?(section.slug)
    end

    test "get_remixed_projects/2 returns a list of remixed projects for a section", %{
      section: section
    } do
      remixed_projects = Sections.get_remixed_projects(section.id, section.base_project_id)
      assert 0 = length(remixed_projects)

      insert(:section_project_publication, %{section: section})
      insert(:section_project_publication, %{section: section})

      remixed_projects = Sections.get_remixed_projects(section.id, section.base_project_id)
      assert 2 = length(remixed_projects)
    end

    test "get_active_sections_by_project/1 returns course sections actives for a project" do
      %{publication: publication, project: project, unit_one_revision: _unit_one_revision} =
        base_project_with_curriculum(%{})

      section1 =
        insert(:section,
          base_project: project,
          type: :enrollable,
          start_date: yesterday(),
          end_date: tomorrow()
        )

      section2 =
        insert(:section,
          base_project: project,
          type: :enrollable,
          start_date: yesterday(),
          end_date: tomorrow()
        )

      {:ok, _sr} = Sections.create_section_resources(section1, publication)
      {:ok, _sr} = Sections.create_section_resources(section2, publication)

      assert project.id
             |> Sections.get_active_sections_by_project()
             |> length == 2
    end

    test "get_active_sections_by_project/1 does not return active course sections for a project" do
      %{publication: _publication, project: project, unit_one_revision: _unit_one_revision} =
        base_project_with_curriculum(%{})

      assert project.id
             |> Sections.get_active_sections_by_project()
             |> length == 0
    end

    test "get_push_force_affected_sections/2 returns all sections that will be affected by forcing the publication update" do
      %{publication: publication, project: project, unit_one_revision: _unit_one_revision} =
        base_project_with_curriculum(%{})

      section1 =
        insert(:section,
          base_project: project,
          type: :enrollable,
          start_date: yesterday(),
          end_date: tomorrow()
        )

      section2 =
        insert(:section,
          base_project: project,
          type: :enrollable,
          start_date: yesterday(),
          end_date: tomorrow()
        )

      product1 = insert(:section, base_project: project)

      {:ok, _sr} = Sections.create_section_resources(section1, publication)
      {:ok, _sr} = Sections.create_section_resources(section2, publication)
      {:ok, _sr} = Sections.create_section_resources(product1, publication)

      %{product_count: product_count, section_count: section_count} =
        Sections.get_push_force_affected_sections(project.id, publication.id)

      assert section_count == 2
      assert product_count == 1
    end

    test "get_push_force_affected_sections/2 does not return sections or products that will be affected by forcing the publication update" do
      %{publication: publication, project: project, unit_one_revision: _unit_one_revision} =
        base_project_with_curriculum(%{})

      %{product_count: product_count, section_count: section_count} =
        Sections.get_push_force_affected_sections(project.id, publication.id)

      assert section_count == 0
      assert product_count == 0
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
      assert unit1_resource_sr.numbering_index == 1
      assert unit1_resource_sr.numbering_level == 1

      nested_page1_sr = Enum.find(section_resources, &(&1.resource_id == nested_page1.id))
      assert nested_page1_sr.numbering_index == 3
      assert nested_page1_sr.numbering_level == 2

      nested_page2_sr = Enum.find(section_resources, &(&1.resource_id == nested_page2.id))
      assert nested_page2_sr.numbering_index == 4
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

    test "get_existing_slugs/1 returns an empty list when passing no slugs" do
      assert Sections.get_existing_slugs([]) == []
    end

    test "get_existing_slugs/1 returns the existing slugs from the input list" do
      slugs =
        insert_pair(:section_resource)
        |> Enum.map(& &1.slug)
        |> Enum.sort()

      assert Sections.get_existing_slugs(["another_slug" | slugs]) |> Enum.sort() == slugs
    end
  end

  describe "section updates" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "check_for_available_publication_updates/1 returns a list of available updates", %{
      author: author,
      project: project,
      container: %{resource: container_resource, revision: container_revision},
      institution: institution
    } do
      {:ok, initial_pub} = Publishing.publish_project(project, "some changes", author.id)

      # Create a course section using the initial publication
      {:ok, section} =
        Sections.create_section(%{
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: institution.id,
          base_project_id: project.id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(initial_pub)

      available_updates = Sections.check_for_available_publication_updates(section)

      assert available_updates |> Enum.count() == 0

      # make some changes to project and publish
      working_pub = Publishing.project_working_publication(project.slug)

      %{resource: p1_new_page1, revision: _revision} =
        Seeder.create_page("P1 New Page one", working_pub, project, author)

      %{resource: p1_new_page2, revision: _revision} =
        Seeder.create_page("P1 New Page two", working_pub, project, author)

      _container_revision =
        Seeder.attach_pages_to(
          [p1_new_page1, p1_new_page2],
          container_resource,
          container_revision,
          working_pub
        )

      {:ok, latest_publication} = Publishing.publish_project(project, "some changes", author.id)

      # verify project published changes show up in list of updates
      available_updates = Sections.check_for_available_publication_updates(section)

      assert available_updates |> Enum.count() == 1
      assert available_updates[project.id].id == latest_publication.id
    end

    test "check_for_updates_in_progress/2", %{
      author: author,
      project: project,
      container: %{resource: container_resource, revision: container_revision},
      page1: page1,
      revision1: revision1,
      page2: page2,
      revision2: revision2,
      institution: institution
    } do
      {:ok, initial_pub} = Publishing.publish_project(project, "some changes", author.id)

      # Create a course section using the initial publication
      {:ok, section} =
        Sections.create_section(%{
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: institution.id,
          base_project_id: project.id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(initial_pub)

      # verify the curriculum precondition
      hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      assert hierarchy.children |> Enum.count() == 2
      assert hierarchy.children |> Enum.at(0) |> Map.get(:resource_id) == page1.id
      assert hierarchy.children |> Enum.at(1) |> Map.get(:resource_id) == page2.id

      # make some changes to project and publish
      working_pub = Publishing.project_working_publication(project.slug)

      # minor resource content changes
      page1_changes = %{
        "content" => %{
          "model" => [
            %{
              "type" => "content",
              "children" => [%{"type" => "p", "children" => [%{"text" => "SECOND"}]}]
            }
          ]
        }
      }

      Seeder.revise_page(page1_changes, page1, revision1, working_pub)

      # add some pages to the root container
      %{resource: p1_new_page1, revision: _revision} =
        Seeder.create_page("P1 New Page one", working_pub, project, author)

      %{resource: p1_new_page2, revision: _revision} =
        Seeder.create_page("P1 New Page two", working_pub, project, author)

      container_revision =
        Seeder.attach_pages_to(
          [p1_new_page1, p1_new_page2],
          container_resource,
          container_revision,
          working_pub
        )

      # create a unit
      %{resource: unit1_resource, revision: unit1_revision} =
        Seeder.create_container("Unit 1", working_pub, project, author)

      # create some nested children
      %{resource: nested_page1, revision: _nested_revision1} =
        Seeder.create_page("Nested Page One", working_pub, project, author)

      %{resource: nested_page2, revision: _nested_revision2} =
        Seeder.create_page(
          "Nested Page Two",
          working_pub,
          project,
          author,
          Seeder.create_sample_content()
        )

      _unit1_revision =
        Seeder.attach_pages_to(
          [nested_page1, nested_page2],
          unit1_resource,
          unit1_revision,
          working_pub
        )

      container_revision =
        Seeder.attach_pages_to(
          [unit1_resource],
          container_resource,
          container_revision,
          working_pub
        )

      # remove page 2
      _deleted_revision =
        Seeder.delete_page(page2, revision2, container_resource, container_revision, working_pub)

      # publish changes
      {:ok, latest_publication} = Publishing.publish_project(project, "some changes", author.id)

      # queue the publication update and immediately check for updates in progress
      %{"section_slug" => section.slug, "publication_id" => latest_publication.id}
      |> Oli.Delivery.Updates.Worker.new()
      |> Oban.insert!()

      updates_in_progress = Sections.check_for_updates_in_progress(section)

      assert Enum.count(updates_in_progress) == 1
      assert Map.has_key?(updates_in_progress, latest_publication.id)
    end

    @tag capture_log: true
    test "apply_publication_update/2", %{
      author: author,
      project: project,
      container: %{resource: container_resource, revision: container_revision},
      page1: page1,
      revision1: revision1,
      page2: page2,
      revision2: revision2,
      institution: institution
    } do
      {:ok, initial_pub} = Publishing.publish_project(project, "some changes", author.id)

      # Create a course section using the initial publication
      {:ok, section} =
        Sections.create_section(%{
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: institution.id,
          base_project_id: project.id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(initial_pub)

      # verify the curriculum precondition
      hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      assert hierarchy.children |> Enum.count() == 2
      assert hierarchy.children |> Enum.at(0) |> Map.get(:resource_id) == page1.id
      assert hierarchy.children |> Enum.at(1) |> Map.get(:resource_id) == page2.id

      # make some changes to project and publish
      working_pub = Publishing.project_working_publication(project.slug)

      # minor resource content changes
      page1_changes = %{
        "content" => %{
          "model" => [
            %{
              "type" => "content",
              "children" => [%{"type" => "p", "children" => [%{"text" => "SECOND"}]}]
            }
          ]
        }
      }

      Seeder.revise_page(page1_changes, page1, revision1, working_pub)

      # add some pages to the root container
      %{resource: p1_new_page1, revision: _revision} =
        Seeder.create_page("P1 New Page one", working_pub, project, author)

      %{resource: p1_new_page2, revision: _revision} =
        Seeder.create_page("P1 New Page two", working_pub, project, author)

      container_revision =
        Seeder.attach_pages_to(
          [p1_new_page1, p1_new_page2],
          container_resource,
          container_revision,
          working_pub
        )

      # create a unit
      %{resource: unit1_resource, revision: unit1_revision} =
        Seeder.create_container("Unit 1", working_pub, project, author)

      # create some nested children
      %{resource: nested_page1, revision: _nested_revision1} =
        Seeder.create_page("Nested Page One", working_pub, project, author)

      %{resource: nested_page2, revision: _nested_revision2} =
        Seeder.create_page(
          "Nested Page Two",
          working_pub,
          project,
          author,
          Seeder.create_sample_content()
        )

      _unit1_revision =
        Seeder.attach_pages_to(
          [nested_page1, nested_page2],
          unit1_resource,
          unit1_revision,
          working_pub
        )

      container_revision =
        Seeder.attach_pages_to(
          [unit1_resource],
          container_resource,
          container_revision,
          working_pub
        )

      # remove page
      _deleted_revision =
        Seeder.delete_page(page2, revision2, container_resource, container_revision, working_pub)

      # publish changes
      {:ok, latest_publication} = Publishing.publish_project(project, "some changes", author.id)

      # apply the new publication update to the section
      Oli.Delivery.Sections.Updates.apply_publication_update(section, latest_publication.id)

      # reload latest hierarchy
      hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      # verify non-structural changes are applied as expected
      assert hierarchy.children |> Enum.at(0) |> then(& &1.revision.content) ==
               page1_changes["content"]

      # verify the updated curriculum structure matches the expected result
      assert hierarchy.children |> Enum.count() == 4
      assert hierarchy.children |> Enum.at(0) |> Map.get(:resource_id) == page1.id
      assert hierarchy.children |> Enum.at(1) |> Map.get(:resource_id) == p1_new_page1.id
      assert hierarchy.children |> Enum.at(2) |> Map.get(:resource_id) == p1_new_page2.id
      assert hierarchy.children |> Enum.at(3) |> Map.get(:resource_id) == unit1_resource.id

      assert hierarchy.children |> Enum.at(3) |> Map.get(:children) |> Enum.count() == 2

      assert hierarchy.children
             |> Enum.at(3)
             |> Map.get(:children)
             |> Enum.at(0)
             |> Map.get(:resource_id) == nested_page1.id

      assert hierarchy.children
             |> Enum.at(3)
             |> Map.get(:children)
             |> Enum.at(1)
             |> Map.get(:resource_id) == nested_page2.id

      # verify the final number of section resource records matches what is
      # expected to guard against section resource record leaks
      section_id = section.id

      section_resources =
        from(sr in SectionResource,
          where: sr.section_id == ^section_id
        )
        |> Repo.all()

      # there is only seven since one of the pages is unreachable
      assert section_resources |> Enum.count() == 7
    end

    @tag capture_log: true
    test "apply_publication_update/2 handles minor non-hierarchical updates",
         %{
           project: project,
           page1: page1,
           revision1: revision1,
           page2: page2,
           institution: institution
         } = map do
      {:ok, initial_pub} = Publishing.publish_project(project, "some changes", map.author.id)

      # create a course section using the initial publication
      {:ok, section} =
        Sections.create_section(%{
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: institution.id,
          base_project_id: project.id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(initial_pub)

      # verify the curriculum precondition
      hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      assert hierarchy.children |> Enum.count() == 2
      assert hierarchy.children |> Enum.at(0) |> Map.get(:resource_id) == page1.id
      assert hierarchy.children |> Enum.at(1) |> Map.get(:resource_id) == page2.id

      # make some changes to project and publish
      working_pub = Publishing.project_working_publication(project.slug)

      map = Map.put(map, :publication, working_pub)

      # minor resource content changes, including adding activity and objective
      activity_content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [
                %{
                  "rule" => "input like {a}",
                  "score" => 10,
                  "id" => "r1",
                  "feedback" => %{"id" => "1", "content" => "yes"}
                },
                %{
                  "rule" => "input like {b}",
                  "score" => 1,
                  "id" => "r2",
                  "feedback" => %{"id" => "2", "content" => "almost"}
                },
                %{
                  "rule" => "input like {c}",
                  "score" => 0,
                  "id" => "r3",
                  "feedback" => %{"id" => "3", "content" => "no"}
                }
              ],
              "scoringStrategy" => "best",
              "evaluationStrategy" => "regex"
            }
          ]
        }
      }

      map =
        Seeder.add_activity(
          map,
          %{title: "activity one", max_attempts: 2, content: activity_content},
          :activity
        )

      map = Seeder.add_objective(map, "objective one", :o1)

      page1_changes = %{
        "content" => %{
          "model" => [
            %{
              "type" => "content",
              "children" => [%{"type" => "p", "children" => [%{"text" => "SECOND"}]}]
            },
            %{
              "type" => "activity-reference",
              "activity_id" => Map.get(map, :activity).revision.resource_id
            }
          ]
        },
        "objectives" => %{"attached" => [Map.get(map, :o1).resource.id]}
      }

      Seeder.revise_page(page1_changes, page1, revision1, working_pub)

      # publish changes
      {:ok, latest_publication} =
        Publishing.publish_project(project, "some changes", map.author.id)

      # verify the publication is a minor update
      assert latest_publication.edition == 0
      assert latest_publication.major == 1
      assert latest_publication.minor == 1

      # apply the new publication update to the section
      Oli.Delivery.Sections.Updates.apply_publication_update(section, latest_publication.id)

      # reload latest hierarchy
      hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      # verify non-structural changes are applied as expected
      assert hierarchy.children |> Enum.at(0) |> then(& &1.revision.content) ==
               page1_changes["content"]

      assert hierarchy.children |> Enum.at(0) |> then(& &1.revision.objectives) ==
               page1_changes["objectives"]

      # verify the activity section resource exists
      section_id = section.id

      section_resources =
        from(sr in SectionResource,
          where: sr.section_id == ^section_id
        )
        |> Repo.all()

      assert section_resources |> Enum.count() == 5

      assert section_resources
             |> Enum.find(fn sr -> sr.resource_id == Map.get(map, :activity).resource.id end)

      assert section_resources
             |> Enum.find(fn sr -> sr.resource_id == Map.get(map, :o1).resource.id end)
    end

    @tag capture_log: true
    test "apply_publication_update/2 only applies minor changes to products", %{
      author: author,
      project: project,
      container: %{resource: container_resource, revision: container_revision},
      page1: page1,
      revision1: revision1,
      page2: page2,
      revision2: revision2
    } do
      {:ok, _pr} = Publishing.publish_project(project, "some changes", author.id)

      %{product: product, section: section} =
        %{}
        |> Oli.Utils.Seeder.Project.create_product("Product 1", project, product_tag: :product)
        |> Oli.Utils.Seeder.Section.create_section_from_product(ref(:product), nil, nil, %{},
          section_tag: :section
        )

      # one week ago
      one_week_ago = DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second)
      a_day_later = DateTime.utc_now() |> DateTime.add(-6, :day) |> DateTime.truncate(:second)

      # Simulate customizing assessment settings for page1
      page1_sr = Oli.Delivery.Sections.get_section_resource(section.id, page1.id)

      {:ok, _} =
        Oli.Delivery.Sections.update_section_resource(page1_sr, %{
          scoring_strategy_id: 2,
          scheduling_type: :due_by,
          manually_scheduled: true,
          start_date: one_week_ago,
          end_date: a_day_later,
          collab_space_config: %Oli.Resources.Collaboration.CollabSpaceConfig{
            status: :enabled,
            threaded: false,
            auto_accept: false,
            show_full_history: false,
            anonymous_posting: false,
            participation_min_posts: 100,
            participation_min_replies: 101
          },
          explanation_strategy: %Oli.Resources.ExplanationStrategy{
            type: :after_set_num_attempts,
            set_num_attempts: 10
          },
          max_attempts: 200,
          retake_mode: :targeted,
          assessment_mode: :one_at_a_time,
          # "I've got the same combination on my luggage"
          password: "12345",
          late_submit: :disallow,
          late_start: :disallow,
          time_limit: 90,
          grace_period: 100,
          review_submission: :disallow,
          feedback_mode: :scheduled,
          feedback_scheduled_date: a_day_later
        })

      # verify the curriculum precondition
      hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      assert hierarchy.children |> Enum.count() == 2
      assert hierarchy.children |> Enum.at(0) |> Map.get(:resource_id) == page1.id
      assert hierarchy.children |> Enum.at(1) |> Map.get(:resource_id) == page2.id

      # make some changes to project and publish
      working_pub = Publishing.project_working_publication(project.slug)

      # minor resource content changes
      page1_changes = %{
        "content" => %{
          "model" => [
            %{
              "type" => "content",
              "children" => [%{"type" => "p", "children" => [%{"text" => "SECOND"}]}]
            }
          ]
        }
      }

      Seeder.revise_page(page1_changes, page1, revision1, working_pub)

      # add some pages to the root container
      %{resource: p1_new_page1, revision: _revision} =
        Seeder.create_page("P1 New Page one", working_pub, project, author)

      %{resource: p1_new_page2, revision: _revision} =
        Seeder.create_page("P1 New Page two", working_pub, project, author)

      container_revision =
        Seeder.attach_pages_to(
          [p1_new_page1, p1_new_page2],
          container_resource,
          container_revision,
          working_pub
        )

      # create a unit
      %{resource: unit1_resource, revision: unit1_revision} =
        Seeder.create_container("Unit 1", working_pub, project, author)

      # create some nested children
      %{resource: nested_page1, revision: _nested_revision1} =
        Seeder.create_page("Nested Page One", working_pub, project, author)

      %{resource: nested_page2, revision: _nested_revision2} =
        Seeder.create_page(
          "Nested Page Two",
          working_pub,
          project,
          author,
          Seeder.create_sample_content()
        )

      _unit1_revision =
        Seeder.attach_pages_to(
          [nested_page1, nested_page2],
          unit1_resource,
          unit1_revision,
          working_pub
        )

      container_revision =
        Seeder.attach_pages_to(
          [unit1_resource],
          container_resource,
          container_revision,
          working_pub
        )

      # remove page 2
      _deleted_revision =
        Seeder.delete_page(page2, revision2, container_resource, container_revision, working_pub)

      # publish changes
      {:ok, latest_publication} = Publishing.publish_project(project, "some changes", author.id)

      # apply the new publication update to the product
      Oli.Delivery.Sections.Updates.apply_publication_update(product, latest_publication.id)

      # reload latest hierarchy
      product_hierarchy = DeliveryResolver.full_hierarchy(product.slug)

      # verify non-structural changes are applied as expected
      assert product_hierarchy.children |> Enum.at(0) |> then(& &1.revision.content) ==
               page1_changes["content"]

      # verify structural changes are not applied tp product
      assert product_hierarchy.children |> Enum.count() == 2
      assert product_hierarchy.children |> Enum.at(0) |> Map.get(:resource_id) == page1.id
      assert product_hierarchy.children |> Enum.at(1) |> Map.get(:resource_id) == page2.id

      # verify the final number of section resource records matches what is
      # expected to guard against section resource record leaks
      product_id = product.id

      product_section_resources =
        from(sr in SectionResource,
          where: sr.section_id == ^product_id
        )
        |> Repo.all()

      assert product_section_resources |> Enum.count() == 3

      # apply the new publication update to the section
      Oli.Delivery.Sections.Updates.apply_publication_update(section, latest_publication.id)

      # reload latest hierarchy
      hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      # verify non-structural changes are applied as expected
      assert hierarchy.children |> Enum.at(0) |> then(& &1.revision.content) ==
               page1_changes["content"]

      # verify the updated curriculum structure matches the expected result

      assert hierarchy.children |> Enum.count() == 4
      assert hierarchy.children |> Enum.at(0) |> Map.get(:resource_id) == page1.id
      assert hierarchy.children |> Enum.at(1) |> Map.get(:resource_id) == p1_new_page1.id
      assert hierarchy.children |> Enum.at(2) |> Map.get(:resource_id) == p1_new_page2.id
      assert hierarchy.children |> Enum.at(3) |> Map.get(:resource_id) == unit1_resource.id

      assert hierarchy.children |> Enum.at(3) |> Map.get(:children) |> Enum.count() == 2

      assert hierarchy.children
             |> Enum.at(3)
             |> Map.get(:children)
             |> Enum.at(0)
             |> Map.get(:resource_id) == nested_page1.id

      assert hierarchy.children
             |> Enum.at(3)
             |> Map.get(:children)
             |> Enum.at(1)
             |> Map.get(:resource_id) == nested_page2.id

      # verify the assessment settings remain unchanged
      page1_sr = Oli.Delivery.Sections.get_section_resource(section.id, page1.id)
      assert page1_sr.scoring_strategy_id == 2
      assert page1_sr.scheduling_type == :due_by
      assert page1_sr.manually_scheduled == true
      assert page1_sr.start_date == one_week_ago
      assert page1_sr.end_date == a_day_later
      assert page1_sr.collab_space_config.status == :enabled
      assert page1_sr.collab_space_config.threaded == false
      assert page1_sr.collab_space_config.auto_accept == false
      assert page1_sr.collab_space_config.show_full_history == false
      assert page1_sr.collab_space_config.anonymous_posting == false
      assert page1_sr.collab_space_config.participation_min_posts == 100
      assert page1_sr.collab_space_config.participation_min_replies == 101
      assert page1_sr.explanation_strategy.type == :after_set_num_attempts
      assert page1_sr.explanation_strategy.set_num_attempts == 10
      assert page1_sr.max_attempts == 200
      assert page1_sr.retake_mode == :targeted
      assert page1_sr.assessment_mode == :one_at_a_time
      assert page1_sr.password == "12345"
      assert page1_sr.late_submit == :disallow
      assert page1_sr.late_start == :disallow
      assert page1_sr.time_limit == 90
      assert page1_sr.grace_period == 100
      assert page1_sr.review_submission == :disallow
      assert page1_sr.feedback_mode == :scheduled
      assert page1_sr.feedback_scheduled_date == a_day_later

      # verify the final number of section resource records matches what is
      # expected to guard against section resource record leaks
      section_id = section.id

      section_resources =
        from(sr in SectionResource,
          where: sr.section_id == ^section_id
        )
        |> Repo.all()

      assert section_resources |> Enum.count() == 7
    end

    @tag capture_log: true
    test "apply_publication_update/2 applies major changes to section based from product when apply_major_updates is true",
         %{
           author: author,
           project: project,
           container: %{resource: container_resource, revision: container_revision},
           page1: page1,
           revision1: revision1,
           page2: page2,
           revision2: revision2
         } do
      {:ok, _initial_pub} = Publishing.publish_project(project, "some changes", author.id)

      seeds =
        %{product: product} =
        Oli.Utils.Seeder.Project.create_product(%{}, "Product 1", project, product_tag: :product)

      Oli.Delivery.Sections.update_section(product, %{apply_major_updates: true})

      %{section: section} =
        Oli.Utils.Seeder.Section.create_section_from_product(
          seeds,
          ref(:product),
          nil,
          nil,
          %{blueprint_id: product.id},
          section_tag: :section
        )

      section = Repo.preload(section, :blueprint)
      # one week ago
      one_week_ago = DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second)
      a_day_later = DateTime.utc_now() |> DateTime.add(-6, :day) |> DateTime.truncate(:second)

      # Simulate customizing assessment settings for page1
      page1_sr = Oli.Delivery.Sections.get_section_resource(section.id, page1.id)

      {:ok, _} =
        Oli.Delivery.Sections.update_section_resource(page1_sr, %{
          scoring_strategy_id: 2,
          scheduling_type: :due_by,
          manually_scheduled: true,
          start_date: one_week_ago,
          end_date: a_day_later,
          collab_space_config: %Oli.Resources.Collaboration.CollabSpaceConfig{
            status: :enabled,
            threaded: false,
            auto_accept: false,
            show_full_history: false,
            anonymous_posting: false,
            participation_min_posts: 100,
            participation_min_replies: 101
          },
          explanation_strategy: %Oli.Resources.ExplanationStrategy{
            type: :after_set_num_attempts,
            set_num_attempts: 10
          },
          max_attempts: 200,
          retake_mode: :targeted,
          assessment_mode: :one_at_a_time,
          # "I've got the same combination on my luggage"
          password: "12345",
          late_submit: :disallow,
          late_start: :disallow,
          time_limit: 90,
          grace_period: 100,
          review_submission: :disallow,
          feedback_mode: :scheduled,
          feedback_scheduled_date: a_day_later
        })

      # verify the curriculum precondition
      hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      assert hierarchy.children |> Enum.count() == 2
      assert hierarchy.children |> Enum.at(0) |> Map.get(:resource_id) == page1.id
      assert hierarchy.children |> Enum.at(1) |> Map.get(:resource_id) == page2.id

      # make some changes to project and publish
      working_pub = Publishing.project_working_publication(project.slug)

      # minor resource content changes
      page1_changes = %{
        "content" => %{
          "model" => [
            %{
              "type" => "content",
              "children" => [%{"type" => "p", "children" => [%{"text" => "SECOND"}]}]
            }
          ]
        }
      }

      Seeder.revise_page(page1_changes, page1, revision1, working_pub)

      # add some pages to the root container
      %{resource: p1_new_page1, revision: _revision} =
        Seeder.create_page("P1 New Page one", working_pub, project, author)

      %{resource: p1_new_page2, revision: _revision} =
        Seeder.create_page("P1 New Page two", working_pub, project, author)

      container_revision =
        Seeder.attach_pages_to(
          [p1_new_page1, p1_new_page2],
          container_resource,
          container_revision,
          working_pub
        )

      # create a unit
      %{resource: unit1_resource, revision: unit1_revision} =
        Seeder.create_container("Unit 1", working_pub, project, author)

      # create some nested children
      %{resource: nested_page1, revision: _nested_revision1} =
        Seeder.create_page("Nested Page One", working_pub, project, author)

      %{resource: nested_page2, revision: _nested_revision2} =
        Seeder.create_page(
          "Nested Page Two",
          working_pub,
          project,
          author,
          Seeder.create_sample_content()
        )

      _unit1_revision =
        Seeder.attach_pages_to(
          [nested_page1, nested_page2],
          unit1_resource,
          unit1_revision,
          working_pub
        )

      container_revision =
        Seeder.attach_pages_to(
          [unit1_resource],
          container_resource,
          container_revision,
          working_pub
        )

      # remove page 2
      _deleted_revision =
        Seeder.delete_page(page2, revision2, container_resource, container_revision, working_pub)

      # publish changes
      {:ok, latest_publication} = Publishing.publish_project(project, "some changes", author.id)

      # apply the new publication update to the section
      Oli.Delivery.Sections.Updates.apply_publication_update(section, latest_publication.id)

      # reload latest hierarchy
      hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      # verify non-structural changes are applied as expected
      assert hierarchy.children |> Enum.at(0) |> then(& &1.revision.content) ==
               page1_changes["content"]

      # verify the updated curriculum structure matches the expected result

      assert hierarchy.children |> Enum.count() == 4
      assert hierarchy.children |> Enum.at(0) |> Map.get(:resource_id) == page1.id
      assert hierarchy.children |> Enum.at(1) |> Map.get(:resource_id) == p1_new_page1.id
      assert hierarchy.children |> Enum.at(2) |> Map.get(:resource_id) == p1_new_page2.id
      assert hierarchy.children |> Enum.at(3) |> Map.get(:resource_id) == unit1_resource.id

      assert hierarchy.children |> Enum.at(3) |> Map.get(:children) |> Enum.count() == 2

      assert hierarchy.children
             |> Enum.at(3)
             |> Map.get(:children)
             |> Enum.at(0)
             |> Map.get(:resource_id) == nested_page1.id

      assert hierarchy.children
             |> Enum.at(3)
             |> Map.get(:children)
             |> Enum.at(1)
             |> Map.get(:resource_id) == nested_page2.id

      # verify the assessment settings remain unchanged
      page1_sr = Oli.Delivery.Sections.get_section_resource(section.id, page1.id)
      assert page1_sr.scoring_strategy_id == 2
      assert page1_sr.scheduling_type == :due_by
      assert page1_sr.manually_scheduled == true
      assert page1_sr.start_date == one_week_ago
      assert page1_sr.end_date == a_day_later
      assert page1_sr.collab_space_config.status == :enabled
      assert page1_sr.collab_space_config.threaded == false
      assert page1_sr.collab_space_config.auto_accept == false
      assert page1_sr.collab_space_config.show_full_history == false
      assert page1_sr.collab_space_config.anonymous_posting == false
      assert page1_sr.collab_space_config.participation_min_posts == 100
      assert page1_sr.collab_space_config.participation_min_replies == 101
      assert page1_sr.explanation_strategy.type == :after_set_num_attempts
      assert page1_sr.explanation_strategy.set_num_attempts == 10
      assert page1_sr.max_attempts == 200
      assert page1_sr.retake_mode == :targeted
      assert page1_sr.assessment_mode == :one_at_a_time
      assert page1_sr.password == "12345"
      assert page1_sr.late_submit == :disallow
      assert page1_sr.late_start == :disallow
      assert page1_sr.time_limit == 90
      assert page1_sr.grace_period == 100
      assert page1_sr.review_submission == :disallow
      assert page1_sr.feedback_mode == :scheduled
      assert page1_sr.feedback_scheduled_date == a_day_later

      # verify the final number of section resource records matches what is
      # expected to guard against section resource record leaks
      section_id = section.id

      section_resources =
        from(sr in SectionResource,
          where: sr.section_id == ^section_id
        )
        |> Repo.all()

      assert section_resources |> Enum.count() == 7
    end

    @tag capture_log: true
    test "apply_publication_update/2 applies minor changes to section based from product when apply_major_updates is false",
         %{
           author: author,
           project: project,
           container: %{resource: container_resource, revision: container_revision},
           page1: page1,
           revision1: revision1,
           page2: page2,
           revision2: revision2
         } do
      {:ok, _initial_pub} = Publishing.publish_project(project, "some changes", author.id)

      seeds =
        %{product: product} =
        Oli.Utils.Seeder.Project.create_product(%{}, "Product 1", project, product_tag: :product)

      %{section: section} =
        Oli.Utils.Seeder.Section.create_section_from_product(
          seeds,
          ref(:product),
          nil,
          nil,
          %{apply_major_updates: false, blueprint_id: product.id},
          section_tag: :section
        )

      section = Repo.preload(section, :blueprint)

      # one week ago
      one_week_ago = DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second)
      a_day_later = DateTime.utc_now() |> DateTime.add(-6, :day) |> DateTime.truncate(:second)

      # Simulate customizing assessment settings for page1
      page1_sr = Oli.Delivery.Sections.get_section_resource(section.id, page1.id)

      {:ok, _} =
        Oli.Delivery.Sections.update_section_resource(page1_sr, %{
          scoring_strategy_id: 2,
          scheduling_type: :due_by,
          manually_scheduled: true,
          start_date: one_week_ago,
          end_date: a_day_later,
          collab_space_config: %Oli.Resources.Collaboration.CollabSpaceConfig{
            status: :enabled,
            threaded: false,
            auto_accept: false,
            show_full_history: false,
            anonymous_posting: false,
            participation_min_posts: 100,
            participation_min_replies: 101
          },
          explanation_strategy: %Oli.Resources.ExplanationStrategy{
            type: :after_set_num_attempts,
            set_num_attempts: 10
          },
          max_attempts: 200,
          retake_mode: :targeted,
          assesment_mode: :one_at_a_time,
          # "I've got the same combination on my luggage"
          password: "12345",
          late_submit: :disallow,
          late_start: :disallow,
          time_limit: 90,
          grace_period: 100,
          review_submission: :disallow,
          feedback_mode: :scheduled,
          feedback_scheduled_date: a_day_later
        })

      # verify the curriculum precondition
      hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      assert hierarchy.children |> Enum.count() == 2
      assert hierarchy.children |> Enum.at(0) |> Map.get(:resource_id) == page1.id
      assert hierarchy.children |> Enum.at(1) |> Map.get(:resource_id) == page2.id

      # make some changes to project and publish
      working_pub = Publishing.project_working_publication(project.slug)

      # minor resource content changes
      page1_changes = %{
        "content" => %{
          "model" => [
            %{
              "type" => "content",
              "children" => [%{"type" => "p", "children" => [%{"text" => "SECOND"}]}]
            }
          ]
        }
      }

      Seeder.revise_page(page1_changes, page1, revision1, working_pub)

      # add some pages to the root container
      %{resource: p1_new_page1, revision: _revision} =
        Seeder.create_page("P1 New Page one", working_pub, project, author)

      %{resource: p1_new_page2, revision: _revision} =
        Seeder.create_page("P1 New Page two", working_pub, project, author)

      container_revision =
        Seeder.attach_pages_to(
          [p1_new_page1, p1_new_page2],
          container_resource,
          container_revision,
          working_pub
        )

      # create a unit
      %{resource: unit1_resource, revision: unit1_revision} =
        Seeder.create_container("Unit 1", working_pub, project, author)

      # create some nested children
      %{resource: nested_page1, revision: _nested_revision1} =
        Seeder.create_page("Nested Page One", working_pub, project, author)

      %{resource: nested_page2, revision: _nested_revision2} =
        Seeder.create_page(
          "Nested Page Two",
          working_pub,
          project,
          author,
          Seeder.create_sample_content()
        )

      _unit1_revision =
        Seeder.attach_pages_to(
          [nested_page1, nested_page2],
          unit1_resource,
          unit1_revision,
          working_pub
        )

      container_revision =
        Seeder.attach_pages_to(
          [unit1_resource],
          container_resource,
          container_revision,
          working_pub
        )

      # remove page 2
      _deleted_revision =
        Seeder.delete_page(page2, revision2, container_resource, container_revision, working_pub)

      # publish changes
      {:ok, latest_publication} = Publishing.publish_project(project, "some changes", author.id)

      # apply the new publication update to the section
      Oli.Delivery.Sections.Updates.apply_publication_update(section, latest_publication.id)

      # reload latest hierarchy
      section_hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      # verify non-structural changes are applied as expected
      assert section_hierarchy.children |> Enum.at(0) |> then(& &1.revision.content) ==
               page1_changes["content"]

      # verify structural changes are not applied to section
      assert section_hierarchy.children |> Enum.count() == 2
      assert section_hierarchy.children |> Enum.at(0) |> Map.get(:resource_id) == page1.id
      assert section_hierarchy.children |> Enum.at(1) |> Map.get(:resource_id) == page2.id

      # verify the final number of section resource records matches what is
      # expected to guard against section resource record leaks
      section_id = section.id

      section_resources =
        from(sr in SectionResource,
          where: sr.section_id == ^section_id
        )
        |> Repo.all()

      assert Enum.count(section_resources) == 3
    end
  end

  describe "get_student_roles?/2" do
    setup do
      user = insert(:user)
      section = insert(:section)
      {:ok, %{section: section, user: user}}
    end

    test "returns false for student and instructor when users are enrolled with any other roles",
         %{
           section: section,
           user: user
         } do
      other_roles =
        [
          :context_administrator,
          :context_content_developer,
          :context_mentor,
          :context_manager,
          :context_member,
          :context_officer
        ]
        |> Enum.map(&ContextRoles.get_role(&1))

      Sections.enroll(user.id, section.id, other_roles)

      assert %{is_student?: false, is_instructor?: false} ==
               Sections.get_user_roles(user, section.slug)
    end

    test "returns true when enrolled as student", %{
      section: section,
      user: user
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      assert %{is_student?: true, is_instructor?: false} ==
               Sections.get_user_roles(user, section.slug)
    end

    test "returns true when enrolled as instructor", %{
      section: section,
      user: user
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])

      assert %{is_student?: false, is_instructor?: true} ==
               Sections.get_user_roles(user, section.slug)
    end

    test "returns true when enrolled as instructor and student", %{
      section: section,
      user: user
    } do
      Sections.enroll(user.id, section.id, [
        ContextRoles.get_role(:context_instructor),
        ContextRoles.get_role(:context_learner)
      ])

      assert %{is_student?: true, is_instructor?: true} ==
               Sections.get_user_roles(user, section.slug)
    end
  end

  describe "sections remix" do
    setup do
      Seeder.base_project_with_resource4()
    end

    test "rebuild_section_curriculum/2 takes a section and hierarchy and upserts section resources",
         %{
           section_1: section,
           nested_revision1: nested_revision1,
           nested_revision2: nested_revision2
         } do
      hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      source_index = 0
      destination_index = 2
      container_node = Enum.at(hierarchy.children, 2)
      node = Enum.at(container_node.children, source_index)

      updated =
        Hierarchy.reorder_children(
          container_node,
          node,
          source_index,
          destination_index
        )

      hierarchy =
        Hierarchy.find_and_update_node(hierarchy, updated)
        |> Hierarchy.finalize()

      project_publications = Sections.get_pinned_project_publications(section.id)
      Sections.rebuild_section_curriculum(section, hierarchy, project_publications)

      hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      # verify the pages in the new hierarchy are reordered
      updated_container_node = Enum.at(hierarchy.children, 2)

      assert Enum.at(updated_container_node.children, 0).revision == nested_revision2
      assert Enum.at(updated_container_node.children, 1).revision == nested_revision1

      # # verify new numberings are correct
      assert hierarchy.numbering.level == 0
      assert hierarchy.numbering.index == 1

      assert Enum.at(hierarchy.children, 0).numbering.level == 1
      assert Enum.at(hierarchy.children, 0).numbering.index == 1
      assert Enum.at(hierarchy.children, 1).numbering.level == 1
      assert Enum.at(hierarchy.children, 1).numbering.index == 2

      # containers are numbered separately from pages, therefore
      # since this is the first container its numbering should be 1, 1
      assert Enum.at(hierarchy.children, 2).numbering.level == 1
      assert Enum.at(hierarchy.children, 2).numbering.index == 1

      # even though this page is at a lower level, pages are numbered
      # contiguously regardless of level. Therefore, this is page 3
      assert Enum.at(Enum.at(hierarchy.children, 2).children, 0).numbering.level == 2
      assert Enum.at(Enum.at(hierarchy.children, 2).children, 0).numbering.index == 3

      assert Enum.at(Enum.at(hierarchy.children, 2).children, 1).numbering.level == 2
      assert Enum.at(Enum.at(hierarchy.children, 2).children, 1).numbering.index == 4
    end
  end

  describe "list_user_enrolled_sections/1" do
    setup do
      student = insert(:user)
      section_1 = insert(:section)
      section_2 = insert(:section)

      Sections.enroll(student.id, section_1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(student.id, section_2.id, [ContextRoles.get_role(:context_learner)])
      {:ok, %{student: student, section_1: section_1, section_2: section_2}}
    end

    test "returns sections for user", %{
      student: student,
      section_1: section_1,
      section_2: section_2
    } do
      [s1 | [s2 | _rest]] = sections = Sections.list_user_enrolled_sections(student)
      assert length(sections) == 2

      assert s1.id == section_1.id
      assert s2.id == section_2.id
    end

    test "returns empty list when user is not enrolled in any sections", %{} do
      student = insert(:user)
      sections = Sections.list_user_enrolled_sections(student)
      assert sections == []
    end
  end

  describe "has_visited_section/2" do
    setup do
      student = insert(:user)
      section = insert(:section)

      {:ok, %{student: student, section: section}}
    end

    test "when user has a resource access associated to the section, it returns true", %{
      student: student,
      section: section
    } do
      resource = insert(:resource)

      insert(:resource_access, %{
        access_count: 0,
        user: student,
        resource: resource,
        section: section
      })

      assert Sections.has_visited_section(section, student) == true
    end

    test "when user has the \"visited\" flag in its enrollment, it returns true", %{
      student: student,
      section: section
    } do
      insert(:enrollment, %{user: student, section: section})
      |> Sections.Enrollment.changeset(%{state: %{has_visited_once: true}})
      |> Repo.update()

      assert Sections.has_visited_section(section, student) == true
    end

    test "when user doesn't have a resource access nor the \"visited\" flag in its enrollment, it returns false",
         %{student: student, section: section} do
      assert Sections.has_visited_section(section, student) == false
    end
  end

  describe "mark_section_visited_for_student/2" do
    setup do
      student = insert(:user)
      section = insert(:section)

      {:ok, %{student: student, section: section}}
    end

    test "updates the \"visited\" flag in the enrollment state when called", %{
      student: student,
      section: section
    } do
      enrollment = insert(:enrollment, %{user: student, section: section})

      Sections.mark_section_visited_for_student(section, student)

      updated_state =
        Sections.Enrollment
        |> where([e], e.id == ^enrollment.id)
        |> select([e], e.state)
        |> Repo.one()

      assert updated_state["has_visited_once"] == true
    end
  end

  describe "transfer student data" do
    setup [:sections_with_same_publications]

    test "gets course sections to which a student's data can be transferred", %{
      section_1: section_1,
      section_2: section_2
    } do
      sections = Transfer.get_sections_to_transfer_data(section_1)
      [target_section_2] = sections

      assert length(sections) == 1
      assert target_section_2.title == section_2.title
    end

    test "deletes attempts and resource accesses by section and user", %{
      section_1: section_1,
      user_1: user_1
    } do
      # gets resource accesses, resource attempts, activity attempts and part attempts from target section
      resource_accesses =
        Core.get_resource_accesses(section_1.slug, user_1.id) |> Enum.map(& &1.id)

      resource_attempts =
        Core.get_resource_attempts_by_resource_accesses(resource_accesses) |> Enum.map(& &1.id)

      activity_attempts =
        Core.get_activity_attempts_by_resource_attempts(resource_attempts) |> Enum.map(& &1.id)

      # assert that there are resource accesses, resource attempts, activity attempts and part attempts in target section

      assert Core.get_resource_accesses(section_1.slug, user_1.id) |> length() == 1

      assert Core.get_resource_attempts_by_resource_accesses(resource_accesses) |> length() == 1

      assert Core.get_activity_attempts_by_resource_attempts(resource_attempts) |> length() == 1

      assert Core.get_part_attempts_by_activity_attempts(activity_attempts) |> length() == 1

      # delete resource accesses, resource attempts, activity attempts and part attempts for target section

      Core.delete_resource_accesses_by_section_and_user(section_1.id, user_1.id)

      # assert that there are no resource accesses, resource attempts, activity attempts and part attempts in target section

      assert Core.get_resource_accesses(section_1.slug, user_1.id) |> length() == 0

      assert Core.get_resource_attempts_by_resource_accesses(resource_accesses) |> length() == 0

      assert Core.get_activity_attempts_by_resource_attempts(resource_attempts) |> length() == 0

      assert Core.get_part_attempts_by_activity_attempts(activity_attempts) |> length() == 0
    end
  end

  describe "get_next_activities_for_student/3" do
    test "returns the upcoming activities in a section for a given student" do
      page_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_page(),
          title: "Upcoming assessment",
          graded: true,
          content: %{"advancedDelivery" => true}
        )

      container_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_container(),
          title: "A graded container?",
          graded: true,
          content: %{"advancedDelivery" => true}
        )

      {:ok, section: section, project: _project, author: author} =
        section_with_pages(%{
          revisions: [page_revision, container_revision],
          revision_section_attributes: [
            %{
              start_date: DateTime.add(DateTime.utc_now(), -10, :day),
              end_date: DateTime.add(DateTime.utc_now(), 5, :day)
            },
            %{
              start_date: DateTime.add(DateTime.utc_now(), -10, :day),
              end_date: DateTime.add(DateTime.utc_now(), 5, :day)
            }
          ]
        })

      student = insert(:user)

      session_context = %OliWeb.Common.SessionContext{
        browser_timezone: "utc",
        local_tz: "utc",
        author: author,
        user: student,
        is_liveview: false
      }

      enroll_user_to_section(student, section, :context_learner)

      next_activities =
        Sections.get_next_activities_for_student(section.slug, student.id, session_context)

      assert length(next_activities) == 1
      assert Enum.at(next_activities, 0).title == "Upcoming assessment"
    end
  end

  describe "get_latest_visited_page/2" do
    test "returns the latest page revision visited by a user in a section" do
      page_1_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_page(),
          title: "Learning Elixir"
        )

      page_2_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_page(),
          title: "Enum.map"
        )

      {:ok, section: section, project: _project, author: _author} =
        section_with_pages(%{
          revisions: [page_1_revision, page_2_revision]
        })

      student = insert(:user)

      enroll_user_to_section(student, section, :context_learner)

      # visit page 1
      visit_page(page_1_revision, section, student)
      revision = Sections.get_latest_visited_page(section.slug, student.id)
      assert revision.title == "Learning Elixir"

      # visit page 2
      visit_page(page_2_revision, section, student)
      revision = Sections.get_latest_visited_page(section.slug, student.id)
      assert revision.title == "Enum.map"
    end

    test "returns nil if the user has not visited any page in the section" do
      page_1_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_page(),
          title: "Learning Elixir"
        )

      page_2_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_page(),
          title: "Enum.map"
        )

      {:ok, section: section, project: _project, author: _author} =
        section_with_pages(%{
          revisions: [page_1_revision, page_2_revision]
        })

      student = insert(:user)

      enroll_user_to_section(student, section, :context_learner)

      refute Sections.get_latest_visited_page(section.slug, student.id)
    end
  end

  describe "get_section_resources_with_lti_activities/1" do
    setup do
      section = insert(:section)

      lti_deployment = insert(:lti_external_tool_activity_deployment)

      activity_registration =
        insert(:activity_registration,
          lti_external_tool_activity_deployment: lti_deployment
        )

      lti_activity_revision =
        insert(:revision,
          activity_type_id: activity_registration.id
        )

      lti_activity_resource = lti_activity_revision.resource

      lti_section_resource =
        insert(:section_resource,
          section: section,
          resource_id: lti_activity_resource.id,
          revision_id: lti_activity_revision.id
        )

      page_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_page(),
          activity_refs: [lti_activity_resource.id]
        )

      page_section_resource =
        insert(:section_resource,
          section: section,
          resource_id: page_revision.resource_id,
          revision_id: page_revision.id
        )

      %{
        section: section,
        lti_activity_resource: lti_activity_resource,
        lti_section_resource: lti_section_resource,
        page_section_resource: page_section_resource
      }
    end

    test "returns empty map when section has no LTI activities" do
      empty_section = insert(:section)

      result = Sections.get_section_resources_with_lti_activities(empty_section)

      assert result == %{}
    end

    test "returns map of LTI activity IDs to section resources", %{
      section: section,
      lti_activity_resource: lti_activity_resource,
      page_section_resource: page_section_resource
    } do
      result = Sections.get_section_resources_with_lti_activities(section)

      assert is_map(result)
      assert map_size(result) == 1
      assert Map.has_key?(result, lti_activity_resource.id)

      section_resources = result[lti_activity_resource.id]
      assert is_list(section_resources)
      assert length(section_resources) == 1
      assert hd(section_resources).id == page_section_resource.id
    end

    test "handles multiple pages referencing the same LTI activity", %{
      section: section,
      lti_activity_resource: lti_activity_resource
    } do
      another_page_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_page(),
          activity_refs: [lti_activity_resource.id]
        )

      another_page_section_resource =
        insert(:section_resource,
          section: section,
          resource_id: another_page_revision.resource_id,
          revision_id: another_page_revision.id
        )

      result = Sections.get_section_resources_with_lti_activities(section)

      section_resources = result[lti_activity_resource.id]
      assert length(section_resources) == 2

      section_resource_ids = Enum.map(section_resources, & &1.id)
      assert Enum.member?(section_resource_ids, another_page_section_resource.id)
    end

    test "handles multiple LTI activities referenced by pages", %{
      section: section
    } do
      lti_deployment2 = insert(:lti_external_tool_activity_deployment)

      activity_registration2 =
        insert(:activity_registration,
          lti_external_tool_activity_deployment: lti_deployment2
        )

      lti_activity_revision2 =
        insert(:revision,
          activity_type_id: activity_registration2.id
        )

      lti_activity_resource2 = lti_activity_revision2.resource

      insert(:section_resource,
        section: section,
        resource_id: lti_activity_resource2.id,
        revision_id: lti_activity_revision2.id
      )

      page_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_page(),
          activity_refs: [lti_activity_resource2.id]
        )

      page_section_resource =
        insert(:section_resource,
          section: section,
          resource_id: page_revision.resource_id,
          revision_id: page_revision.id
        )

      result = Sections.get_section_resources_with_lti_activities(section)

      assert map_size(result) == 2
      assert Map.has_key?(result, lti_activity_resource2.id)

      section_resources = result[lti_activity_resource2.id]
      assert length(section_resources) == 1
      assert hd(section_resources).id == page_section_resource.id
    end

    test "ignores pages that don't reference LTI activities", %{
      section: section
    } do
      page_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_page(),
          activity_refs: []
        )

      insert(:section_resource,
        section: section,
        resource_id: page_revision.resource_id,
        revision_id: page_revision.id
      )

      result = Sections.get_section_resources_with_lti_activities(section)

      assert is_map(result)
      assert map_size(result) == 1
    end
  end
end
