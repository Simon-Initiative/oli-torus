defmodule OliWeb.Delivery.InstructorDashboard.DraftEmailAsyncTest do
  @moduledoc """
  Focused coverage of the parent LiveView's draft-generation async contract:

      handle_info({:generate_draft, id, ctx}) -> start_async({:draft, id}, ...)
        -> handle_async({:draft, id}, {:ok | :exit, _}) -> DraftEmailModal.deliver_draft_result/2
        -> send_update -> modal UI

  Uses an isolated `DraftEmailModal` harness (no instructor dashboard mount, so none of the
  dashboard's background oracle loaders run). The Driver LiveView's async results are routed
  through the REAL `InstructorDashboardLive.handle_async/3` via an attached `:handle_async` hook,
  and the REAL `handle_info/2` is invoked in the LiveView process (so `start_async` is registered
  before `render_async`, with no timing race). LiveView itself guarantees cancellation on
  navigate-away, so that is not re-tested here.
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
  alias Oli.InstructorDashboard.Email.EmailContext
  alias Oli.Repo

  @component_id "draft_async_test"

  setup do
    # A migration seeds a global :instructor_email GenAI config; remove it (rolled back with the
    # test's sandbox) so generate_draft deterministically resolves to {:error, :missing_feature_config}.
    Repo.delete_all(from(f in FeatureConfig, where: f.feature == :instructor_email))
    :ok
  end

  describe "draft generation async contract" do
    test "the full handle_info -> start_async -> handle_async chain delivers the result to the modal",
         %{conn: conn} do
      {:ok, view, _html} = live_component_isolated(conn, DraftEmailModal, base_attrs())

      route_async_through_production_handler(view)

      # Invoke the real parent handler in the LiveView process; it starts the async draft.
      # Driver.run returns only after start_async is registered, so there is no race.
      Driver.run(view, fn socket ->
        {:noreply, socket} =
          InstructorDashboardLive.handle_info(
            {:generate_draft, @component_id, email_context()},
            socket
          )

        {:reply, :ok, socket}
      end)

      # With no GenAI config, generate_draft returns {:error, :missing_feature_config};
      # handle_async({:ok, that}) delivers it and the modal surfaces the not-configured message.
      # Await the async task, then render again to flush the deliver_draft_result send_update.
      _ = render_async(view, 2_000)
      assert render(view) =~ "AI email generation is not configured for this course."
    end

    @tag capture_log: true
    test "a crashed draft task is delivered to the modal as an error via handle_async({:exit, _})",
         %{conn: conn} do
      {:ok, view, _html} = live_component_isolated(conn, DraftEmailModal, base_attrs())

      route_async_through_production_handler(view)

      Driver.run(view, fn socket ->
        {:reply, :ok, start_async(socket, {:draft, @component_id}, fn -> raise "boom" end)}
      end)

      # The crash arrives as {:exit, reason}; handle_async delivers {:error, reason} and the
      # modal renders the generic generation-failure message. Await the task, then render again
      # to flush the deliver_draft_result send_update.
      _ = render_async(view, 2_000)
      assert render(view) =~ "Draft generation failed. Please try again."
    end

    test "cancelling an in-flight draft (modal close) surfaces no error in the modal", %{
      conn: conn
    } do
      {:ok, view, _html} = live_component_isolated(conn, DraftEmailModal, base_attrs())

      route_async_through_production_handler(view)

      # A long-running draft we will cancel before it can complete.
      Driver.run(view, fn socket ->
        {:reply, :ok,
         start_async(socket, {:draft, @component_id}, fn -> Process.sleep(:infinity) end)}
      end)

      # The real close-time handler cancels it; cancellation arrives at handle_async as
      # {:exit, {:shutdown, :cancel}} and must be ignored (no error delivered to the modal).
      Driver.run(view, fn socket ->
        {:noreply, socket} =
          InstructorDashboardLive.handle_info({:cancel_draft, @component_id}, socket)

        {:reply, :ok, socket}
      end)

      _ = render_async(view, 2_000)
      refute render(view) =~ "Draft generation failed. Please try again."
    end

    test "cancelling an unknown draft id is a no-op", %{conn: conn} do
      {:ok, view, _html} = live_component_isolated(conn, DraftEmailModal, base_attrs())

      Driver.run(view, fn socket ->
        {:noreply, socket} =
          InstructorDashboardLive.handle_info({:cancel_draft, "no_such_component"}, socket)

        {:reply, :ok, socket}
      end)

      # LiveView remains functional; nothing delivered to the modal.
      refute render(view) =~ "Draft generation failed. Please try again."
    end
  end

  # Attaches a :handle_async hook on the Driver LiveView that forwards async results to the
  # real production handler, so the test exercises InstructorDashboardLive.handle_async/3.
  defp route_async_through_production_handler(view) do
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

  # section_id 1 has no instructor_email config (deleted in setup) → deterministic
  # {:error, :missing_feature_config} from generate_draft.
  defp email_context do
    %EmailContext{
      section_id: 1,
      course_title: "Test Course",
      instructor_name: "Instructor",
      scope_label: "All students",
      situation_key: :struggling_students,
      recipients: [],
      recipient_count: 0,
      tone: :neutral
    }
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
