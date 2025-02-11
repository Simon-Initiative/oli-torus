defmodule OliWeb.Live.TaggedTupleHelper do
  def noreply_wrapper(term), do: {:noreply, term}
  def ok_wrapper(term), do: {:ok, term}
end
