defmodule OliWeb.ManualGrading.Filters do
  use Surface.Component
  alias OliWeb.ManualGrading.FilterButton

  prop options, :struct, required: true
  prop selection, :boolean, required: true

  def render(assigns) do
    ~F"""
    <div style="display: inline;">
      <FilterButton selection={@selection} tooltip="Only show attempts from this same user"
        label="User" key={:user_id} active={is_active(assigns, :user_id)} clicked={"filters_changed"}/>
      <FilterButton selection={@selection} tooltip="Only show attempts for this same activity"
        label="Activity" key={:activity_id} active={is_active(assigns, :activity_id)} clicked={"filters_changed"}/>
      <FilterButton selection={@selection} tooltip="Only show attempts for this same page"
        label="Page" key={:page_id} active={is_active(assigns, :page_id)} clicked={"filters_changed"}/>
      <FilterButton selection={@selection} tooltip="Only show attempts of this same purpose"
        label="Purpose" key={:graded} active={is_active(assigns, :graded)} clicked={"filters_changed"}/>
    </div>
    """
  end

  def is_active(assigns, key), do: !(Map.get(assigns.options, key) |> is_nil)

  def handle_delegated(event, params, socket, patch_fn) do
    delegate_handle_event(event, params, socket, patch_fn)
  end

  def delegate_handle_event("filters_changed", %{"key" => key, "active" => "false"}, socket, patch_fn) do
    changes = Map.put(%{}, String.to_existing_atom(key), nil)
    patch_fn.(socket, changes)
  end

  def delegate_handle_event("filters_changed", %{"key" => key}, socket, patch_fn) do

    value = case key do
      "user_id" -> socket.assigns.attempt.user.id
      "activity_id" -> socket.assigns.attempt.resource_id
      "page_id" -> socket.assigns.attempt.page_id
      "graded" -> socket.assigns.attempt.graded
    end

    changes = Map.put(%{}, String.to_existing_atom(key), value)
    patch_fn.(socket, changes)
  end

  def delegate_handle_event(_, _, _, _) do
    :not_handled
  end
end
