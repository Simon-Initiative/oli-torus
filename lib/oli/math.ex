defmodule Oli.Math do
  @moduledoc """
  Thin Elixir boundary around the public Gleam math parser.

  The Gleam parser owns syntax and debug formatting. This module only maps the
  Erlang-target result into a Torus-friendly shape so server callers do not need
  to know about generated Gleam module names or tuple contracts.
  """

  @type parse_success :: %{ast: term(), debug: String.t()}
  @type parse_failure :: %{error: term(), debug: String.t()}

  @spec hello(String.t()) :: String.t()
  def hello(name) when is_binary(name) do
    call_gleam(:expression, :hello, [name])
  end

  @spec parse(String.t()) :: {:ok, parse_success()} | {:error, parse_failure()}
  def parse(expression) when is_binary(expression) do
    case call_gleam(:torus_math, :parse, [expression]) do
      {:ok, parsed} ->
        {:ok, %{ast: parsed, debug: call_gleam(:torus_math, :to_debug_string, [parsed])}}

      {:error, error} ->
        {:error,
         %{error: error, debug: call_gleam(:torus_math, :parse_error_to_debug_string, [error])}}
    end
  end

  defp call_gleam(module, function, args) do
    Oli.Math.Gleam.call(module, function, args)
  end
end
