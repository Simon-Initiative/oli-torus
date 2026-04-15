defmodule OliWeb.Attempt.AttemptLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  setup [:admin_conn]

  describe "sorting activity attempts" do
    test "ignores invalid sort keys" do
      {:ok, table_model} = OliWeb.Attempt.TableModel.new([])
      socket = %Phoenix.LiveView.Socket{assigns: %{table_model: table_model}}

      assert {:noreply, updated_socket} =
               OliWeb.Attempt.AttemptLive.handle_event(
                 "sort",
                 %{"sort_by" => "not_a_real_column"},
                 socket
               )

      assert updated_socket.assigns.table_model.sort_by_spec.name ==
               table_model.sort_by_spec.name

      assert updated_socket.assigns.table_model.sort_order == table_model.sort_order
    end

    setup do
      section = insert(:section)
      student = insert(:user)
      page_revision = insert(:revision)

      resource_access =
        insert(:resource_access,
          user: student,
          section: section,
          resource: page_revision.resource
        )

      resource_attempt =
        insert(:resource_attempt,
          resource_access: resource_access,
          revision: page_revision,
          attempt_guid: Ecto.UUID.generate()
        )

      early_revision = insert(:revision, title: "Early Screen")
      middle_revision = insert(:revision, title: "Middle Screen")
      late_revision = insert(:revision, title: "Late Screen")

      insert(:activity_attempt,
        resource_attempt: resource_attempt,
        revision: middle_revision,
        resource: middle_revision.resource,
        attempt_number: 2,
        date_evaluated: ~U[2024-01-02 12:00:00Z]
      )

      insert(:activity_attempt,
        resource_attempt: resource_attempt,
        revision: late_revision,
        resource: late_revision.resource,
        attempt_number: 3,
        date_evaluated: ~U[2024-01-03 12:00:00Z]
      )

      insert(:activity_attempt,
        resource_attempt: resource_attempt,
        revision: early_revision,
        resource: early_revision.resource,
        attempt_number: 1,
        date_evaluated: ~U[2024-01-01 12:00:00Z]
      )

      %{section: section, resource_attempt: resource_attempt}
    end

    test "sorts by date evaluated", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      view
      |> element("th[phx-click='sort'][phx-value-sort_by='date_evaluated']")
      |> render_click(%{sort_by: "date_evaluated"})

      assert view
             |> element("tbody tr:first-child td:nth-child(5)")
             |> render() =~ "Early Screen"

      assert view
             |> element("tbody tr:last-child td:nth-child(5)")
             |> render() =~ "Late Screen"

      view
      |> element("th[phx-click='sort'][phx-value-sort_by='date_evaluated']")
      |> render_click(%{sort_by: "date_evaluated"})

      assert view
             |> element("tbody tr:first-child td:nth-child(5)")
             |> render() =~ "Late Screen"

      assert view
             |> element("tbody tr:last-child td:nth-child(5)")
             |> render() =~ "Early Screen"
    end
  end
end
