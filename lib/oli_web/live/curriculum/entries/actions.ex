defmodule OliWeb.Curriculum.Actions do
  @moduledoc """
  Curriculum item entry actions component.
  """

  use OliWeb, :html

  alias Oli.Resources.ResourceType
  alias Phoenix.LiveView.JS

  attr(:child, :map, required: true)
  attr(:project_slug, :string)
  attr(:revision_history_link, :boolean, default: false)

  def render(assigns) do
    ~H"""
    <div class="entry-actions">
      <div class="dropdown">
        <button
          class="btn dropdown-toggle"
          type="button"
          phx-click={JS.toggle(to: "#dropdownMenu_#{@child.slug}")}
        >
          <svg
            aria-hidden="true"
            focusable="false"
            data-prefix="fas"
            data-icon="caret-down"
            class="w-2"
            role="img"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 320 512"
          >
            <path
              fill="currentColor"
              d="M31.3 192h257.3c17.8 0 26.7 21.5 14.1 34.1L174.1 354.8c-7.8 7.8-20.5 7.8-28.3 0L17.2 226.1C4.6 213.5 13.5 192 31.3 192z"
            >
            </path>
          </svg>
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
            <i class="fas fa-sliders-h mr-1 flex-1"></i> Options
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
          <%= if ResourceType.is_non_adaptive_page(@child) do %>
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
          <div class="dropdown-divider"></div>
          <.link
            :if={@revision_history_link}
            class="dropdown-item"
            navigate={
              ~p"/workspaces/course_author/#{@project_slug}/curriculum/#{@child.slug}/history"
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

  defp push_event_and_hide_dropdown(event, target_slug),
    do: JS.push(event) |> JS.toggle(to: "#dropdownMenu_#{target_slug}")
end
