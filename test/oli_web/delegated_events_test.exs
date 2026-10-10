defmodule OliWeb.DelegatedEventsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import OliWeb.DelegatedEvents

  alias Phoenix.LiveComponent.CID
  alias Phoenix.LiveView.Socket

  describe "delegate_to/2" do
    test "returns {:noreply, socket} and logs a warning when no delegate handles the event" do
      socket = %Socket{view: OliWeb.DelegatedEventsTest.SomeView}

      log =
        capture_log(fn ->
          assert {:noreply, ^socket} =
                   delegate_to(
                     {"unknown_event", %{"a" => 1}, socket, &patch_fn/2},
                     [&not_handled/4, &not_handled/4]
                   )
        end)

      assert log =~ "unknown_event"
      assert log =~ "OliWeb.DelegatedEventsTest.SomeView"
    end

    test "the warning names the view and the event, never the event's payload" do
      socket = %Socket{view: OliWeb.DelegatedEventsTest.SomeView}
      params = %{"email" => "private-student@example.test", "token" => "payload-secret"}

      log =
        capture_log(fn ->
          delegate_to({"stale_event", params, socket, &patch_fn/2}, [&not_handled/4])
        end)

      assert log =~ ~s|Unhandled event in OliWeb.DelegatedEventsTest.SomeView: "stale_event"|
      refute log =~ "private-student@example.test"
      refute log =~ "payload-secret"
    end

    test "inside a live component the warning also names the component by its id" do
      socket = %Socket{
        view: OliWeb.DelegatedEventsTest.SomeView,
        assigns: %{__changed__: %{}, id: "enrollment-picker", myself: %CID{cid: 3}}
      }

      log =
        capture_log(fn ->
          delegate_to({"stale_event", %{}, socket, &patch_fn/2}, [&not_handled/4])
        end)

      assert log =~
               ~s|Unhandled event in OliWeb.DelegatedEventsTest.SomeView (component "enrollment-picker"): "stale_event"|
    end

    test "returns the result of the first delegate that handles the event, without logging" do
      socket = %Socket{view: OliWeb.DelegatedEventsTest.SomeView}

      log =
        capture_log(fn ->
          assert {:noreply, %Socket{assigns: %{handled_by: :second}}} =
                   delegate_to(
                     {"known_event", %{"a" => 1}, socket, &patch_fn/2},
                     [&not_handled/4, &handles_known_event/4]
                   )
        end)

      refute log =~ "known_event"
    end
  end

  defp not_handled(_event, _params, _socket, _patch_fn), do: :not_handled

  defp handles_known_event("known_event", %{"a" => 1}, socket, patch_fn),
    do: patch_fn.(socket, %{handled_by: :second})

  defp patch_fn(socket, params), do: {:noreply, %{socket | assigns: params}}
end
