defmodule Oli.Utils do

  @doc """
  Generates a random hex string of the given length
  """
  def random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.encode16 |> binary_part(0, length)
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

  @doc """
  Traps a nil and wraps it in an {:error, _} tuple, otherwise passes thru
  the non-nil result as {:ok, result}
  """
  def trap_nil(result, description_tag \\ :not_found) do
    case result do
      nil -> {:error, {description_tag}}
      _ -> {:ok, result}
    end
  end
end
