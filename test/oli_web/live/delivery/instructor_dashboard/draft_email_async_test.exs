defmodule OliWeb.Delivery.InstructorDashboard.DraftEmailAsyncTest do
  @moduledoc """
  Focused coverage of the parent LiveView's request-scoped draft async contract:

      handle_info({:generate_draft, id, prev_rid, rid, ctx})
        -> cancel prev -> start_async({:draft, id, rid}, ...)
        -> handle_async({:draft, id, rid}, {:ok | :exit, _})
        -> deliver_draft_result(id, rid, _) -> send_update -> modal applies iff rid current

  Uses an isolated `DraftEmailModal` harness (no dashboard mount → no background oracle loaders).
  The Driver LiveView's handle_info/handle_async are routed to the REAL production handlers via
  attached hooks. The component mints/owns the request id (via its generate event), so a delivered
  result is applied only when ids match. Navigate-away cancellation is framework-backed (not
  re-tested here).
  """
  use OliWeb.ConnCase, async: false

  import LiveComponentTests
  import Phoenix.LiveViewTest
  import Phoenix.LiveView, only: [start_async: 3]
  import Ecto.Query, only: [from: 2]

  alias LiveComponentTests.Driver
  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.DraftEmailModal
  alias OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive
  alias Oli.GenAI.FeatureConfig
  alias Oli.Repo

  @component_id "draft_async_test"

  setup do
    # A migration seeds a global :instructor_email GenAI config; remove it (rolled back with the
    # test's sandbox) so generate_draft deterministically resolves to {:error, :missing_feature_config}.
    Repo.delete_all(from(f in FeatureConfig, where: f.feature == :instructor_email))
    :ok
  end

  describe "draft generation async contract" do
    test "the full handle_info -> start_async -> handle_async chain delivers to the modal", %{
      conn: conn
    } do
      {:ok, view, _html} = live_component_isolated(conn, DraftEmailModal, base_attrs())

      route_handle_async_to_production(view)
      route_handle_info_to_production(view)

      # The component mints the request id and sends {:generate_draft, ...}; the routed parent
      # starts the async; with no GenAI config it resolves to {:error, :missing_feature_config},
      # delivered back to the (matching) modal as the not-configured message.
      view |> element("button[phx-click='generate_draft']") |> render_click()

      _ = render_async(view, 2_000)
      assert render(view) =~ "AI email generation is not configured for this course."
    end

    @tag capture_log: true
    test "a crashed draft task is delivered as an error to the matching modal", %{conn: conn} do
      {:ok, view, _html} = live_component_isolated(conn, DraftEmailModal, base_attrs())

      route_handle_async_to_production(view)
      rid = arm_request_id(view)

      Driver.run(view, fn socket ->
        {:reply, :ok, start_async(socket, {:draft, @component_id, rid}, fn -> raise "boom" end)}
      end)

      _ = render_async(view, 2_000)
      assert render(view) =~ "Draft generation failed. Please try again."
    end

    test "cancelling an in-flight draft (modal close) surfaces no error", %{conn: conn} do
      {:ok, view, _html} = live_component_isolated(conn, DraftEmailModal, base_attrs())

      route_handle_async_to_production(view)
      rid = arm_request_id(view)

      Driver.run(view, fn socket ->
        {:reply, :ok,
         start_async(socket, {:draft, @component_id, rid}, fn -> Process.sleep(:infinity) end)}
      end)

      # cancel_async surfaces as {:exit, {:shutdown, :cancel}}, which the ignore clause drops.
      Driver.run(view, fn socket ->
        {:noreply, socket} =
          InstructorDashboardLive.handle_info({:cancel_draft, @component_id, rid}, socket)

        {:reply, :ok, socket}
      end)

      _ = render_async(view, 2_000)
      refute render(view) =~ "Draft generation failed. Please try again."
    end

    test "cancelling an unknown request id is a no-op", %{conn: conn} do
      {:ok, view, _html} = live_component_isolated(conn, DraftEmailModal, base_attrs())

      Driver.run(view, fn socket ->
        {:noreply, socket} =
          InstructorDashboardLive.handle_info({:cancel_draft, @component_id, 999_999}, socket)

        {:reply, :ok, socket}
      end)

      refute render(view) =~ "Draft generation failed. Please try again."
    end
  end

  # Routes the Driver's async results through the real production handle_async/3.
  defp route_handle_async_to_production(view) do
    Driver.run(view, fn socket ->
      socket =
        Phoenix.LiveView.attach_hook(socket, :draft_async, :handle_async, fn key,
                                                                             result,
                                                                             socket ->
          {:noreply, socket} = InstructorDashboardLive.handle_async(key, result, socket)
          {:halt, socket}
        end)

      {:reply, :ok, socket}
    end)
  end

  # Routes the component's {:generate_draft, ...} / {:cancel_draft, ...} to the real parent handler.
  defp route_handle_info_to_production(view) do
    Driver.run(view, fn socket ->
      socket =
        Phoenix.LiveView.attach_hook(socket, :draft_info, :handle_info, fn
          {:generate_draft, _, _, _, _} = msg, socket ->
            {:noreply, socket} = InstructorDashboardLive.handle_info(msg, socket)
            {:halt, socket}

          {:cancel_draft, _, _} = msg, socket ->
            {:noreply, socket} = InstructorDashboardLive.handle_info(msg, socket)
            {:halt, socket}

          _other, socket ->
            {:cont, socket}
        end)

      {:reply, :ok, socket}
    end)
  end

  # Triggers the component's generate event so it mints + stores a draft_request_id (which a
  # directly-started async must match to be applied). The generate message is intercepted/halted
  # so no real parent async runs; returns the captured request id.
  defp arm_request_id(view) do
    test_pid = self()

    live_component_intercept(view, fn
      {:generate_draft, _id, _prev, rid, _ctx}, socket ->
        send(test_pid, {:captured_rid, rid})
        {:halt, socket}

      _other, socket ->
        {:cont, socket}
    end)

    view |> element("button[phx-click='generate_draft']") |> render_click()
    assert_receive {:captured_rid, rid}
    rid
  end

  defp base_attrs do
    %{
      id: @component_id,
      students: [
        %{
          id: 1,
          display_name: "Student 1",
          given_name: "Student",
          family_name: "One",
          email: "student1@example.edu"
        }
      ],
      section_id: 1,
      section_title: "Demo Section",
      instructor_email: "instructor@example.edu",
      instructor_name: "Instructor Example",
      scope_label: "All students",
      situation_key: :struggling_students,
      show_modal: true,
      email_handler_id: "draft_async_test"
    }
  end
end
