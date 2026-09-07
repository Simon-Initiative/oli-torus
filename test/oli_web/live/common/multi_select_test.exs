defmodule OliWeb.Common.MultiSelectInputTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Common.MultiSelectInput

  test "dropdown toggle has a 44 pixel minimum touch target" do
    html =
      render_component(&MultiSelectInput.render/1,
        id: "course-filter",
        placeholder: "Select courses",
        disabled: false,
        options: [],
        selected_values: %{},
        myself: nil
      )

    assert html =~
             ~s(class="flex min-h-11 min-w-11 items-center justify-center p-2" aria-label="Select courses")
  end
end
