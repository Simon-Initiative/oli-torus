defmodule OliWeb.Common.Modal do
  @moduledoc """
  A Phoenix LiveView compliant Bootstrap modal implementation.

  Usage:

  1. In your LiveView, use this module:
  ```
  use OliWeb.Common.Modal
  ```

  2. Initialize `modal` assign and add `render_modal(assigns)` to the rendered output:
  ```
  mount(_, _, socket) do
    {:ok, assign(socket, modal: nil)}
  end

  def render(assigns) do
    ...
    <%= render_modal(assigns) %>
    ...
  end
  ```

  3. Create your modal by setting the 'modal' assign
  ```
  def handle_event("show_modal", _, socket) do
    {:noreply, assign(socket, modal: %{component: MyModal, assigns: %{...}})}
  end
  ```

  4. Dismiss modal using bootstrap javascript (data-dismiss="modal", escape key, etc...)
  or using the hide_modal(socket) function
  ```
  def handle_event("close_modal", _, socket) do
    {:noreply, socket |> hide_modal()}
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

      def handle_event("_bsmodal.unmount", _, socket) do
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
        |> push_event("_bsmodal.hide", %{})
        |> assign(:__modal_assigns_after_hide__, assigns_after_hide)
      end
    end
  end
end
