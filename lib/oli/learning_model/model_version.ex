defmodule Oli.LearningModel.ModelVersion do
  @moduledoc """
  Defines the semantic learning-model versions supported by Torus.

  Archive values are decoded by explicit matching so untrusted strings never
  create atoms.
  """

  @values [:naive, :lkt_aoa]

  @type t :: :naive | :lkt_aoa

  @spec values() :: [t()]
  def values, do: @values

  @spec encode(t()) :: String.t()
  def encode(:naive), do: "naive"
  def encode(:lkt_aoa), do: "lkt_aoa"

  @spec decode_archive(term(), t()) ::
          {:ok, t()} | {:error, {:invalid_learning_model_version, term()}}
  def decode_archive(value, fallback)

  def decode_archive(nil, fallback) when fallback in @values, do: {:ok, fallback}
  def decode_archive("naive", fallback) when fallback in @values, do: {:ok, :naive}
  def decode_archive("lkt_aoa", fallback) when fallback in @values, do: {:ok, :lkt_aoa}

  def decode_archive(value, fallback) when fallback in @values,
    do: {:error, {:invalid_learning_model_version, value}}

  def decode_archive(_value, fallback),
    do: {:error, {:invalid_learning_model_version, fallback}}
end
