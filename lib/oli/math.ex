defmodule Oli.Math do
  @moduledoc """
  Thin Elixir boundary around the public Gleam math parser.

  The Gleam parser owns syntax and debug formatting. This module only maps the
  Erlang-target result into a Torus-friendly shape so server callers do not need
  to know about generated Gleam module names or tuple contracts.
  """

  @type parse_success :: %{ast: term(), debug: String.t()}
  @type parse_failure :: %{error: term(), debug: String.t()}

  @spec parse(String.t()) :: {:ok, parse_success()} | {:error, parse_failure()}
  def parse(expression) when is_binary(expression) do
    case Oli.Math.Gleam.parse(expression) do
      {:ok, parsed} ->
        {:ok, %{ast: parsed, debug: Oli.Math.Gleam.to_debug_string(parsed)}}

      {:error, error} ->
        {:error, %{error: error, debug: Oli.Math.Gleam.parse_error_to_debug_string(error)}}
    end
  end
end
