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

    assert html =~
             ~s(id="alternatives-option-123-option-a" class="list-group-item cursor-grab active:cursor-grabbing" draggable="true" phx-hook="DragSource")

    {handle_position, _} = :binary.match(html, "fa-grip-vertical")
    {name_position, _} = :binary.match(html, "Option A")

    assert handle_position < name_position
    assert html =~ "text-gray-300 dark:text-gray-600"
    assert html =~ "drop-target alternatives-option-drop-target"
    refute html =~ "fa-arrow-up"
    refute html =~ "fa-arrow-down"
  end
end
