defmodule Oli.Utils.Appsignal do
  @doc """
  Will log a RuntimeError to Appsignal with the reason being the
  `e` parameter of the `{:error, e}` tuple.  Returns the tuple
  so that this function can be used inline like:

  ```
  something_that_will_maybe_return_an_error()
  |> Oli.Utils.Appsignal()
  ```
  """
  def capture_error(e) when is_atom(e) do
    Atom.to_string(e)
    |> capture_error()
  end

  def capture_error(e) when is_binary(e) do
    try do
      raise e
    catch
      kind, reason ->
        Appsignal.send_error(kind, reason, __STACKTRACE__)
    end
  end

  def capture_error({e}), do: capture_error(e)
end
