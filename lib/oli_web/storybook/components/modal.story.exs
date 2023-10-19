defmodule OliWeb.Storybook.ModalExample do
  use PhoenixStorybook.Story, :example
  use Phoenix.Component

  import OliWeb.Components.Common
  import OliWeb.Components.Modal

  alias Phoenix.LiveView.JS

  def doc, do: "Modal example"

  @impl true
  def mount(_, _, socket), do: {:ok, socket}

  @impl true
  def render(assigns) do
    ~H"""
      <div>
        <.button variant={:primary} phx-click={show_modal(%JS{}, "confirm-modal")}>Show modal</.button>

        <.modal id="confirm-modal">
          <:title>Example</:title>
          Here is an example modal.
          <:confirm>OK</:confirm>
          <:cancel>Cancel</:cancel>
        </.modal>
      </div>
    """
  end
end
