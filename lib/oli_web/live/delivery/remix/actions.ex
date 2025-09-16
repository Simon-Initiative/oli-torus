defmodule OliWeb.Delivery.Remix.Actions do
  @moduledoc """
  Curriculum item entry actions component.
  """

  use OliWeb, :live_component
  alias Oli.Resources.ResourceType

  def render(assigns) do
    ~H"""
    <div class="entry-actions">
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
        class="btn btn-danger btn-sm ml-2"
        phx-click="show_remove_modal"
        phx-value-uuid={@uuid}
      >
        <i class="far fa-trash-alt"></i> Remove
      </button>
    </div>
    """
  end
end
