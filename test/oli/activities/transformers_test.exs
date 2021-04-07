defmodule Oli.Activities.TransformersTest do
  use ExUnit.Case, async: true

  alias Oli.Activities.Transformers

  test "applying shuffle" do
    model = %{
      "stem" => "this is the stem",
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

    # Shuffle fifty times.  If none of the shuffles result in
    # the first element changing - we likely have a broken shuffle impl.
    assert Enum.any?(1..50, fn _ ->
             {:ok, transformed} = Transformers.apply_transforms(model)
             transformed["choices"] |> Enum.at(0) |> Map.get("id") != "1"
           end)
  end

  test "catching invalid transformer" do
    model = %{
      "stem" => "this is the stem",
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
          %{"id" => "1", "path" => "choices", "operation" => "shuffled"}
        ]
      }
    }

    assert {:error, ["invalid operation"]} = Transformers.apply_transforms(model)
  end

  test "catching case where path cannot be found" do
    model = %{
      "stem" => "this is the stem",
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
          %{"id" => "1", "path" => "choicess", "operation" => "shuffle"}
        ]
      }
    }

    assert {:error, :path_not_found} = Transformers.apply_transforms(model)
  end
end
