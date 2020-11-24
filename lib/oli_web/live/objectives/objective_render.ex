defmodule OliWeb.Objectives.ObjectiveRender do

  @moduledoc """
  Curriculum item entry component.
  """

  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias OliWeb.Objectives.ObjectiveForm
  alias OliWeb.Objectives.Actions

  def render(assigns) do
    ~L"""
    <%= case @mode do %>
    <% :show -> %>
      <div class="d-flex flex-row">
        <div class="p-2 mb-2 flex-grow-1 objective-title"><%= @objective_mapping.revision.title %></div>
        <%= live_component @socket, Actions, slug: @slug, has_children: Enum.count(@objective_mapping.revision.children) > 0,
          can_delete?: @can_delete?, depth: @depth %>
      </div>

    <% :edit -> %>
      <%= live_component @socket, ObjectiveForm, changeset: @changeset,
          project: @project, title_value: @title_value, slug_value: @objective_mapping.revision.slug, parent_slug_value: @parent_slug_value, depth: @depth,
          form_id: @form_id, place_holder: @place_holder, phx_disable_with: @phx_disable_with, button_text: @button_text, method: @method %>

    <% end %>
    """
  end
end
