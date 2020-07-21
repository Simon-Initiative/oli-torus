defmodule OliWeb.Objectives.ObjectiveRender do

  @moduledoc """
  Curriculum item entry component.
  """

  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias OliWeb.Objectives.ObjectiveForm

  def render(assigns) do
    ~L"""
    <%= case @mode do %>
    <% :show -> %>
      <div class="p-2 mb-2 objective-title <%= if @selected == @objective_mapping.revision.slug do "objective-selected" else "" end %>"><%= @objective_mapping.revision.title %></div>

    <% :add_sub_objective -> %>
      <div class="p-2 mb-2 objetive-title <%= if @selected == @objective_mapping.revision.slug do "objective-selected" else "" end %>"><%= @objective_mapping.revision.title %></div>
      <%= live_component @socket, ObjectiveForm, changeset: @changeset,
                 project: @project, title_value: @title_value, slug_value: "", parent_slug_value: @parent_slug_value,
                 form_id: @form_id, place_holder: @place_holder, phx_disable_with: @phx_disable_with, button_text: @button_text, method: @method %>

    <% :edit -> %>
      <%= live_component @socket, ObjectiveForm, changeset: @changeset,
                 project: @project, title_value: @title_value, slug_value: @objective_mapping.revision.slug, parent_slug_value: @parent_slug_value,
                 form_id: @form_id, place_holder: @place_holder, phx_disable_with: @phx_disable_with, button_text: @button_text, method: @method %>

    <% end %>
    """
  end
end
