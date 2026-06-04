defmodule Oli.Math.Equality do
  @moduledoc """
  Thin Elixir boundary around the public Gleam equality API.

  The Gleam implementation owns the equality contract, JSON parsing, numeric
  evaluation, and diagnostics. This module only hides generated module names so
  future Torus evaluator integration can call one server-side boundary without
  duplicating math semantics in Elixir.
  """

  @type equality_spec :: term()
  @type equality_result :: term()
  @type equality_config_error :: term()

  @spec decode_config(String.t()) :: {:ok, equality_spec()} | {:error, equality_config_error()}
  def decode_config(source) when is_binary(source) do
    Oli.Math.Gleam.call(:torus_math, :decode_equality_config, [source])
  end

  @spec encode_config(equality_spec()) :: String.t()
  def encode_config(spec) do
    Oli.Math.Gleam.call(:torus_math, :encode_equality_config, [spec])
  end

  @spec evaluate_config(equality_spec(), String.t()) :: equality_result()
  def evaluate_config(spec, submitted) when is_binary(submitted) do
    Oli.Math.Gleam.call(:torus_math, :evaluate_equality, [spec, submitted])
  end

  @spec evaluate_json(String.t(), String.t()) ::
          {:ok, equality_result()} | {:error, equality_config_error()}
  def evaluate_json(source, submitted) when is_binary(source) and is_binary(submitted) do
    with {:ok, spec} <- decode_config(source) do
      {:ok, evaluate_config(spec, submitted)}
    end
  end
end
