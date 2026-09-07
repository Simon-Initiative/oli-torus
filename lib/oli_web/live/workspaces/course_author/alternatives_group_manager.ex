defmodule OliWeb.Workspaces.CourseAuthor.AlternativesGroupManager do
  @moduledoc """
  Shared presentation for strategy-specific Alternatives Group management.

  The owning LiveView remains responsible for authorization and persistence. This
  component deliberately exposes no strategy selector or placement-content editor.
  """

  use OliWeb, :html

  import OliWeb.Resources.AlternativesEditor.GroupOption

  attr :group, :any, required: true
  attr :item_label, :string, required: true
  attr :empty_item_label, :string, required: true
  attr :create_item_event, :string, required: true
  attr :delete_group_event, :string, required: true
  attr :editing_enabled, :boolean, default: true
  attr :heading_level, :integer, default: 4, values: [3, 4]
  slot :new_item_form

  def group_card(assigns) do
    ~H"""
    <article
      id={"alternatives-group-#{@group.resource_id}"}
      class="alternatives-group my-3 rounded border border-gray-200 bg-gray-50 p-4 dark:border-gray-700 dark:bg-neutral-800"
    >
      <header class="d-flex flex-row align-items-center gap-2">
        <h3 :if={@heading_level == 3} class="h6 mb-0 font-weight-bold">{@group.title}</h3>
        <h4 :if={@heading_level == 4} class="h6 mb-0 font-weight-bold">{@group.title}</h4>
        <div class="flex-grow-1"></div>
        <OliWeb.Common.Components.icon_button
          :if={@editing_enabled}
          class="mr-1"
          icon="fa-solid fa-pencil"
          on_click="show_edit_group_modal"
          values={["phx-value-resource-id": @group.resource_id]}
          aria_label={"Edit #{@group.title}"}
        />
        <button
          :if={@editing_enabled}
          type="button"
          class="btn btn-danger btn-sm"
          phx-click={@delete_group_event}
          phx-value-resource-id={@group.resource_id}
          aria-label={"Delete #{@group.title}"}
        >
          Delete
        </button>
      </header>
      <div class="mt-3">
        <%= if Enum.empty?(@group.content["options"]) do %>
          <div class="my-2 text-center" role="status"><em>{@empty_item_label}</em></div>
        <% else %>
          <.option_list group={@group} show_actions={@editing_enabled} />
        <% end %>
        <button
          :if={@editing_enabled and Enum.empty?(@new_item_form)}
          type="button"
          class="btn btn-link px-0 mt-3"
          phx-click={@create_item_event}
          phx-value-resource-id={@group.resource_id}
        >
          <i class="fa fa-plus" aria-hidden="true"></i> New {@item_label}
        </button>
        {render_slot(@new_item_form)}
      </div>
    </article>
    """
  end
end
