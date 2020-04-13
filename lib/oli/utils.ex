defmodule Oli.Utils do
  @doc """
  Generates a random hex string of the given length
  """
  def random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.encode16 |> binary_part(0, length)
  end


  @doc """
  Converts a map of LTI parameters to a keyword list.
  This function is unsafe because it expects an atom to exist for each map key,
  which makes it only safe for requests with known parameter names that are defined as atoms
  """
  def unsafe_map_to_keyword_list(map) do
    Enum.map(map, fn({key, value}) -> {String.to_atom(key), value} end)
  end

  @doc """
  Returns the specified value if not nil, otherwise returns the default value
  """
  def value_or(value, default_value) do
    if value == nil do
      default_value
    else
      value
    end
  end

  def format_datetime(datetime) do
    ampm = if datetime.hour < 13, do: "AM", else: "PM"
    hour = if datetime.hour < 13, do: datetime.hour, else: datetime.hour - 12
    minute = if datetime.minute < 10, do: "#{datetime.minute}0", else: datetime.minute
    "#{datetime.month}/#{datetime.day}/#{datetime.year} #{hour}:#{minute} #{ampm}"
  end

  def trap_nil(nil), do: {:error, {:not_found}}
  def trap_nil(result), do: {:ok, result}
end
