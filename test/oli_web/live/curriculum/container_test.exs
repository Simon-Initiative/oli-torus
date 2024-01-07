defmodule OliWeb.Curriculum.ContainerLiveTest do
  use OliWeb.ConnCase

  alias Oli.Seeder
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver

  import Oli.Factory
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint OliWeb.Endpoint

  describe "cannot access when is not logged in" do
    test "redirect to new session when accessing the container view", %{
      conn: conn
    } do
      project = insert(:project)

      redirect_path =
        "/authoring/session/new?request_path=%2Fauthoring%2Fproject%2F#{project.slug}%2Fcurriculum"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, Routes.container_path(@endpoint, :index, project.slug))
    end
  end

  describe "cannot access when is not an author" do
    setup [:user_conn]

    test "redirect to new session when accessing the container view", %{
      conn: conn
    } do
      project = insert(:project)

      redirect_path =
        "/authoring/session/new?request_path=%2Fauthoring%2Fproject%2F#{project.slug}%2Fcurriculum"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, Routes.container_path(@endpoint, :index, project.slug))
    end
  end

  describe "container live test" do
    setup [:setup_session]

    test "disconnected and connected mount", %{
      conn: conn,
      author: author,
      project: project,
      map: map
    } do
      conn =
        get(
          conn,
          "/authoring/project/#{project.slug}/curriculum/#{AuthoringResolver.root_container(project.slug).slug}"
        )

      # Routing to the root container redirects to the `curriculum` path
      redir_path = "/authoring/project/#{project.slug}/curriculum"
      assert redirected_to(conn, 302) =~ redir_path

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(
          author,
          OliWeb.Pow.PowHelpers.get_pow_config(:author)
        )

      conn = get(conn, redir_path)

      # The implicit root container path (/curriculum/) should show the root container resources
      {:ok, view, _} = live(conn)

      # the container should have two pages
      page1 = Map.get(map, :page1)
      page2 = Map.get(map, :page2)

      assert view
             |> element("##{Integer.to_string(page1.id)}")
             |> has_element?()

      assert view
             |> element("##{Integer.to_string(page2.id)}")
             |> has_element?()
    end

    test "shows the author name editing the page correctly", %{
      conn: conn,
      project: project,
      map: %{
        published_resource1: published_resource1
      }
    } do
      editing_author = insert(:author)

      Publishing.update_published_resource(published_resource1, %{
        locked_by_id: editing_author.id,
        lock_updated_at: now()
      })

      {:ok, view, _} = live(conn, Routes.container_path(@endpoint, :index, project.slug))

      assert has_element?(view, "span", "#{editing_author.name} is editing")
    end

    test "shows duplicate action for pages", %{
      conn: conn,
      author: author,
      project: project,
      revision1: revision_page_one,
      revision2: revision_page_two
    } do
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(
          author,
          OliWeb.Pow.PowHelpers.get_pow_config(:author)
        )
        |> get("/authoring/project/#{project.slug}/curriculum/")

      {:ok, view, _html} = live(conn)

      # Duplicate action is present with the right revision id
      assert view
             |> element(
               "div[phx-value-slug=\"#{revision_page_one.slug}\"] button[role=\"duplicate_page\"]"
             )
             |> render =~ "phx-value-id=\"#{revision_page_one.id}\""

      # Clicking on duplicate action creates a new entry with the right title name
      view
      |> element(
        "div[phx-value-slug=\"#{revision_page_two.slug}\"] button[role=\"duplicate_page\"]"
      )
      |> render_click =~
        "entry-title\">Copy of #{revision_page_two.title}</span>"
    end

    test "does not show duplicate action for adaptive pages", %{
      conn: conn,
      author: author,
      project: project,
      adaptive_page_revision: adaptive_page_revision
    } do
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(
          author,
          OliWeb.Pow.PowHelpers.get_pow_config(:author)
        )
        |> get("/authoring/project/#{project.slug}/curriculum/")

      {:ok, view, _html} = live(conn)

      assert view
             |> has_element?("div[phx-value-slug=\"#{adaptive_page_revision.slug}\"]")

      refute view
             |> has_element?(
               "div[phx-value-slug=\"#{adaptive_page_revision.slug}\"] button[phx-click=\"duplicate_page\"]"
             )
    end

    test "show the correct fields for the page option modal", %{
      conn: conn,
      author: author,
      project: project,
      revision1: revision_page_one
    } do
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(
          author,
          OliWeb.Pow.PowHelpers.get_pow_config(:author)
        )
        |> get("/authoring/project/#{project.slug}/curriculum/")

      {:ok, view, _html} = live(conn)

      view
      |> element(
        "div[phx-value-slug=\"#{revision_page_one.slug}\"] button[role=\"show_options_modal\"]"
      )
      |> render_click() =~ "Page Options"

      assert has_element?(
               view,
               "form#revision-settings-form [name=\"revision[title]\"]"
             )

      assert has_element?(
               view,
               "form#revision-settings-form [name=\"revision[graded]\"]"
             )

      assert has_element?(
               view,
               "form#revision-settings-form [name=\"revision[explanation_strategy][type]\"]"
             )

      assert has_element?(
               view,
               "form#revision-settings-form [name=\"revision[max_attempts]\"]"
             )

      assert has_element?(
               view,
               "form#revision-settings-form [name=\"revision[scoring_strategy_id]\"]"
             )

      assert has_element?(
               view,
               "form#revision-settings-form [name=\"revision[retake_mode]\"]"
             )

      assert has_element?(
               view,
               "form#revision-settings-form [name=\"revision[purpose]\"]"
             )

      assert has_element?(
               view,
               "form#revision-settings-form div#related-resources-selector"
             )
    end

    test "when the page is of type 'foundation', the related resources selector is disabled",
         %{
           conn: conn,
           author: author,
           project: project,
           revision1: revision_page_one
         } do
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(
          author,
          OliWeb.Pow.PowHelpers.get_pow_config(:author)
        )
        |> get("/authoring/project/#{project.slug}/curriculum/")

      {:ok, view, _html} = live(conn)

      view
      |> element(
        "div[phx-value-slug=\"#{revision_page_one.slug}\"] button[role=\"show_options_modal\"]"
      )
      |> render_click()

      view
      |> form("form#revision-settings-form", %{
        "revision" => %{
          "purpose" => "foundation"
        }
      })

      assert view
             |> element("div#related-resources-selector")
             |> render() =~ "disabled"
    end

    test "the related resources get updated in the database", %{
      conn: conn,
      author: author,
      project: project,
      revision1: revision_page_one,
      revision2: revision_page_two
    } do
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(
          author,
          OliWeb.Pow.PowHelpers.get_pow_config(:author)
        )
        |> get("/authoring/project/#{project.slug}/curriculum/")

      {:ok, view, _html} = live(conn)

      view
      |> element(
        "div[phx-value-slug=\"#{revision_page_one.slug}\"] button[role=\"show_options_modal\"]"
      )
      |> render_click()

      view
      |> form("form#revision-settings-form")
      |> render_submit(%{
        "revision" => %{
          "purpose" => "application",
          "relates_to" => [revision_page_two.resource_id]
        }
      })

      assert Oli.Publishing.AuthoringResolver.from_revision_slug(
               project.slug,
               revision_page_one.slug
             )
             |> Map.get(:relates_to) == [revision_page_two.resource_id]
    end

    test "an author can not see the `view revision history` link", %{
      conn: conn,
      author: author,
      project: project
    } do
      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(
          author,
          OliWeb.Pow.PowHelpers.get_pow_config(:author)
        )
        |> get("/authoring/project/#{project.slug}/curriculum")
        |> Map.put(
          :request_path,
          "/authoring/project/#{project.slug}/curriculum#show_links"
        )

      {:ok, view, _html} = live(conn)

      refute render(view) =~ "View revision history"
    end
  end

  describe "container live test (as admin)" do
    setup [:setup_session, :admin_conn]

    test "can see the `view revision history` link if the url has #show_links",
         %{
           conn: conn,
           project: project
         } do
      conn =
        conn
        |> get("/authoring/project/#{project.slug}/curriculum")
        |> Map.put(
          :request_path,
          "/authoring/project/#{project.slug}/curriculum#show_links"
        )

      {:ok, view, _html} = live(conn)

      assert render(view) =~ "View revision history"
    end

    test "can not see the `view revision history` link if the url does not have #show_links",
         %{
           conn: conn,
           project: project
         } do
      conn =
        conn
        |> get("/authoring/project/#{project.slug}/curriculum")

      {:ok, view, _html} = live(conn)

      refute render(view) =~ "View revision history"
    end

    test "can navigate to all pages view", %{conn: conn, project: project} do
      conn =
        conn
        |> get("/authoring/project/#{project.slug}/curriculum")

      {:ok, view, _html} = live(conn)

      view
      |> element("a[role='go_to_all_pages']", "All Pages")
      |> render_click()

      assert_redirect(
        view,
        ~p"/authoring/project/#{project.slug}/pages"
      )
    end
  end

  defp setup_session(%{conn: conn}) do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.add_adaptive_page()

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(
        map.author,
        OliWeb.Pow.PowHelpers.get_pow_config(:author)
      )

    {:ok,
     conn: conn,
     map: map,
     author: map.author,
     project: map.project,
     adaptive_page_revision: map.adaptive_page_revision,
     revision1: map.revision1,
     revision2: map.revision2}
  end
end
