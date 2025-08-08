defmodule OliWeb.Admin.Institutions.IndexLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Institutions.Institution

  describe "admin" do
    setup [:admin_conn]

    test "when no institutions exist, a sign saying so gets render correctly", %{
      conn: conn
    } do
      {:ok, view, _html} = institutions_index_route(conn)

      assert has_element?(view, "div", "There are no registered institutions")
    end

    test "when institutions exist, the institutions list gets render correctly", %{conn: conn} do
      institutions = Enum.map(1..5, fn _ -> insert(:institution) end)

      {:ok, view, _html} = institutions_index_route(conn)

      assert view
             |> render()
             |> Floki.parse_document!()
             |> Floki.find("#institutions table tbody tr")
             |> length() == 5

      Enum.each(institutions, &assert(has_element?(view, "a", &1.name)))
    end
  end

  describe "pending registrations" do
    setup [:admin_conn]

    test "when no institutions exist, a sign saying so gets render correctly", %{
      conn: conn
    } do
      {:ok, view, _html} = institutions_index_route(conn)
      go_to_pending_registrations(view)

      assert has_element?(view, "div", "There are no pending registrations")
    end

    test "the pending registrations list gets render correctly", %{
      conn: conn
    } do
      pending_registrations = Enum.map(1..5, fn _ -> insert(:pending_registration) end)

      {:ok, view, _html} = institutions_index_route(conn)
      go_to_pending_registrations(view)

      assert view
             |> render()
             |> Floki.parse_document!()
             |> Floki.find("#pending_registrations table tbody tr")
             |> length() == 5

      Enum.each(pending_registrations, fn registration ->
        assert has_element?(view, "#pending_registrations table tbody tr td", registration.name)

        assert has_element?(
                 view,
                 "#pending_registrations table tbody tr td",
                 registration.institution_url
               )

        assert has_element?(
                 view,
                 "#pending_registrations table tbody tr td",
                 registration.institution_email
               )
      end)
    end

    test "can review pending registrations", %{conn: conn} do
      pending_registration = insert(:pending_registration)

      {:ok, view, _html} = institutions_index_route(conn)
      go_to_pending_registrations(view)

      view
      |> render_click("select_pending_registration", %{
        registration_id: pending_registration.id,
        action: "review"
      })

      assert has_element?(
               view,
               "input[value='#{pending_registration.name}'][placeholder='Institution Name']"
             )

      assert has_element?(
               view,
               "input[value='#{pending_registration.institution_url}'][placeholder='Institution URL']"
             )

      assert has_element?(
               view,
               "input[value='#{pending_registration.institution_email}'][placeholder='Contact Email']"
             )

      assert has_element?(
               view,
               "select[name='registration[country_code]'] option[value='US'][selected]"
             )

      assert has_element?(
               view,
               "input[value='#{pending_registration.client_id}'][placeholder='Client ID']"
             )

      assert has_element?(
               view,
               "input[value='#{pending_registration.issuer}'][placeholder='Issuer']"
             )

      assert has_element?(
               view,
               "input[value='#{pending_registration.deployment_id}'][placeholder='Deployment ID']"
             )

      assert has_element?(
               view,
               "input[value='#{pending_registration.key_set_url}'][placeholder='Keyset URL']"
             )

      assert has_element?(
               view,
               "input[value='#{pending_registration.auth_token_url}'][placeholder='Auth Token URL']"
             )

      assert has_element?(
               view,
               "input[value='#{pending_registration.auth_login_url}'][placeholder='Auth Login URL']"
             )

      assert has_element?(
               view,
               "input[value='#{pending_registration.auth_server}'][placeholder='Auth Server URL']"
             )
    end

    @tag capture_log: true
    test "can approve pending registrations", %{conn: conn} do
      pending_registration =
        insert(:pending_registration, %{
          name: "My new institution"
        })

      assert Institution
             |> where([i], i.name == "My new institution")
             |> Repo.one() == nil

      {:ok, view, _html} = institutions_index_route(conn)
      go_to_pending_registrations(view)

      view
      |> render_click("select_pending_registration", %{
        registration_id: pending_registration.id,
        action: "review"
      })

      view
      |> render_submit(
        "save_registration",
        %{
          registration:
            pending_registration
            |> Map.from_struct()
            |> Map.take([
              :country_code,
              :institution_email,
              :institution_url,
              :name,
              :issuer,
              :client_id,
              :deployment_id,
              :key_set_url,
              :auth_token_url,
              :auth_login_url,
              :auth_server,
              :line_items_service_domain
            ])
        }
      )

      assert Institution
             |> where([i], i.name == "My new institution")
             |> Repo.one() != nil
    end

    @tag capture_log: true
    test "when a pending registration is approved by setting a `New Institution`, the new institution is created correctly",
         %{conn: conn} do
      insert(:institution, %{
        institution_url: "www.existing_institution.com",
        name: "Existing institution"
      })

      pending_registration =
        insert(:pending_registration, %{
          institution_url: "www.existing_institution.com",
          name: "New Institution"
        })

      assert Institution
             |> where([i], i.name == "New Institution")
             |> Repo.one() == nil

      {:ok, view, _html} = institutions_index_route(conn)
      go_to_pending_registrations(view)

      view
      |> render_click("select_pending_registration", %{
        registration_id: pending_registration.id,
        action: "review"
      })

      view
      |> element("select[phx-change='select_existing_institution']")
      |> render_change(%{
        "_target" => ["registration", "institution_id"],
        "registration" => %{"institution_id" => ""}
      })

      view
      |> render_submit(
        "save_registration",
        %{
          registration:
            pending_registration
            |> Map.from_struct()
            |> Map.take([
              :country_code,
              :institution_email,
              :institution_url,
              :name,
              :issuer,
              :client_id,
              :deployment_id,
              :key_set_url,
              :auth_token_url,
              :auth_login_url,
              :auth_server,
              :line_items_service_domain
            ])
            |> Map.put(:institution_id, "")
        }
      )

      new_institution =
        Institution
        |> where([i], i.name == "New Institution")
        |> Repo.one()

      assert new_institution.institution_url == "www.existing_institution.com"
    end

    @tag capture_log: true
    test "when a pending registration contains the url of an existing institution, the existing institution is used instead",
         %{conn: conn} do
      existing_institution =
        insert(:institution, %{
          institution_url: "www.existing_institution.com",
          name: "Existing institution"
        })

      pending_registration =
        insert(:pending_registration, %{
          institution_url: "www.existing_institution.com",
          name: "Existing institution with different name"
        })

      {:ok, view, _html} = institutions_index_route(conn)
      go_to_pending_registrations(view)

      view
      |> render_click("select_pending_registration", %{
        registration_id: pending_registration.id,
        action: "review"
      })

      assert has_element?(
               view,
               "select[name='registration[institution_id]'] option[value='#{existing_institution.id}'][selected]"
             )

      view
      |> render_submit(
        "save_registration",
        %{
          registration:
            pending_registration
            |> Map.from_struct()
            |> Map.take([
              :country_code,
              :institution_email,
              :institution_url,
              :name,
              :issuer,
              :client_id,
              :deployment_id,
              :key_set_url,
              :auth_token_url,
              :auth_login_url,
              :auth_server,
              :line_items_service_domain
            ])
        }
      )

      assert Institution
             |> where([i], i.name == "Existing institution with different name")
             |> Repo.one() == nil
    end
  end

  defp institutions_index_route(conn),
    do:
      live(
        conn,
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Admin.Institutions.IndexLive
        )
      )

  defp go_to_pending_registrations(view) do
    render_click(view, "change_active_tab", %{"tab" => "pending_registrations_tab"})
  end
end
