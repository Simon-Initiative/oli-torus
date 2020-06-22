defmodule OliWeb.Objectives.ObjectiveEntry do

  @moduledoc """
  Curriculum item entry component.
  """

  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias OliWeb.Objectives.ObjectiveRender

  def render(assigns) do

    ~L"""
    <div
      tabindex="0"
      id="<%= @objective_mapping.resource.id %>"
      phx-keydown="keydown"
      phx-click="select"
      phx-value-slug="<%= @objective_mapping.revision.slug %>"
      class="my-1 list-group-item d-flex align-items-start
      <%= if @selected == @objective_mapping.revision.slug do
             "list-group-item-secondary"
          end
      %>"
    >
    <div class="w-100">
    <%= cond do
         @edit == @objective_mapping.revision.slug ->
           live_component @socket, ObjectiveRender, changeset: @changeset, objective_mapping: @objective_mapping, children: @children,
            project: @project, form_id: "edit-objective", place_holder: @objective_mapping.revision.title,
            phx_disable_with: "Updating Objective...", button_text: "Save", parent_slug_value: "",
            title_value: @objective_mapping.revision.title, selected: @selected, edit: @edit, method: "edit", mode: :edit
         @edit == "add_sub_" <> @objective_mapping.revision.slug ->
            live_component @socket, ObjectiveRender, changeset: @changeset, objective_mapping: @objective_mapping, children: @children,
            project: @project, form_id: "create-sub-objective", place_holder: "New Sub-Objective", title_value: "",
            phx_disable_with: "Adding Sub-Objective...", button_text: "Add", selected: @selected, edit: @edit, method: "new",
            parent_slug_value: @objective_mapping.revision.slug, mode: :add_sub_objective
         true ->
            live_component @socket, ObjectiveRender, changeset: @changeset, objective_mapping: @objective_mapping, children: @children,
            project: @project, mode: :show, selected: @selected, edit: @edit
    end %>
    </div>
    <div style="min-width: 50px">
      <div style="<%= if @selected == @objective_mapping.revision.slug do
             "display: flex;"
          else
             "display: none;"
          end
      %>">
        <button
          id=<%= "edit_#{@objective_mapping.resource.id}" %>
          title="Edit"
          class="ml-1 btn btn-sm btn-outline-primary"
          phx-click="modify"
          phx-value-slug="<%= @objective_mapping.revision.slug %>"
         >
         <i class="fas fa-pencil-alt fa-lg"></i>
        </button>
        <%= if @depth < 2 do %>
       <button
          id=<%= "add_#{@objective_mapping.resource.id}" %>
          title="Add"
          class="ml-1 btn btn-sm btn-outline-primary"
          phx-click="modify"
          phx-value-slug=<%= "add_sub_#{@objective_mapping.revision.slug}" %>
         >
         <i class="fas fa-plus fa-lg"></i>
        </button>
        <% end %>
        <button
          id=<%= "delete_#{@objective_mapping.resource.id}" %>
          title="Delete"
          class="ml-1 btn btn-sm btn-outline-danger" data-toggle="modal" data-target="#exampleModalCenter"
         >
         <i class="fas fa-trash fa-lg"></i>
        </button>
      </div>
      </div>
    </div>
    """
  end
end
