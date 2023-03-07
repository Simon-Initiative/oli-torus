defmodule Oli.SectionsTest do
  use Oli.DataCase

  import Oli.Factory
  import Oli.Utils.Seeder.Utils

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionResource
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Publishing
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Hierarchy

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

    test "unenroll/3 deletes an enrollment if all context roles are removed", %{
      section: section,
      user1: user1
    } do
      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_instructor)])

      Sections.unenroll(user1.id, section.id, [ContextRoles.get_role(:context_instructor)])

      assert Sections.list_enrollments(section.slug) == []
    end

    test "unenroll_learner/2 deletes an enrollment if the user is only a student", %{
      section: section,
      user1: user1
    } do
      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_learner)])

      Sections.unenroll_learner(user1.id, section.id)

      assert Sections.list_enrollments(section.slug) == []
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

    test "has_student_data?/1 returns false when section has no snapshots", %{section: section} do
      refute Sections.has_student_data?(section.slug)
    end

    test "has_student_data?/1 returns true when section has snapshots" do
      section = insert(:snapshot).section
      assert Sections.has_student_data?(section.slug)
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
      {:ok, initial_pub} = Publishing.publish_project(project, "some changes")

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

      {:ok, latest_publication} = Publishing.publish_project(project, "some changes")

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
      {:ok, initial_pub} = Publishing.publish_project(project, "some changes")

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
      {:ok, latest_publication} = Publishing.publish_project(project, "some changes")

      # queue the publication update and immediately check for updates in progress
      %{"section_slug" => section.slug, "publication_id" => latest_publication.id}
      |> Oli.Delivery.Updates.Worker.new()
      |> Oban.insert!()

      updates_in_progress = Sections.check_for_updates_in_progress(section)

      assert Enum.count(updates_in_progress) == 1
      assert Map.has_key?(updates_in_progress, latest_publication.id)
    end

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
      {:ok, initial_pub} = Publishing.publish_project(project, "some changes")

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
      {:ok, latest_publication} = Publishing.publish_project(project, "some changes")

      # apply the new publication update to the section
      Sections.apply_publication_update(section, latest_publication.id)

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

      assert section_resources |> Enum.count() == 8
    end

    test "apply_publication_update/2 handles minor non-hierarchical updates",
         %{
           project: project,
           page1: page1,
           revision1: revision1,
           page2: page2,
           institution: institution
         } = map do
      {:ok, initial_pub} = Publishing.publish_project(project, "some changes")

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
      {:ok, latest_publication} = Publishing.publish_project(project, "some changes")

      # verify the publication is a minor update
      assert latest_publication.edition == 0
      assert latest_publication.major == 1
      assert latest_publication.minor == 1

      # apply the new publication update to the section
      Sections.apply_publication_update(section, latest_publication.id)

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

    test "apply_publication_update/2 only applies minor changes to products", %{
      author: author,
      project: project,
      container: %{resource: container_resource, revision: container_revision},
      page1: page1,
      revision1: revision1,
      page2: page2,
      revision2: revision2
    } do
      {:ok, _initial_pub} = Publishing.publish_project(project, "some changes")

      %{product: product, section: section} =
        %{}
        |> Oli.Utils.Seeder.Project.create_product("Product 1", project, product_tag: :product)
        |> Oli.Utils.Seeder.Section.create_section_from_product(ref(:product), nil, nil, %{},
          section_tag: :section
        )

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
      {:ok, latest_publication} = Publishing.publish_project(project, "some changes")

      # apply the new publication update to the product
      Sections.apply_publication_update(product, latest_publication.id)

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

      assert product_section_resources |> Enum.count() == 7

      # apply the new publication update to the section
      Sections.apply_publication_update(section, latest_publication.id)

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

      assert section_resources |> Enum.count() == 8
    end
  end

  describe "is_student?/2" do
    setup do
      user = insert(:user)
      section = insert(:section)
      {:ok, %{section: section, user: user}}
    end

    test "returns false for enrolled users that are not students", %{
      section: section,
      user: user
    } do
      other_roles = [
        :context_administrator,
        :context_content_developer,
        :context_instructor,
        :context_learner,
        :context_mentor,
        :context_manager,
        :context_member,
        :context_officer
      ]

      not_student_random_role = Enum.random(other_roles)

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(not_student_random_role)])

      refute Sections.is_student?(user, section.slug)
    end

    test "returns true for enrolled students", %{
      section: section,
      user: user
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      assert Sections.is_student?(user, section.slug)
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
end
