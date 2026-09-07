defmodule OliWeb.Components.ReorderableList do
  @moduledoc """
  Shared rendering and keyboard movement behavior for server-reordered lists.

  Reordering remains owned by the parent LiveView. This component provides the
  focusable drag-source contract and translates Shift+Arrow keyboard events into
  the drop indices used by the existing reorder handlers.
  """

  use OliWeb, :html

  attr :id, :string, required: true
  attr :tag, :string, default: "div"
  attr :position, :integer, required: true
  attr :count, :integer, required: true
  attr :item_key, :string, required: true
  attr :label, :string, required: true
  attr :status_id, :string, required: true
  attr :keydown, :string, required: true
  attr :enabled, :boolean, default: true
  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def item(assigns) do
    ~H"""
    <.dynamic_tag
      tag_name={@tag}
      id={@id}
      tabindex={if @enabled, do: "0"}
      draggable={to_string(@enabled)}
      phx-hook={@enabled && "DragSource"}
      phx-keydown={@enabled && @keydown}
      phx-value-position={@position}
      phx-value-count={@count}
      data-drag-index={@position}
      data-keyboard-reorder-key={@item_key}
      data-keyboard-reorder-status-id={@status_id}
      data-keyboard-reorder-label={@label}
      data-reorder-position={@position}
      data-reorder-count={@count}
      aria-keyshortcuts={@enabled && "Shift+ArrowUp Shift+ArrowDown"}
      aria-describedby={@enabled && "#{@id}-reorder-instructions #{@id}-reorder-position"}
      class={@class}
      {@rest}
    >
      {render_slot(@inner_block)}
      <span :if={@enabled} id={"#{@id}-reorder-instructions"} class="sr-only">
        Hold Shift and press the Up or Down Arrow key to move this item.
      </span>
      <span
        :if={@enabled}
        id={"#{@id}-reorder-position"}
        class="sr-only"
      >
        Item position {@position + 1} of {@count}.
      </span>
    </.dynamic_tag>
    """
  end

  attr :id, :string, required: true

  def status(assigns) do
    ~H"""
    <span id={@id} class="sr-only" aria-live="polite" aria-atomic="true"></span>
    """
  end

  @doc """
  Converts a Shift+Arrow key event into the source and destination indices used
  by the existing drag-and-drop reorder contract.
  """
  def keyboard_move(%{
        "key" => key,
        "shiftKey" => true,
        "position" => position,
        "count" => count
      })
      when key in ["ArrowUp", "ArrowDown"] do
    with {position, ""} <- Integer.parse(to_string(position)),
         {count, ""} <- Integer.parse(to_string(count)),
         true <- position >= 0 and position < count,
         {:ok, drop_index} <- drop_index(key, position, count) do
      {:move, position, drop_index}
    else
      _ -> :noop
    end
  end

  def keyboard_move(_params), do: :noop

  defp drop_index("ArrowUp", 0, _count), do: :noop
  defp drop_index("ArrowUp", position, _count), do: {:ok, position - 1}
  defp drop_index("ArrowDown", position, count) when position == count - 1, do: :noop
  defp drop_index("ArrowDown", position, _count), do: {:ok, position + 2}
end
