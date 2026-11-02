defmodule OliWeb.DelegatedEvents do
  require Logger

  @doc """
  Runs `event` through `delegates` in order and returns the first result that is not `:not_handled`.
  When no delegate handles the event, logs a warning naming the view (and the live component's
  id, when a component delegates) and the event, and returns `{:noreply, socket}`.
  """
  def delegate_to({event, params, socket, patch_fn}, delegates) do
    delegates
    |> Enum.reduce_while(:not_handled, fn delegate_fn, _ ->
      case delegate_fn.(event, params, socket, patch_fn) do
        :not_handled -> {:cont, :not_handled}
        result -> {:halt, result}
      end
    end)
    |> case do
      :not_handled ->
        Logger.warning("Unhandled event in #{origin(socket)}: #{inspect(event)}")

        {:noreply, socket}

      result ->
        result
    end
  end

  # The payload is never logged: an event's params can carry student data.
  defp origin(%{view: view, assigns: %{myself: _, id: id}}),
    do: "#{inspect(view)} (component #{inspect(id)})"

  defp origin(%{view: view}), do: inspect(view)
end
