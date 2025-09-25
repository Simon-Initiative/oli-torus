defmodule OliWeb.InstitutionsLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Institutions
  alias Oli.Institutions.Institution

  defp live_view_route(institution_id),
    do:
      Routes.institution_path(
        OliWeb.Endpoint,
        OliWeb.Admin.Institutions.ResearchConsentView,
        institution_id
      )

  defp create_institution(_conn) do
    institution = insert(:institution)

    [institution: institution]
  end

  describe "user cannot access when is not logged in" do
    setup [:create_institution]

    test "redirects to new session when accessing the research content view", %{
      conn: conn,
      institution: institution
    } do
      redirect_path =
        "/authors/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} = live(conn, live_view_route(institution.id))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :create_institution]

    test "returns forbidden when accessing the research consent view", %{
      conn: conn,
      institution: institution
    } do
      conn = get(conn, live_view_route(institution.id))

      assert redirected_to(conn) == ~p"/workspaces/course_author"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You are not authorized to access this page."
    end
  end

  describe "institution research consent view" do
    setup [:admin_conn, :create_institution]

    test "redirects to not found when institution not exists", %{conn: conn} do
      {:error, {:redirect, %{to: "/not_found"}}} = live(conn, live_view_route(-1))
    end

    test "loads correctly with oli form", %{conn: conn, institution: institution} do
      {:ok, view, _html} = live(conn, live_view_route(institution.id))

      assert has_element?(view, "h5", "Manage Research Consent")
      assert has_element?(view, "input[value=\"oli_form\"][checked]")
      assert has_element?(view, "input[value=\"no_form\"]")
      assert has_element?(view, "form[phx-submit='save']")
    end

    test "loads correctly with no form", %{conn: conn} do
      institution = insert(:institution, research_consent: :no_form)

      {:ok, view, _html} = live(conn, live_view_route(institution.id))

      assert has_element?(view, "h5", "Manage Research Consent")
      assert has_element?(view, "input[value=\"oli_form\"]")
      assert has_element?(view, "input[value=\"no_form\"][checked]")
      assert has_element?(view, "form[phx-submit='save']")
    end

    test "displays error message when data is invalid", %{conn: conn, institution: institution} do
      {:ok, view, _html} = live(conn, live_view_route(institution.id))

      view
      |> element("form[phx-submit='save']")
      |> render_submit(%{"institution" => %{"research_consent" => "invalid"}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Institution couldn&#39;t be created/updated. Please check the errors below."

      assert has_element?(view, "p", "is invalid")
    end

    test "saves institution with no form when data is valid", %{
      conn: conn,
      institution: institution
    } do
      {:ok, view, _html} = live(conn, live_view_route(institution.id))

      view
      |> element("form[phx-submit='save']")
      |> render_submit(%{"institution" => %{"research_consent" => "no_form"}})

      flash =
        assert_redirected(view, Routes.institution_path(OliWeb.Endpoint, :show, institution.id))

      assert flash["info"] == "Institution successfully updated."

      %Institution{research_consent: research_consent} =
        Institutions.get_institution_by!(%{id: institution.id})

      assert research_consent == :no_form
    end

    test "saves institution with oli form when data is valid", %{conn: conn} do
      institution = insert(:institution, research_consent: :no_form)
      {:ok, view, _html} = live(conn, live_view_route(institution.id))

      view
      |> element("form[phx-submit='save']")
      |> render_submit(%{"institution" => %{"research_consent" => "oli_form"}})

      flash =
        assert_redirected(view, Routes.institution_path(OliWeb.Endpoint, :show, institution.id))

      assert flash["info"] == "Institution successfully updated."

      %Institution{research_consent: research_consent} =
        Institutions.get_institution_by!(%{id: institution.id})

      assert research_consent == :oli_form
    end
  end
end
