defmodule Oli.CourseTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.{Family, Project}
  alias Oli.Delivery.Sections
  alias Oli.Inventories

  describe "projects basic" do
    @valid_attrs %{description: "some description", version: "1", title: "some title"}
    @update_attrs %{
      description: "some updated description",
      version: "1",
      title: "some updated title"
    }
    @invalid_attrs %{description: nil, slug: nil, title: nil}

    setup do
      project = insert(:project)

      valid_attrs =
        Map.put(@valid_attrs, :family_id, project.family_id)
        |> Map.put(:project_id, project.id)
        |> Map.put(:publisher_id, project.publisher_id)

      {:ok, %{project: project, valid_attrs: valid_attrs}}
    end

    test "list_projects/0 returns all projects", %{project: project} do
      assert [returned_project] = Course.list_projects()
      assert returned_project.id == project.id
    end

    test "get_project!/1 returns the project with given id", %{project: project} do
      assert returned_project = Course.get_project!(project.id)
      assert returned_project.id == project.id
    end

    test "create_project/2 with invalid data returns error changeset" do
      empty_title = ""
      assert {:error, _} = Oli.TestHelpers.create_project_fixture(empty_title, author_fixture())
    end

    test "create_empty_project/1 with valid data creates a project", %{valid_attrs: valid_attrs} do
      assert {:ok, %Project{} = project} = create_empty_project(valid_attrs)
      assert project.description == "some description"
      assert project.slug == "some_title"
      assert project.title == "some title"
      assert project.lo_well_formed
    end

    test "create_empty_project/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = create_empty_project(@invalid_attrs)
    end

    test "update_project/2 writes the export fields that background jobs maintain", %{
      project: project
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {:ok, %Project{} = updated} =
               Course.update_project(project, %{
                 latest_export_url: "https://example.edu/export.zip",
                 latest_export_timestamp: now
               })

      assert updated.latest_export_url == "https://example.edu/export.zip"
    end

    test "update_project/2 refuses project settings", %{project: project} do
      assert {:error, :protected} = Course.update_project(project, @update_attrs)

      assert {:error, :protected} =
               Course.update_project(project, %{"latest_export_url" => "x", "title" => "Other"})

      assert Course.get_project!(project.id).title == project.title
    end
  end

  describe "get_project_license/1" do
    setup do
      attributes = nil
      project = insert(:project, attributes: attributes)
      %{revision: revision, publication: publication} = insert(:published_resource)

      %{section: section} =
        _spp = insert(:section_project_publication, project: project, publication: publication)

      %{page: revision, project: project, publication: publication, section: section}
    end

    test "returns map for a Creative Commons license", %{
      page: page,
      project: project,
      publication: publication,
      section: section
    } do
      attributes = %{
        attributes: %{
          license: %{license_type: :cc_by, custom_license_details: nil}
        }
      }

      {:ok, project} = Oli.TestHelpers.update_project_fixture(project, attributes)
      Sections.update_section_project_publication(section, project.id, publication.id)

      assert %{license_type: :cc_by, custom_license_details: nil} =
               Oli.Authoring.Course.get_project_license(page.id, section.slug)
    end

    test "returns map for custom license", %{
      page: page,
      project: project,
      publication: publication,
      section: section
    } do
      custom_license_msg = "Some custom license"

      attributes = %{
        attributes: %{
          license: %{license_type: :custom, custom_license_details: custom_license_msg}
        }
      }

      {:ok, project} = Oli.TestHelpers.update_project_fixture(project, attributes)
      Sections.update_section_project_publication(section, project.id, publication.id)

      assert %{license_type: :custom, custom_license_details: ^custom_license_msg} =
               Oli.Authoring.Course.get_project_license(page.id, section.slug)
    end

    test "returns nil when no attributes are present", %{page: page, section: section} do
      refute Oli.Authoring.Course.get_project_license(page.id, section.slug)
    end
  end

  describe "get_projects_for_author/1" do
    setup do
      # Create a regular author
      author = insert(:author)

      # Create an author with system_admin role
      system_admin =
        insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().system_admin)

      # Create an author with account_admin role
      account_admin =
        insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().account_admin)

      # Create an author with content_admin role
      content_admin =
        insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().content_admin)

      # Create projects
      project1 = insert(:project)
      project2 = insert(:project)
      project3 = insert(:project)

      # Associate author with project1 only
      insert(:author_project, author_id: author.id, project_id: project1.id)

      {:ok,
       %{
         author: author,
         system_admin: system_admin,
         account_admin: account_admin,
         content_admin: content_admin,
         project1: project1,
         project2: project2,
         project3: project3
       }}
    end

    test "returns only assigned projects for a regular author", %{
      author: author,
      project1: project1
    } do
      projects = Course.get_projects_for_author(author)

      assert length(projects) == 1
      assert Enum.any?(projects, fn p -> p.id == project1.id end)
    end

    test "returns all projects for a system admin", %{
      system_admin: system_admin,
      project1: project1,
      project2: project2,
      project3: project3
    } do
      projects = Course.get_projects_for_author(system_admin)

      # Should return all projects (including any from other tests)
      assert length(projects) >= 3
      assert Enum.any?(projects, fn p -> p.id == project1.id end)
      assert Enum.any?(projects, fn p -> p.id == project2.id end)
      assert Enum.any?(projects, fn p -> p.id == project3.id end)
    end

    test "returns all projects for an account admin", %{
      account_admin: account_admin,
      project1: project1,
      project2: project2,
      project3: project3
    } do
      projects = Course.get_projects_for_author(account_admin)

      # Should return all projects (including any from other tests)
      assert length(projects) >= 3
      assert Enum.any?(projects, fn p -> p.id == project1.id end)
      assert Enum.any?(projects, fn p -> p.id == project2.id end)
      assert Enum.any?(projects, fn p -> p.id == project3.id end)
    end

    test "returns all projects for a content admin", %{
      content_admin: content_admin,
      project1: project1,
      project2: project2,
      project3: project3
    } do
      projects = Course.get_projects_for_author(content_admin)

      # Should return all projects (including any from other tests)
      assert length(projects) >= 3
      assert Enum.any?(projects, fn p -> p.id == project1.id end)
      assert Enum.any?(projects, fn p -> p.id == project2.id end)
      assert Enum.any?(projects, fn p -> p.id == project3.id end)
    end
  end
end
