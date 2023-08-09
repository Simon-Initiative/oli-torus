defmodule OliWeb.Curriculum.EntryLive do
  @moduledoc """
  Curriculum item entry component.
  """
  use Phoenix.LiveComponent

  import OliWeb.Curriculum.Utils

  alias OliWeb.Curriculum.{Actions, DetailsLive, LearningSummaryLive}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Links

  attr(:ctx, :map, required: true)
  attr(:child, :map, required: true)
  attr(:index, :integer, required: true)
  attr(:selected, :boolean, required: true)
  attr(:project, :map, required: true)
  attr(:numberings, :map, required: true)
  attr(:editor, :map, required: true)
  attr(:activity_ids, :list, required: true)
  attr(:activity_map, :map, required: true)
  attr(:author, :map, required: true)
  attr(:container, :map, required: true)
  attr(:objective_map, :map, required: true)
  attr(:view, :string, required: true)

  def render(assigns) do
    ~H"""
    <div
      tabindex="0"
      phx-keydown="keydown"
      id={"#{@child.resource_id}"}
      draggable="true"
      phx-click="select"
      phx-value-slug={@child.slug}
      phx-value-index={@index}
      data-drag-index={@index}
      data-drag-slug={@child.slug}
      phx-hook="DragSource"
      class={"p-3 flex-grow-1 d-flex curriculum-entry #{if @selected do
          "active"
        else
          ""
        end}"}
    >
      <div class="flex-grow-1 d-flex flex-column self-center">
        <div class="flex-1">
          <%= icon(assigns) %>
          <%= if Oli.Resources.ResourceType.get_type_by_id(@child.resource_type_id) == "container" do %>
            <%= Links.resource_link(@child, [], @project, @numberings, "ml-1 mr-1 entry-title") %>
          <% else %>
            <span class="ml-1 mr-1 entry-title"><%= @child.title %></span>
            <.link
              class="entry-title mx-3"
              to={
                Routes.resource_path(
                  OliWeb.Endpoint,
                  :edit,
                  @project.slug,
                  @child.slug
                )
              }
            >
              Edit Page
            </.link>
          <% end %>
          <span :if={@editor} class="badge">
            <%= Map.get(@editor, :name) || "Someone" %> is editing this
          </span>
        </div>

        <div>
          <%= case @view do %>
            <% "Detailed" -> %>
              <%= live_component(DetailsLive, assigns) %>
            <% "Learning Summary" -> %>
              <%= live_component(LearningSummaryLive, assigns) %>
            <% _ -> %>
          <% end %>
        </div>
      </div>
      <!-- prevent dragging of actions menu and modals using this draggable wrapper -->
      <div draggable="true" ondragstart="event.preventDefault(); event.stopPropagation();">
        <%= live_component(Actions, assigns) %>
      </div>
    </div>
    """
  end

  def icon(%{child: child} = assigns) do
    if is_container?(child) do
      ~H"""
      <i class="fa fa-archive fa-lg mx-2 text-gray-700 dark:text-gray-100"></i>
      """
    else
      if child.graded do
        ~H"""
        <i class="fa-solid fa-file-pen fa-lg mx-2 text-gray-700 dark:text-gray-100"></i>
        """
      else
        ~H"""
        <i class="fa-solid fa-file-lines fa-lg mx-2 text-gray-700 dark:text-gray-100"></i>
        """
      end
    end
  end
end
