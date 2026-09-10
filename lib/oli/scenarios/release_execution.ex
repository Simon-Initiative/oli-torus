defmodule Oli.Scenarios.ReleaseExecution do
  @moduledoc "Executes scenarios with YAML-defined ownership and no implicit defaults."

  alias Oli.Scenarios.{DirectiveParser, Engine}

  @max_scenario_bytes 5_000_000
  @max_include_depth 20

  def parse_file(path) when is_binary(path) do
    case File.stat(path) do
      {:ok, %{type: :regular, size: size}} when size <= @max_scenario_bytes ->
        DirectiveParser.load_file!(path)

      {:ok, %{type: :regular}} ->
        raise ArgumentError, "scenario file exceeds the release size limit"

      _ ->
        raise ArgumentError, "scenario file was not found"
    end
  end

  def execute(directives, path) when is_list(directives) and is_binary(path) do
    root_size = File.stat!(path).size

    Engine.execute(directives,
      ownership: true,
      current_dir: path |> Path.expand() |> Path.dirname(),
      release_remaining_bytes: @max_scenario_bytes - root_size,
      release_max_include_depth: @max_include_depth
    )
  end

  def execute_file(path) when is_binary(path) do
    path |> parse_file() |> execute(path)
  end
end
