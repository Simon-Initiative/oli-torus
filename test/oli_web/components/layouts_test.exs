defmodule OliWeb.LayoutsTest do
  use OliWeb.ConnCase, async: true

  test "module loads and templates are embedded" do
    assert Code.ensure_loaded?(OliWeb.Layouts)
    assert function_exported?(OliWeb.Layouts, :__info__, 1)
  end
end
