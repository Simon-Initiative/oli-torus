defmodule Oli.Activities.Transformers.VariableSubstitutionTest do
  use ExUnit.Case, async: true

  alias Oli.Activities.Transformers.VariableSubstitution

  test "correctly escapes and replaces variables that possibly contain JSON special chars" do
    model = %{
      "stem" => "var1 = @@var1@@",
      "choices" => [
        %{id: "1", content: []},
        %{id: "2", content: []},
        %{id: "3", content: []},
        %{id: "4", content: []}
      ],
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1",
            "responses" => [],
            "scoringStrategy" => "best",
            "evaluationStrategy" => "regex"
          }
        ],
        "transformations" => [
          %{"id" => "1", "path" => "choices", "operation" => "shuffle"}
        ]
      }
    }

    {:ok, transformed} =
      VariableSubstitution.transform(model, nil, [
        %{"variable" => "var1", "result" => "evaluated"}
      ])

    assert transformed["stem"] == "var1 = evaluated"

    {:ok, transformed} =
      VariableSubstitution.transform(model, nil, [
        %{"variable" => "var1", "result" => ~s|"|}
      ])

    assert transformed["stem"] == ~s|var1 = "|

    {:ok, transformed} =
      VariableSubstitution.transform(model, nil, [
        %{"variable" => "var1", "result" => ~s|1\n2|}
      ])

    assert transformed["stem"] == ~s|var1 = 1\n2|

    {:ok, transformed} =
      VariableSubstitution.transform(model, nil, [
        %{"variable" => "var1", "result" => [0, 1, 2]}
      ])

    assert transformed["stem"] == ~s|var1 = [0, 1, 2]|

  end
end
