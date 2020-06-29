defmodule OliWeb.Objectives.ObjectiveRender do

  @moduledoc """
  Curriculum item entry component.
  """

  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias OliWeb.Objectives.ObjectiveForm
  alias OliWeb.Objectives.ObjectiveEntry

  def render(assigns) do

    ~L"""
    <%= cond do %>
    <% @mode == :show -> %>
    <div class="pt-1 mb-1"><%= @objective_mapping.revision.title %></div>
    <%= if length(@children) != 0 do  %>
    <div class="list-group list-group-flush w-100">
       <%= for child <- @children do %>
          <%= live_component @socket, ObjectiveEntry, changeset: @changeset, objective_mapping: child.mapping,
                children: [], depth: 2, project: @project, selected: @selected, edit: @edit %>
       <% end %>
    </div>
    <% end %>
    <% @mode == :add_sub_objective -> %>
    <div class="pt-1 mb-1"><span class="mr-1"><i class="fas fa-crosshairs fa-lg"></i></span><%= @objective_mapping.revision.title %></div>
     <%= live_component @socket, ObjectiveForm, changeset: @changeset,
                 project: @project, title_value: @title_value, slug_value: "", parent_slug_value: @parent_slug_value,
                 form_id: @form_id, place_holder: @place_holder, phx_disable_with: @phx_disable_with, button_text: @button_text, method: @method %>
    <%= if length(@children) != 0 do  %>
    <div class="list-group list-group-flush w-100">
         <%= for child <- @children do %>
          <%= live_component @socket, ObjectiveEntry, changeset: @changeset,objective_mapping: child.mapping,
               children: [], depth: 2, project: @project, selected: @selected, edit: @edit %>
       <% end %>
     </div>
     <% end %>
    <% @mode == :edit -> %>
      <%= live_component @socket, ObjectiveForm, changeset: @changeset,
                 project: @project, title_value: @title_value, slug_value: @objective_mapping.revision.slug, parent_slug_value: @parent_slug_value,
                 form_id: @form_id, place_holder: @place_holder, phx_disable_with: @phx_disable_with, button_text: @button_text, method: @method %>
    <%= if length(@children) != 0 do  %>
     <div class="list-group list-group-flush w-100">
        <%= for child <- @children do %>
          <%= live_component @socket, ObjectiveEntry, changeset: @changeset, objective_mapping: child.mapping, children: [], depth: 2,
                 project: @project, selected: @selected, edit: @edit %>
       <% end %>
     </div>
    <% end %>
    <% true -> %>
    <%= live_component @socket, ObjectiveForm, changeset: @changeset,
                 project: @project, title_value: @title_value, slug_value: "", parent_slug_value: @parent_slug_value,
                 form_id: @form_id, place_holder: @place_holder, phx_disable_with: @phx_disable_with, button_text: @button_text, method: @method %>
    <% end %>
    """
  end
end
