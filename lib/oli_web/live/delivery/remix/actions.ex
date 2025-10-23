defmodule OliWeb.Delivery.Remix.Actions do
  @moduledoc """
  Curriculum item entry actions component.
  """

  use OliWeb, :live_component
  alias Oli.Resources.ResourceType

  def render(assigns) do
    ~H"""
    <div class="entry-actions flex items-center gap-2">
      <button
        type="button"
        class="btn btn-outline-primary btn-sm ml-2"
        phx-click="show_move_modal"
        phx-value-uuid={@uuid}
      >
        <i class="fas fa-arrow-circle-right"></i> Move
      </button>
      <button
        :if={@resource_type == ResourceType.id_for_page()}
        type="button"
        class="btn btn-outline-primary btn-sm ml-2"
        phx-click="show_hide_resource_modal"
        phx-value-uuid={@uuid}
      >
        <i class={"fa-solid #{if @hidden, do: "fa-eye", else: "fa-eye-slash"}"}></i> {if @hidden,
          do: "Show",
          else: "Hide"}
      </button>
      <button
        type="button"
        class={"flex flex-row items-center gap-2 btn btn-danger btn-sm ml-2 #{if @is_used_as_source_page, do: "disabled"}"}
        phx-click={if @is_used_as_source_page, do: nil, else: "show_remove_modal"}
        phx-value-uuid={if @is_used_as_source_page, do: nil, else: @uuid}
        disabled={@is_used_as_source_page}
      >
        <i class="far fa-trash-alt"></i>
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
      </button>
    </div>
    """
  end
end
