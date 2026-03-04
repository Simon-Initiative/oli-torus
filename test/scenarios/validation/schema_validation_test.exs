defmodule Oli.Scenarios.Validation.SchemaValidationTest do
  use ExUnit.Case, async: true

  alias Oli.Scenarios
  alias Oli.Scenarios.DirectiveParser

  test "all checked-in scenario yaml files satisfy scenario.schema.json" do
    files =
      Path.wildcard("test/scenarios/**/*.yaml")
      |> Enum.sort()

    failures =
      Enum.reduce(files, [], fn file, acc ->
        case Scenarios.validate_file(file) do
          :ok ->
            acc

          {:error, errors} ->
            [{file, errors} | acc]
        end
      end)
      |> Enum.reverse()

    assert failures == [],
           "Schema validation failures:\n" <>
             Enum.map_join(failures, "\n\n", fn {file, errors} ->
               "#{file}\n  " <>
                 Enum.map_join(errors, "\n  ", fn err ->
                   "#{err.path}: #{err.message}"
                 end)
             end)
  end

  test "schema and parser agree on unknown directives" do
    yaml = """
    - create_project:
        name: "demo"
    """

    assert {:error, _errors} = Scenarios.validate_yaml(yaml)

    assert_raise RuntimeError, ~r/Unrecognized directive: 'create_project'/, fn ->
      DirectiveParser.parse_yaml!(yaml)
    end
  end
end
