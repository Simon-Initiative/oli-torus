defmodule OliWeb.Objectives.ObjectiveEntry do

  @moduledoc """
  Curriculum item entry component.
  """

  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias OliWeb.Objectives.ObjectiveRender
  alias OliWeb.Objectives.ObjectiveEntry

  defp render_children(assigns) do
    ~L"""
       <%= for child <- @children do %>
          <%= live_component @socket, ObjectiveEntry, changeset: @changeset, objective_mapping: child.mapping,
                children: [], depth: 2, project: @project, selected: @selected, edit: @edit %>
       <% end %>
    """
  end

  def render(assigns) do

    margin_for_depth = assigns.depth * 20

    ~L"""

    <div class="row">
      <div class="col-12">

        <div
          tabindex="0"
          id="<%= @objective_mapping.resource.id %>"
          phx-keydown="keydown"
          phx-click="select"
          phx-value-slug="<%= @objective_mapping.revision.slug %>"
          style="margin-left: <%= margin_for_depth %>px"
          class="my-1"
        >

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
      </div>
    </div>

    <%= render_children(assigns) %>
    """
  end
end
