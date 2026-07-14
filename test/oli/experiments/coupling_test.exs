defmodule Oli.Experiments.CouplingTest do
  use ExUnit.Case, async: true

  @event_schema_names ~w(Exposure Outcome Reward PolicyUpdate)
  @event_table_names ~w(
    experiment_exposures
    experiment_outcomes
    experiment_rewards
    experiment_policy_updates
  )
  @allowed_paths [
    "lib/oli/experiments.ex",
    "lib/oli/experiments/",
    "test/oli/experiments/"
  ]

  test "non-experiment product code does not couple to temporary runtime event tables" do
    violations =
      "lib/**/*.ex"
      |> Path.wildcard()
      |> Enum.reject(&allowed_path?/1)
      |> Enum.flat_map(&violations_in_file/1)

    assert violations == []
  end

  defp allowed_path?(path) do
    Enum.any?(@allowed_paths, fn allowed_path ->
      path == allowed_path or String.starts_with?(path, allowed_path)
    end)
  end

  defp violations_in_file(path) do
    content = File.read!(path)

    schema_violations =
      Enum.filter(@event_schema_names, fn schema_name ->
        String.contains?(content, "Oli.Experiments.Schemas.#{schema_name}") or
          (Regex.match?(~r/\b#{schema_name}\b/, content) and
             String.contains?(content, "Experiment"))
      end)

    table_violations =
      Enum.filter(@event_table_names, fn table_name ->
        String.contains?(content, table_name)
      end)

    Enum.map(schema_violations ++ table_violations, fn token -> "#{path}:#{token}" end)
  end
end
