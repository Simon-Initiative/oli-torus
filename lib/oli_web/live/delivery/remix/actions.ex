defmodule OliWeb.Delivery.Remix.Actions do
  @moduledoc """
  Curriculum item entry actions component.
  """

  use OliWeb, :live_component
  alias Oli.Resources.ResourceType
  alias OliWeb.Components.DesignTokens.Primitives.Button

  def render(assigns) do
    ~H"""
    <div class="entry-actions flex items-center gap-2">
      <Button.button
        :if={@show_options}
        variant={:secondary}
        size={:sm}
        class="!px-4"
        phx-click="show_options_modal"
        phx-value-uuid={@uuid}
      >
        Options
      </Button.button>
      <Button.button
        variant={:secondary}
        size={:sm}
        class="!px-4"
        phx-click="show_move_modal"
        phx-value-uuid={@uuid}
      >
        <:icon_left>
          <OliWeb.Icons.arrow_circle_right class="w-3.5 h-3.5 fill-current" />
        </:icon_left>
        Move
      </Button.button>
      <Button.button
        :if={@resource_type == ResourceType.id_for_page()}
        variant={:secondary}
        size={:sm}
        class="!px-4"
        phx-click="show_hide_resource_modal"
        phx-value-uuid={@uuid}
      >
        <:icon_left>
          <i class={"fa-solid #{if @hidden, do: "fa-eye", else: "fa-eye-slash"} text-xs"}></i>
        </:icon_left>
        {if @hidden, do: "Show", else: "Hide"}
      </Button.button>
      <Button.button
        variant={:danger}
        size={:sm}
        class="!px-4"
        phx-click={if @is_used_as_source_page, do: nil, else: "show_remove_modal"}
        phx-value-uuid={if @is_used_as_source_page, do: nil, else: @uuid}
        disabled={@is_used_as_source_page}
      >
        <:icon_left>
          <OliWeb.Icons.trash_filled class="w-3.5 h-3.5 fill-current" />
        </:icon_left>
        Remove
        <span
          :if={@is_used_as_source_page}
          class="cursor-pointer"
          data-bs-toggle="tooltip"
          data-bs-placement="top"
          title="In order to remove this page, you first need to remove the gating condition associated with it."
        >
          <OliWeb.Icons.circle_exclamation />
        </span>
      </Button.button>
    </div>
    """
  end
end
