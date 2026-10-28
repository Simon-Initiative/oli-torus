defmodule Oli.LearningModel.Parameters.Type do
  @moduledoc """
  Ecto type for loading and dumping typed learning-model parameter envelopes.
  """

  use Ecto.Type

  alias Oli.LearningModel.Parameters

  @impl Ecto.Type
  def type, do: :map

  @impl Ecto.Type
  def cast(value), do: decode(value)

  @impl Ecto.Type
  def load(value), do: decode(value)

  @impl Ecto.Type
  def dump(value) do
    case Parameters.encode(value) do
      {:ok, encoded} -> {:ok, encoded}
      {:error, _reason} -> :error
    end
  end

  @impl Ecto.Type
  def equal?(left, right), do: left == right

  defp decode(value) do
    case Parameters.decode(value) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _reason} -> :error
    end
  end
end
