defmodule Oli.Analytics.Common do
  import Ecto.Query, warn: false

  @doc """
  Take an enumeration of maps of data and return a JSON Lines compatible string.
  """
  def to_jsonlines(maps) do
    Enum.map(maps, fn m -> Jason.encode!(m) end)
    |> Enum.join("\n")
  end

end
