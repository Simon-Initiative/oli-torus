defmodule Oli.Activities.ParseTest do
  use ExUnit.Case, async: true

  alias Oli.Activities.Model
  alias Oli.TestHelpers

  test "parsing of a valid model" do
    {:ok, contents} = TestHelpers.read_json_file("./test/oli/activities/valid.json")

    assert {:ok, parsed} = Model.parse(contents)

    assert length(parsed.parts) == 2
    assert length(parsed.transformations) == 1
  end

  test "collecting errors" do
    {:ok, contents} = TestHelpers.read_json_file("./test/oli/activities/errors.json")

    assert {:error, errors} = Model.parse(contents)

    assert length(errors) == 4
  end
end
