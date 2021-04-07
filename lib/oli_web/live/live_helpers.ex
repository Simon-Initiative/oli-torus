defmodule OliWeb.LiveHelpers do
  import Phoenix.LiveView.Helpers

  @doc """
  Renders a component inside the `OliWeb.ModalComponent` component.

  The rendered modal receives a `:return_to` option to properly update
  the URL when the modal is closed.

  ## Examples

      <%= live_modal @socket, OliWeb.TestXXLive.FormComponent,
        id: @resource.id || :new,
        action: @live_action,
        resource: @resource,
        return_to: Routes.resource_path(@socket, :index) %>
  """
  def live_modal(_, component, opts) do
    path = Keyword.fetch!(opts, :return_to)
    modal_opts = [id: :modal, return_to: path, component: component, opts: opts]

    live_component(_, OliWeb.ModalComponent, modal_opts)
  end
end
