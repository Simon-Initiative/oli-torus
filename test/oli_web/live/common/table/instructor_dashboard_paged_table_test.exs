defmodule OliWeb.Common.InstructorDashboardPagedTableTest do
  use ExUnit.Case, async: true

  alias OliWeb.Common.InstructorDashboardPagedTable
  alias Phoenix.LiveView.Socket

  describe "handle_delegated/4" do
    test "returns :not_handled for an event the table does not own" do
      patch_fn = fn _socket, _params -> flunk("patch_fn must not be called") end

      assert :not_handled ==
               InstructorDashboardPagedTable.handle_delegated(
                 "unknown_event",
                 %{"a" => 1},
                 %Socket{},
                 patch_fn
               )
    end
  end
end
