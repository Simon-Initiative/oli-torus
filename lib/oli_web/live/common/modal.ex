defmodule OliWeb.Common.Modal do
  @moduledoc """
  A Phoenix LiveView Bootstrap compliant modal implementation.

  Usage:

  1. In your LiveView, use this module:
  ```
  use OliWeb.Common.Modal
  ```

  2. Initialize modal assign and add render_modal to the render output:
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
  def handle_event("show_modal", _, socket) do
    {:noreply, assign(socket, modal: %{component: MyModal, assigns: %{...}})}
  end

  4. Dismiss modal using bootstrap javascript (data-dismiss="modal", escape key, etc...)
      or using the hide_modal(socket) function
  def handle_event("close_modal", _, socket) do
    {:noreply, socket |> hide_modal()}
  end
  """

  defmacro __using__([]) do
    quote do
      def render_modal(assigns) do
        case assigns[:modal] do
          nil ->
            nil

          %{component: component, assigns: assigns} ->
            live_component(component, assigns)
        end
      end

      def handle_event("hide_modal", _, socket) do
        {:noreply, hide_modal(socket)}
      end

      def handle_event("unmount_modal", _, socket) do
        {:noreply, assign(socket, modal: nil)}
      end

      defp hide_modal(socket) do
        push_event(socket, "hide_modal", %{})
      end
    end
  end
end
