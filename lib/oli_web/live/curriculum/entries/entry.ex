defmodule OliWeb.Curriculum.EntryLive do
  @moduledoc """
  Curriculum item entry component.
  """
  use Surface.LiveComponent

  import OliWeb.Curriculum.Utils

  alias OliWeb.Curriculum.{Actions, DetailsLive, LearningSummaryLive}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Links
  alias Surface.Components.Link

  prop child, :struct, required: true
  prop index, :integer, required: true
  prop selected, :boolean, required: true
  prop project, :struct, required: true
  prop numberings, :struct, required: true
  prop editor, :struct, required: true
  prop activity_ids, :list, required: true
  prop activity_map, :map, required: true
  prop author, :struct, required: true
  prop container, :struct, required: true
  prop context, :struct, required: true
  prop objective_map, :map, required: true
  prop view, :string, required: true

  def render(assigns) do
    ~F"""
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
          {icon(assigns)}
          {#if Oli.Resources.ResourceType.get_type_by_id(@child.resource_type_id) == "container"}
            {Links.resource_link(@child, [], @project, @numberings, "ml-1 mr-1 entry-title")}
          {#else}
            <span class="ml-1 mr-1 entry-title">{@child.title}</span>
            <Link
              class="entry-title mx-3"
              to={Routes.resource_path(
                OliWeb.Endpoint,
                :edit,
                @project.slug,
                @child.slug
              )}
              label="Edit Page"
            />
          {/if}
          {#if @editor}
            <span class="badge">
              {Map.get(@editor, :name) || "Someone"} is editing this
            </span>
          {/if}
        </div>
        <div>
          {#case @view}
            {#match "Detailed"}
              {live_component(DetailsLive, assigns)}
            {#match "Learning Summary"}
              {live_component(LearningSummaryLive, assigns)}
            {#match _}
              {nil}
          {/case}
        </div>
      </div>

      <!-- prevent dragging of actions menu and modals using this draggable wrapper -->
      <div draggable="true" ondragstart="event.preventDefault(); event.stopPropagation();">
        {live_component(Actions, assigns)}
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
