defmodule Oli.Math.Match do
  @moduledoc """
  Thin Elixir boundary around the public Gleam `matchConfig` API.

  The Gleam implementation owns the match-config contract, decoding, evaluation,
  and safe diagnostics. This wrapper keeps delivery evaluation independent from
  generated module names and from lower-level math subsystem details.
  """

  @type match_config :: term()
  @type match_result :: term()
  @type match_config_error :: term()

  @spec decode_config(map() | String.t()) ::
          {:ok, match_config()} | {:error, match_config_error()}
  def decode_config(source) when is_map(source) do
    source
    |> Jason.encode!()
    |> decode_config()
  end

  def decode_config(source) when is_binary(source) do
    Oli.Math.Gleam.decode_match_config(source)
  end

  @spec encode_config(match_config()) :: String.t()
  def encode_config(config) do
    Oli.Math.Gleam.encode_match_config(config)
  end

  @spec evaluate_config(match_config(), String.t()) :: match_result()
  def evaluate_config(config, submitted) when is_binary(submitted) do
    Oli.Math.Gleam.evaluate_match(config, submitted)
  end

  @spec evaluate_json(map() | String.t(), String.t()) ::
          {:ok, match_result()} | {:error, match_config_error()}
  def evaluate_json(source, submitted) when is_binary(submitted) do
    with {:ok, config} <- decode_config(source) do
      {:ok, evaluate_config(config, submitted)}
    end
  end
end
