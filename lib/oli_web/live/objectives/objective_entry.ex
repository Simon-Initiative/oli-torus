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
                children: [], depth: @depth + 1, project: @project, can_delete?: @can_delete?, edit: @edit %>
       <% end %>

       <%= if Enum.count(@children) > 0 do %>
        <div class="row create-sub-objective py-1">
          <div class="col-12 pb-2">
            <div style="margin-left: <%= @depth * 20 %>px">
              <button
                class="ml-1 btn btn-xs btn-light"
                phx-click="add_sub"
                phx-value-slug="add_sub_<%= @objective_mapping.revision.slug %>">
                <i class="fas fa-plus fa-lg"></i> Add
              </button>

            </div>
          </div>
        </div>
       <% end %>
    """
  end

  def render(assigns) do

    margin_for_depth = (assigns.depth - 1) * 20

    ~L"""

    <div class="row objective py-1" tabindex="0">
      <div class="col-12">
        <div style="margin-left: <%= margin_for_depth %>px">

        <% IO.inspect {@edit, @objective_mapping.revision.slug} %>

        <%= cond do
          @edit == @objective_mapping.revision.slug ->
            live_component @socket, ObjectiveRender, changeset: @changeset, objective_mapping: @objective_mapping, children: @children,
            project: @project, slug: @objective_mapping.revision.slug, form_id: "edit-objective", place_holder: @objective_mapping.revision.title,
            phx_disable_with: "Updating Objective...", button_text: "Save", parent_slug_value: "", depth: @depth,
            title_value: @objective_mapping.revision.title, can_delete?: @can_delete?,
            edit: @edit, method: "edit", mode: :edit
          @edit == "add_sub_" <> @objective_mapping.revision.slug ->
            live_component @socket, ObjectiveRender, changeset: @changeset, objective_mapping: @objective_mapping, children: @children,
            project: @project, slug: @objective_mapping.revision.slug, form_id: "create-sub-objective", place_holder: "New Sub-Objective", title_value: "",
            phx_disable_with: "Adding Sub-Objective...", button_text: "Add", edit: @edit, method: "new",
            parent_slug_value: @objective_mapping.revision.slug, depth: @depth, mode: :add_sub_objective
          true ->
            live_component @socket, ObjectiveRender, changeset: @changeset, objective_mapping: @objective_mapping, children: @children,
            project: @project, slug: @objective_mapping.revision.slug, depth: @depth, mode: :show, can_delete?: @can_delete?, edit: @edit
        end %>

        </div>
      </div>
    </div>

    <%= render_children(assigns) %>
    """
  end
end
