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
  def capture_error(e, metadata \\ nil)

  def capture_error(e, metadata) when is_atom(e) do
    Atom.to_string(e)
    |> capture_error(metadata)
  end

  def capture_error(e, metadata) when is_binary(e) do
    try do
      raise e
    catch
      kind, reason ->
        case metadata do
          nil ->
            Appsignal.send_error(kind, reason, __STACKTRACE__)

          metadata ->
            Appsignal.send_error(kind, reason, __STACKTRACE__, fn span ->
              Appsignal.Span.set_attribute(span, "metadata", metadata)
            end)
        end
    end
  end

  def capture_error({e}, metadata), do: capture_error(e, metadata)
end
