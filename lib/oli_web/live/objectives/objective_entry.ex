defmodule OliWeb.Objectives.ObjectiveEntry do

  @moduledoc """
  Curriculum item entry component.
  """

  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias OliWeb.Objectives.ObjectiveRender

  def render(assigns) do

    ~L"""
    <style>
    .to-show {
    display: none;
    }

    .list-group-item:hover .to-show{
    display: flex;
    }

    .add-button-item {
    height: 20px;
    }

    .icon-font {
    font-size: larger;
    }
    </style>
    <div
      id="<%= @objective_mapping.resource.id %>"
      class="list-group-item list-group-item-action d-flex align-items-start"
      >
    <div class="w-100">
    <%= cond do
         @edit == @objective_mapping.revision.slug ->
           live_component @socket, ObjectiveRender, changeset: @changeset, objective_mapping: @objective_mapping, children: @children,
            project: @project, form_id: "edit-objective", place_holder: @objective_mapping.revision.title,
            phx_disable_with: "Updating Objective...", button_text: "Reword", parent_slug_value: "", title_value: @objective_mapping.revision.title, edit: @edit, method: "edit", mode: :edit
         @edit == "add_sub_" <> @objective_mapping.revision.slug ->
            live_component @socket, ObjectiveRender, changeset: @changeset, objective_mapping: @objective_mapping, children: @children,
            project: @project, form_id: "create-sub-objective", place_holder: "New Sub-Objective", title_value: "",
            phx_disable_with: "Adding Sub-Objective...", button_text: "Add", edit: @edit, method: "new", parent_slug_value: @objective_mapping.revision.slug, mode: :add_sub_objective
         true ->
            live_component @socket, ObjectiveRender, changeset: @changeset, objective_mapping: @objective_mapping, children: @children,
            project: @project, mode: :show, edit: @edit
    end %>
    </div>
    <div style="min-width: 50px">
      <div class="to-show">
        <button
          id=<%= "edit_#{@objective_mapping.resource.id}" %>
          class="btn btn-sm"
          phx-click="modify"
          phx-value-slug="<%= @objective_mapping.revision.slug %>"
         >
         <i class="fas fa-pencil-alt">edit</i>
        </button>
        <button
          id=<%= "delete_#{@objective_mapping.resource.id}" %>
          class="btn btn-sm"
          phx-click="delete"
          phx-value-slug="<%= @objective_mapping.revision.slug %>"
         >
         <i class="fas fa-trash">delete</i>
        </button>
        <%= if @depth < 2 do %>
       <button
          id=<%= "add_#{@objective_mapping.resource.id}" %>
          class="btn btn-sm"
          phx-click="modify"
          phx-value-slug=<%= "add_sub_#{@objective_mapping.revision.slug}" %>
         >
         <i class="fas fa-plus">add</i>
        </button>
        <% end %>
      </div>
      </div>
    </div>
    """
  end
end
