defmodule OliWeb.Curriculum.Actions do
  @moduledoc """
  Curriculum item entry actions component.
  """

  use OliWeb, :html

  alias Oli.ScopedFeatureFlags
  alias Oli.Accounts.Author
  alias Oli.Resources.ResourceType
  alias OliWeb.Icons
  alias OliWeb.Router.Helpers, as: Routes
  alias Phoenix.LiveView.JS

  attr(:child, :map, required: true)
  attr(:project, :map, required: true)
  attr(:revision_history_link, :boolean, default: false)
  attr(:current_author, :any, default: nil)

  def render(assigns) do
    ~H"""
    <div class="entry-actions">
      <div class="dropdown">
        <button
          class="btn dropdown-toggle"
          type="button"
          aria-label="Options"
          title="Options"
          phx-click={JS.toggle(to: "#dropdownMenu_#{@child.slug}")}
        >
          <Icons.vertical_dots class="text-gray-700 dark:text-gray-100" />
        </button>
        <div
          class="hidden dropdown-menu right-0"
          id={"dropdownMenu_#{@child.slug}"}
          phx-click-away={JS.toggle(to: "#dropdownMenu_#{@child.slug}")}
          aria-labelledby={"dropdownMenuButton_#{@child.slug}"}
        >
          <button
            type="button"
            class="dropdown-item"
            phx-click={push_event_and_hide_dropdown("show_options_modal", @child.slug)}
            role="show_options_modal"
            phx-value-slug={@child.slug}
          >
            <i class="fas fa-sliders-h mr-1 flex-1"></i> Settings
          </button>
          <button
            type="button"
            class="dropdown-item"
            phx-click={push_event_and_hide_dropdown("show_move_modal", @child.slug)}
            role="show_move_modal"
            phx-value-slug={@child.slug}
          >
            <i class="fas fa-arrow-circle-right mr-1"></i> Move to...
          </button>
          <%= if show_duplicate_action?(@child, @project, @current_author) do %>
            <button
              type="button"
              class="dropdown-item"
              phx-click={push_event_and_hide_dropdown("duplicate_page", @child.slug)}
              role="duplicate_page"
              phx-value-id={@child.id}
            >
              <i class="fas fa-copy mr-1"></i> Duplicate
            </button>
          <% end %>
          <.link
            :if={ResourceType.is_page(@child)}
            class="dropdown-item"
            href={preview_url(@project.slug, @child)}
            target={preview_window_name(@project.slug)}
          >
            <i class="fas fa-eye mr-1"></i> Preview
          </.link>
          <div class="dropdown-divider"></div>
          <.link
            :if={@revision_history_link}
            class="dropdown-item"
            navigate={
              ~p"/workspaces/course_author/#{@project.slug}/curriculum/#{@child.slug}/history"
            }
          >
            <i class="fas fa-history mr-1"></i> View revision history
          </.link>
          <button
            type="button"
            class="dropdown-item text-danger"
            phx-click={push_event_and_hide_dropdown("show_delete_modal", @child.slug)}
            role="show_delete_modal"
            phx-value-slug={@child.slug}
          >
            <i class="far fa-trash-alt mr-1"></i> Delete
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp show_duplicate_action?(child, project, current_author) do
    ResourceType.is_non_adaptive_page(child) or
      (ResourceType.is_adaptive_page(child) and
         adaptive_duplication_available?(project, current_author))
  end

  defp adaptive_duplication_available?(project, %Author{} = author) do
    ScopedFeatureFlags.can_access?(:adaptive_duplication, author, project)
  end

  defp adaptive_duplication_available?(_project, _current_author), do: false

  defp preview_url(project_slug, child) do
    if ResourceType.is_adaptive_page(child) do
      Routes.resource_path(OliWeb.Endpoint, :preview_fullscreen, project_slug, child.slug)
    else
      Routes.resource_path(OliWeb.Endpoint, :preview, project_slug, child.slug)
    end
  end

  defp preview_window_name(project_slug), do: "preview-#{project_slug}"

  defp push_event_and_hide_dropdown(event, target_slug),
    do: JS.push(event) |> JS.toggle(to: "#dropdownMenu_#{target_slug}")
end
