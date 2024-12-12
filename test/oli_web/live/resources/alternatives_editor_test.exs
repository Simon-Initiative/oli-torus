defmodule OliWeb.Resources.AlternativesEditorTest do
  use OliWeb.ConnCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Oli.Utils.Seeder.Utils

  alias Oli.Utils.Seeder

  defp create_project(map) do
    map
    |> Seeder.Project.create_author(author_tag: :author)
    |> Seeder.Project.create_sample_project(
      ref(:author),
      project_tag: :project,
      publication_tag: :publication,
      unscored_page1_tag: :unscored_page1,
      unscored_page1_activity_tag: :unscored_page1_activity,
      scored_page2_tag: :scored_page2,
      scored_page2_activity_tag: :scored_page2_activity
    )
  end

  defp login_as_author(map) do
    map
    |> Seeder.Session.login_as_author(ref(:author))
  end

  describe "author is not logged in" do
    setup [:create_project]

    test "redirects to new session when accessing alternatives editor view", %{
      conn: conn,
      project: project
    } do
      redirect_path =
        "/authors/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(
          conn,
          Routes.live_path(
            OliWeb.Endpoint,
            OliWeb.Resources.AlternativesEditor,
            project.slug
          )
        )
    end
  end

  describe "author is logged in" do
    setup [:create_project, :login_as_author]

    test "redirects to not found when project does not exist", %{conn: conn} do
      {:error,
       {:redirect,
        %{flash: %{"info" => "That project does not exist"}, to: "/workspaces/course_author"}}} =
        live(
          conn,
          Routes.live_path(
            OliWeb.Endpoint,
            OliWeb.Resources.AlternativesEditor,
            "slug_does_not_exist"
          )
        )
    end

    test "renders when there are no alternatives groups", %{conn: conn, project: project} do
      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(
            OliWeb.Endpoint,
            OliWeb.Resources.AlternativesEditor,
            project.slug
          )
        )

      assert has_element?(view, "h2", "Alternatives")
      assert has_element?(view, "div", "There are no alternatives groups")
    end

    test "renders creation of a new alternatives group and group option", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(
            OliWeb.Endpoint,
            OliWeb.Resources.AlternativesEditor,
            project.slug
          )
        )

      # show create alternatives modal
      view
      |> element(~s|button[phx-click="show_create_modal"|)
      |> render_click()

      assert has_element?(view, ~s|div[class="modal-dialog"]|)
      assert has_element?(view, "h5", "Create Alternative")

      # create alternatives group
      view
      |> element(~s|form[phx-submit="create_group"|)
      |> render_submit(%{"params" => %{"name" => "Stats Package"}})

      # verify new alternatives group was created with no options
      assert has_element?(view, "b", "Stats Package")
      assert has_element?(view, "em", "There are no options in this group")

      # show add option modal
      view
      |> element(~s|button[phx-click="show_create_option_modal"|)
      |> render_click()

      assert has_element?(view, ~s|div[class="modal-dialog"]|)
      assert has_element?(view, "h5", "Create Option")

      # create option
      view
      |> element(~s|form[phx-submit="create_option"|)
      |> render_submit(%{"params" => %{"name" => "Excel"}})

      # verify alternatives group contains new option
      assert has_element?(view, "div", "Excel")
      refute has_element?(view, "em", "There are no options in this group")

      # show edit option modal
      view
      |> element(~s|button[phx-click="show_edit_option_modal"]|)
      |> render_click()

      assert has_element?(view, ~s|div[class="modal-dialog"]|)
      assert has_element?(view, "h5", "Edit Option")

      # edit option
      view
      |> element(~s|form[phx-submit="edit_option"|)
      |> render_submit(%{"params" => %{"name" => "Shine"}})

      # verify alternatives group contains the edited option
      assert has_element?(view, "div", "Shine")
      refute has_element?(view, "div", "Excel")

      # show delete option modal
      view
      |> element(~s|button[phx-click="show_delete_option_modal"]|)
      |> render_click()

      assert has_element?(view, ~s|div[class="modal-dialog"]|)
      assert has_element?(view, "h5", "Delete Option")

      # delete option
      view
      |> element(~s|button[phx-click="delete_option"]|)
      |> render_click()

      # verify alternatives group doesn't contain the deleted option
      assert has_element?(view, "em", "There are no options in this group")
    end
  end
end
