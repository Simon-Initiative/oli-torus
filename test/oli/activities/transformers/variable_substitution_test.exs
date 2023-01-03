defmodule Oli.Activities.TransformersTest do
  use ExUnit.Case, async: true

  alias Oli.Activities.Transformers

  alias Oli.Activities.Transformers.VariableSubstitution

  defp as_revision(id, model) do
    %Oli.Resources.Revision{
      id: id,
      resource_id: id,
      content: model
    }
  end

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
  end
end
