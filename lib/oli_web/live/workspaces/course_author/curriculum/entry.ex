defmodule OliWeb.Workspaces.CourseAuthor.Curriculum.Entry do
  @moduledoc """
  Curriculum item entry component.
  """
  use OliWeb, :html

  import OliWeb.Curriculum.Utils

  alias OliWeb.Curriculum.{Actions, Details, LearningSummary}
  alias Oli.Resources.Numbering
  alias Oli.Resources.ResourceType

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
  attr(:revision_history_link, :boolean, default: false)
  attr(:sidebar_expanded, :boolean)

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
          {entry_icon(assigns)}
          <%= if Oli.Resources.ResourceType.get_type_by_id(@child.resource_type_id) == "container" do %>
            {container_link(@child, @project, @numberings, "ml-1 mr-1 entry-title")}
          <% else %>
            <span class="ml-1 mr-1 entry-title">{@child.title}</span>
            <.edit_link
              project_slug={@project.slug}
              child={@child}
              sidebar_expanded={@sidebar_expanded}
            />
          <% end %>
          <span :if={@editor} class="badge">
            {Map.get(@editor, :name) || "Someone"} is editing this
          </span>
        </div>

        <div>
          <%= case @view do %>
            <% "Detailed" -> %>
              <Details.render child={@child} ctx={@ctx} />
            <% "Learning Summary" -> %>
              <LearningSummary.render
                child={@child}
                activity_ids={@activity_ids}
                activity_map={@activity_map}
                objective_map={@objective_map}
              />
            <% _ -> %>
          <% end %>
        </div>
      </div>
      <!-- prevent dragging of actions menu and modals using this draggable wrapper -->
      <div draggable="true" ondragstart="event.preventDefault(); event.stopPropagation();">
        <Actions.render
          child={@child}
          revision_history_link={@revision_history_link}
          project_slug={@project.slug}
        />
      </div>
    </div>
    """
  end

  attr(:project_slug, :string, required: true)
  attr(:child, :map, required: true)
  attr(:sidebar_expanded, :boolean, required: true)

  def edit_link(%{child: child} = assigns) do
    if ResourceType.is_adaptive_page(child) do
      ~H"""
      <.link
        class="entry-title mx-3"
        href={
          ~p"/workspaces/course_author/#{@project_slug}/curriculum/#{@child.slug}/edit?sidebar_expanded=#{@sidebar_expanded}"
        }
      >
        Edit Page
      </.link>
      """
    else
      ~H"""
      <.link
        class="entry-title mx-3"
        navigate={
          ~p"/workspaces/course_author/#{@project_slug}/curriculum/#{@child.slug}/edit?sidebar_expanded=#{@sidebar_expanded}"
        }
      >
        Edit Page
      </.link>
      """
    end
  end

  def entry_icon(%{child: child} = assigns) do
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

  defp container_link(revision, project, numberings, class) do
    path = ~p"/workspaces/course_author/#{project.slug}/curriculum/#{revision.slug}"
    numbering = Map.get(numberings, revision.id)

    title =
      if numbering do
        Numbering.prefix(numbering) <> ": " <> revision.title
      else
        revision.title
      end

    assigns = %{path: path, class: class, title: title}

    ~H"""
    <.link navigate={@path} class={@class}>{@title}</.link>
    """
  end
end
