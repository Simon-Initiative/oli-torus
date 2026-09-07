defmodule OliWeb.Resources.AlternativesEditor.GroupOptionTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Resources.AlternativesEditor.GroupOption

  test "read-only option lists do not render drag controls or drop targets" do
    group = %{
      resource_id: 123,
      content: %{"options" => [%{"id" => "option-a", "name" => "Option A"}]}
    }

    html =
      render_component(&GroupOption.option_list/1,
        group: group,
        show_actions: false
      )

    refute html =~ "phx-hook=\"DragSource\""
    refute html =~ "phx-hook=\"DropTarget\""
    assert html =~ "Option A"
  end

  test "editable option rows are fully draggable with a subtle leading handle" do
    group = %{
      resource_id: 123,
      content: %{"options" => [%{"id" => "option-a", "name" => "Option A"}]}
    }

    html = render_component(&GroupOption.option_list/1, group: group)

    assert html =~ ~s(id="alternatives-options-123" class="flex flex-col gap-0")
    assert html =~ ~s(id="alternatives-option-123-option-a")
    assert html =~ ~s(draggable="true")
    assert html =~ ~s(phx-hook="DragSource")
    assert html =~ "border-gray-200 bg-white"
    refute html =~ "list-group"
    refute html =~ "curriculum-entry"
    refute html =~ "dropdown-toggle"

    {handle_position, _} = :binary.match(html, "fa-grip-vertical")
    {name_position, _} = :binary.match(html, ">Option A</div>")

    assert handle_position < name_position
    assert html =~ "text-gray-300 dark:text-gray-600"
    assert html =~ "drop-target alternatives-option-drop-target"
    assert html =~ ~s(aria-label="Options for Option A")
    assert html =~ ~s(title="Options for Option A")
    refute html =~ "fa-arrow-up"
    refute html =~ "fa-arrow-down"
  end
end
