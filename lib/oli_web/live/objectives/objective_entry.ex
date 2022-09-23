defmodule OliWeb.Objectives.ObjectiveEntry do
  @moduledoc """
  Curriculum item entry component.
  """

  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias OliWeb.Objectives.ObjectiveRender
  alias OliWeb.Objectives.ObjectiveEntry
  alias OliWeb.Objectives.ObjectiveForm

  defp render_children(assigns) do
    ~L"""
      <%= for child <- @children do %>
        <%= live_component ObjectiveEntry, changeset: @changeset, objective_mapping: child.mapping,
              children: [], depth: @depth + 1, project: @project, can_delete?: @can_delete?, edit: @edit %>
      <% end %>

      <%= cond do %>
        <% @edit == "add_sub_" <> @objective_mapping.revision.slug -> %>
          <% # we are in create sub-objective mode, render an ObjectiveForm for the new objective %>
          <div class="row create-sub-objective py-1">
            <div class="col-12 pb-2">
              <div style="margin-left: <%= @depth * 40 %>px">

              <%= live_component ObjectiveForm, changeset: @changeset,
                project: @project, title_value: "", slug_value: "", parent_slug_value: @objective_mapping.revision.slug, depth: @depth,
                form_id: "create-sub-objective", place_holder: "", phx_disable_with: "Creating Sub-Objective...", button_text: "Create", method: "new" %>

              </div>
            </div>
          </div>

        <% @depth < 2 -> %>
          <% # this objective has one or more children, it is a container objective and more sub-objectives can be created %>
          <div class="row py-1 d-flex">
            <button
              class="ml-5 btn btn-xs btn-light"
              phx-click="add_sub"
              phx-value-slug="add_sub_<%= @objective_mapping.revision.slug %>">
              <i class="fas fa-plus fa-lg"></i> Create new Sub-Objective
            </button>

            <button
              class="ml-2 btn btn-xs btn-light"
              phx-click="show_select_existing_sub_modal"
              phx-value-slug="<%= @objective_mapping.revision.slug %>">
              <i class="fas fa-plus fa-lg"></i> Add existing Sub-Objective
            </button>
          </div>
        <% true -> %>

      <% end %>
    """
  end

  def render(assigns) do
    margin_for_depth = (assigns.depth - 1) * 40

    ~L"""

    <div id="<%= @objective_mapping.revision.slug %>" class="row objective py-1" tabindex="0" style="margin-left: <%= margin_for_depth %>px">
      <div class="col-12">
        <%= cond do %>
          <% @edit == @objective_mapping.revision.slug -> %>
            <div class="py-2">
              <%= live_component ObjectiveRender, changeset: @changeset, objective_mapping: @objective_mapping, children: @children,
                project: @project, slug: @objective_mapping.revision.slug, form_id: "edit-objective", place_holder: @objective_mapping.revision.title,
                phx_disable_with: "Updating Objective...", button_text: "Save", parent_slug_value: "", depth: @depth,
                title_value: @objective_mapping.revision.title, can_delete?: @can_delete?,
                edit: @edit, method: "edit", mode: :edit %>
            </div>
          <% true -> %>
            <%= live_component ObjectiveRender, changeset: @changeset, objective_mapping: @objective_mapping, children: @children,
            project: @project, slug: @objective_mapping.revision.slug, depth: @depth, mode: :show, can_delete?: @can_delete?, edit: @edit %>
        <% end %>
      </div>
    </div>

    <%= render_children(assigns) %>
    """
  end
end
