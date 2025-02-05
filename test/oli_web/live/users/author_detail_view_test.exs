defmodule OliWeb.Users.AuthorsDetailViewTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Authoring.Authors.ProjectRole
  alias Oli.Accounts.SystemRole

  defp authors_detail_view(author_id) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Users.AuthorsDetailView, author_id)
  end

  describe "users cannot access" do
    setup [:user_conn]

    test "author details", %{conn: conn} do
      author = insert(:author)

      {:error, {:redirect, %{to: _}}} = live(conn, authors_detail_view(author.id))
    end
  end

  describe "admins can access" do
    setup [:admin_conn]

    test "author details", %{conn: conn} do
      author = insert(:author)

      {:ok, view, _html} = live(conn, authors_detail_view(author.id))

      assert render(view) =~ author.name
    end
  end

  describe "author details - projects group" do
    setup [:admin_conn]

    test "section gets rendered when there are no projects assigned to the author",
         %{
           conn: conn
         } do
      author = insert(:author)
      {:ok, view, _html} = live(conn, authors_detail_view(author.id))

      assert render(view) =~ "Projects"

      assert view |> element("#author_projects") |> render() =~ "None exist"
    end

    test "author projects get listed", %{conn: conn} do
      author = insert(:author)
      project_1 = create_project_for(author, :owner, %{title: "Elixir"})
      project_2 = create_project_for(author, :contributor, %{title: "Ruby"})

      author_2 = insert(:author)
      create_project_for(author_2, :owner, %{title: "JS"})

      {:ok, view, _html} = live(conn, authors_detail_view(author.id))

      assert view
             |> element("#author_projects table tr[id='#{project_1.id}']")
             |> render() =~
               "Elixir"

      assert view
             |> element("#author_projects table tr[id='#{project_1.id}']")
             |> render() =~
               "Owner"

      assert view
             |> element("#author_projects table tr[id='#{project_2.id}']")
             |> render() =~
               "Ruby"

      assert view
             |> element("#author_projects table tr[id='#{project_2.id}']")
             |> render() =~
               "Collaborator"

      refute view |> element("#author_projects") |> render() =~ "JS"
    end

    test "most recent edit value corresponds to author edit (not considering edits by other authors)",
         %{conn: conn} do
      author = insert(:author)
      project = create_project_for(author, :owner, %{title: "Elixir"})

      #  first publication
      # (its date should not be considered as most recent edit as there will be a more recent one)
      page_1_revision =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Page 1",
          graded: true,
          author_id: author.id,
          updated_at: ~U[2023-07-20 12:30:00Z]
        )

      container_revision =
        insert(:revision, %{
          resource: insert(:resource),
          objectives: %{},
          resource_type_id: Oli.Resources.ResourceType.id_for_container(),
          children: [page_1_revision.resource_id],
          content: %{},
          deleted: false,
          title: "Root Container",
          author_id: author.id,
          updated_at: ~U[2023-07-20 12:30:00Z]
        })

      insert(:project_resource, %{
        project_id: project.id,
        resource_id: page_1_revision.resource_id
      })

      insert(:project_resource, %{
        project_id: project.id,
        resource_id: container_revision.resource_id
      })

      publication =
        insert(:publication, %{
          project: project,
          root_resource_id: container_revision.resource_id
        })

      insert(:published_resource, %{
        publication: publication,
        resource: page_1_revision.resource,
        revision: page_1_revision,
        author: author
      })

      insert(:published_resource, %{
        publication: publication,
        resource: container_revision.resource,
        revision: container_revision,
        author: author
      })

      # make another publication
      # (this one should be considered as most recent edit value)
      page_1_revision_v2 =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Page 1 (edited)",
          graded: true,
          resource: page_1_revision.resource,
          author_id: author.id,
          updated_at: ~U[2023-07-21 12:31:00Z]
        )

      container_revision_v2 =
        insert(:revision, %{
          resource: container_revision.resource,
          objectives: %{},
          resource_type_id: Oli.Resources.ResourceType.id_for_container(),
          children: [page_1_revision.resource_id],
          content: %{},
          deleted: false,
          title: "Root Container",
          author_id: author.id,
          updated_at: ~U[2023-07-21 12:31:00Z]
        })

      publication_v2 =
        insert(:publication, %{
          project: project,
          root_resource_id: container_revision_v2.resource_id
        })

      insert(:published_resource, %{
        publication: publication_v2,
        resource: page_1_revision_v2.resource,
        revision: page_1_revision_v2,
        author: author
      })

      insert(:published_resource, %{
        publication: publication_v2,
        resource: container_revision_v2.resource,
        revision: container_revision_v2,
        author: author
      })

      # make another publication by other author
      # (this one should not be considered as most recent edit value, as it corresponds to another author)
      author_2 = insert(:author)

      page_1_revision_v2 =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Page 1 (edited)",
          graded: true,
          resource: page_1_revision.resource,
          author_id: author_2.id,
          updated_at: ~U[2023-07-21 12:32:00Z]
        )

      container_revision_v2 =
        insert(:revision, %{
          resource: container_revision.resource,
          objectives: %{},
          resource_type_id: Oli.Resources.ResourceType.id_for_container(),
          children: [page_1_revision.resource_id],
          content: %{},
          deleted: false,
          title: "Root Container",
          author_id: author_2.id,
          updated_at: ~U[2023-07-21 12:32:00Z]
        })

      publication_v2 =
        insert(:publication, %{
          project: project,
          root_resource_id: container_revision_v2.resource_id
        })

      insert(:published_resource, %{
        publication: publication_v2,
        resource: page_1_revision_v2.resource,
        revision: page_1_revision_v2,
        author: author_2
      })

      insert(:published_resource, %{
        publication: publication_v2,
        resource: container_revision_v2.resource,
        revision: container_revision_v2,
        author: author_2
      })

      {:ok, view, _html} = live(conn, authors_detail_view(author.id))

      assert view
             |> element("#author_projects table tr[id='#{project.id}']")
             |> render() =~
               "Elixir"

      assert view
             |> element("#author_projects table tr[id='#{project.id}']")
             |> render() =~
               "Owner"

      assert view
             |> element("#author_projects table tr[id='#{project.id}']")
             |> render() =~
               "Jul. 21, 2023 - 12:31 PM"
    end

    test "can search author projects", %{conn: conn} do
      author = insert(:author)
      project_1 = create_project_for(author, :owner, %{title: "Elixir"})
      project_2 = create_project_for(author, :contributor, %{title: "Ruby"})

      {:ok, view, _html} = live(conn, authors_detail_view(author.id))

      assert view
             |> element("#author_projects table tr[id='#{project_1.id}']")
             |> render() =~
               "Elixir"

      assert view
             |> element("#author_projects table tr[id='#{project_2.id}']")
             |> render() =~
               "Ruby"

      view
      |> element(~s{form[phx-change="search_project"]})
      |> render_change(%{project_title: "lix"})

      assert view
             |> element("#author_projects table tr[id='#{project_1.id}']")
             |> render() =~
               "Elixir"

      refute view |> element("#author_projects") |> render() =~ "Ruby"
    end

    test "can sort author projects", %{conn: conn} do
      author = insert(:author)
      create_project_for(author, :owner, %{title: "Elixir"})
      create_project_for(author, :contributor, %{title: "Ruby"})
      create_project_for(author, :contributor, %{title: "JS"})

      {:ok, view, _html} = live(conn, authors_detail_view(author.id))

      assert view
             |> element("#author_projects tbody tr:nth-of-type(1)")
             |> render() =~
               "Elixir"

      assert view
             |> element("#author_projects tbody tr:nth-of-type(2)")
             |> render() =~
               "JS"

      assert view
             |> element("#author_projects tbody tr:nth-of-type(3)")
             |> render() =~
               "Ruby"

      # sort by title :desc
      view
      |> element("#author_projects th:first-of-type")
      |> render_click

      assert view
             |> element("#author_projects tbody tr:nth-of-type(1)")
             |> render() =~
               "Ruby"

      assert view
             |> element("#author_projects tbody tr:nth-of-type(2)")
             |> render() =~
               "JS"

      assert view
             |> element("#author_projects tbody tr:nth-of-type(3)")
             |> render() =~
               "Elixir"
    end

    test "project title links to corresponding project", %{conn: conn} do
      author = insert(:author)
      project = create_project_for(author, :owner, %{title: "Elixir"})

      {:ok, view, _html} = live(conn, authors_detail_view(author.id))

      assert view
             |> element("#author_projects table tr[id='#{project.id}']")
             |> render() =~
               "Elixir"

      assert view
             |> element("#author_projects table tr[id='#{project.id}']")
             |> render() =~ ~p"/workspaces/course_author/#{project.slug}/overview"
    end

    test "system admin can edit author role", %{conn: conn} do
      author = insert(:author)

      {:ok, view, _html} = live(conn, authors_detail_view(author.id))

      # Start edit author
      view
      |> element("button[phx-click=\"start_edit\"]")
      |> render_click()

      # Assert that the author has author role
      assert view
             |> element("select option[value='#{author.system_role_id}']")
             |> render() =~
               "Author"

      # Change author role to account admin
      view
      |> element("#edit_author[phx-submit=\"submit\"")
      |> render_submit(%{"author" => %{"system_role_id" => "3"}})

      # Assert that the author has account admin role
      assert view
             |> element("select option[value='#{SystemRole.role_id().account_admin}']")
             |> render() =~
               "Account Admin"

      assert has_element?(view, "div.alert-info", "Author successfully updated.")
    end

    test "system admin can create a reset password link for an author", %{conn: conn} do
      author = insert(:author)

      {:ok, view, _html} = live(conn, authors_detail_view(author.id))

      view
      |> element(~s{button[phx-click="generate_reset_password_link"]})
      |> render_click()

      assert has_element?(view, "p", "This link will expire in 24 hours.")

      assert render(view) =~ "/authors/reset_password/"
    end
  end

  describe "author details - edit author" do
    setup [:account_admin_conn]

    test "non system admin cannot edit author role", %{conn: conn} do
      author = insert(:author)

      {:ok, view, _html} = live(conn, authors_detail_view(author.id))

      # Start edit author
      view
      |> element("button[phx-click=\"start_edit\"]")
      |> render_click()

      # Assert that the author role select is disabled
      assert has_element?(view, "select[name=\"author[system_role_id]\"][disabled=\"disabled\"]")
    end
  end

  defp create_project_for(author, :owner, attrs) do
    project = insert(:project, attrs)

    insert(:author_project, %{
      author_id: author.id,
      project_id: project.id,
      project_role_id: ProjectRole.role_id().owner
    })

    project
  end

  defp create_project_for(author, :contributor, attrs) do
    project = insert(:project, attrs)

    insert(:author_project, %{
      project_id: project.id
    })

    insert(:author_project, %{
      project_id: project.id,
      author_id: author.id,
      project_role_id: ProjectRole.role_id().contributor
    })

    project
  end
end
