defmodule Mix.Tasks.Oli.GenerateContentDispatcher do
  @shortdoc "Generate or check the shared rich-content type dispatcher"
  @moduledoc """
  Regenerates only the typed-element dispatcher from the schema's annotated
  concrete definitions. Placement/context enums remain manually authored policy.

      mix oli.generate_content_dispatcher
      mix oli.generate_content_dispatcher --check

  An optional schema path can be supplied for tooling/tests. Check mode compares
  decoded schemas, ignores formatting differences, and never writes files. No
  application, database, validator construction, or runtime generation is needed.
  """
  use Mix.Task

  alias Oli.Schemas.ContentDispatcher

  @default_path "priv/schemas/v0-1-0/content-element.schema.json"

  @impl Mix.Task
  def run(args) do
    {opts, paths} = OptionParser.parse!(args, strict: [check: :boolean])

    path =
      case paths do
        [] -> @default_path
        [path] -> path
        _ -> Mix.raise("Provide at most one content schema path")
      end

    schema = path |> File.read!() |> Jason.decode!()
    generated = ContentDispatcher.generate(schema)

    case {opts[:check], schema == generated} do
      {true, true} ->
        :ok

      {true, false} ->
        Mix.raise("Content dispatcher is stale; run mix oli.generate_content_dispatcher")

      _ ->
        File.write!(path, Jason.encode!(ordered(generated), pretty: true) <> "\n")
    end
  end

  # Stable, readable JSON output independent of BEAM map iteration order.
  defp ordered(value) when is_map(value) do
    priority = [
      "$id",
      "$schema",
      "title",
      "description",
      "$comment",
      "type",
      "properties",
      "required",
      "additionalProperties",
      "if",
      "then",
      "else",
      "allOf",
      "$defs"
    ]

    value
    |> Enum.sort_by(fn {key, _} -> {Enum.find_index(priority, &(&1 == key)) || 100, key} end)
    |> Enum.map(fn {key, child} -> {key, ordered(child)} end)
    |> Jason.OrderedObject.new()
  end

  defp ordered(value) when is_list(value), do: Enum.map(value, &ordered/1)
  defp ordered(value), do: value
end
