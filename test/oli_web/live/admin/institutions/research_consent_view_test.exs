defmodule OliWeb.Admin.Institutions.ResearchConsentViewTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Ecto.Query, warn: false
  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Repo
  alias Oli.Institutions.Institution

  describe "admin" do
    setup [:admin_conn]

    test "the consent view gets rendered correctly", %{conn: conn} do
      institution = insert(:institution)

      {:ok, view, _html} =
        live(
          conn,
          Routes.institution_path(
            OliWeb.Endpoint,
            OliWeb.Admin.Institutions.ResearchConsentView,
            institution.id
          )
        )

      assert has_element?(view, "h5", "Manage Research Consent")
      assert has_element?(view, "input[name=\"institution[research_consent]\"]")
      assert has_element?(view, "label", "OLI Research Consent Form")
      assert has_element?(view, "label", "No Research Consent Form")
    end

    test "can update the institution consent", %{conn: conn} do
      institution = insert(:institution)

      {:ok, view, _html} =
        live(
          conn,
          Routes.institution_path(
            OliWeb.Endpoint,
            OliWeb.Admin.Institutions.ResearchConsentView,
            institution.id
          )
        )

      view
      |> form("form[phx-submit='save']")
      |> render_submit(%{
        institution: %{
          research_consent: :no_form
        }
      })

      assert Institution
             |> where([i], i.id == ^institution.id)
             |> Repo.one()
             |> Map.get(:research_consent) == :no_form
    end
  end
end
