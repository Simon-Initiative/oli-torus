defmodule OliWeb.DelegatedEvents do
  def delegate_to({event, params, socket, patch_fn}, delegates) do
    Enum.reduce_while(delegates, :not_handled, fn delegate_fn, _ ->
      case delegate_fn.(event, params, socket, patch_fn) do
        :not_handled -> {:cont, :not_handled}
        result -> {:halt, result}
      end
    end)
  end
end
