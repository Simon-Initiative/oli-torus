defmodule OliWeb.Common.Modal do
  @moduledoc """
  A Phoenix LiveView compliant Bootstrap modal implementation.

  Usage:

  1. In your LiveView, use this module:
  ```
  use OliWeb.Common.Modal
  ```

  2. Add `render_modal(assigns)` to the rendered output:
  ```
  def render(assigns) do
    ...
    <%= render_modal(assigns) %>
    ...
  end
  ```

  3. Create your modal by defining a modal functional component and then
  calling 'show_modal' with the socket, component and any additional assigns.
  ```

  def handle_event("show_modal", _, socket) do

    modal_assigns = %{
      id: "my_modal",
      message: "Hello from Modal",
      on_confirm: "some_confirm_action"
    }

    modal = fn assigns ->
      ~H\"\"\"
        <div>
          <%= @modal_assigns.message %>
          <button phx-click={@modal_assigns.on_confirm}>Ok</button>
        </div>
      \"\"\"
    end

    {:noreply, assign(socket, modal, modal_assigns: modal_assigns)}
  end
  ```

  4. Dismiss modal using bootstrap javascript (data-bs-dismiss="modal", escape key, etc...)
  or using the `hide_modal(socket, assigns)` function. Hide modal can optionally take any
  cleanup assigns to be set after the modal has disappeared and is no longer being rendered.
  ```
  def handle_event("close_modal", _, socket) do
    {:noreply, socket |> hide_modal(modal_assigns: nil)}
  end
  ```
  """

  defmacro __using__([]) do
    quote do
      def render_modal(assigns) do
        case assigns[:__modal__] do
          nil ->
            nil

          component when is_function(component) ->
            component.(assigns)
        end
      end

      def handle_event("phx_modal.unmount", _, socket) do
        case socket.assigns do
          %{__modal_assigns_after_hide__: assigns_after_hide}
          when not is_nil(assigns_after_hide) ->
            {:noreply,
             assign(
               socket,
               Keyword.merge(assigns_after_hide, __modal__: nil, __modal_assigns_after_hide__: nil)
             )}

          _ ->
            {:noreply, assign(socket, __modal__: nil)}
        end
      end

      def show_modal(socket, modal, assigns \\ []) when is_function(modal) do
        socket
        |> assign(:__modal__, modal)
        |> assign(assigns)
      end

      def hide_modal(socket, assigns_after_hide \\ []) do
        socket
        |> push_event("phx_modal.hide", %{})
        |> assign(:__modal_assigns_after_hide__, assigns_after_hide)
      end
    end
  end
end
