defmodule Oli.Activities.TransformersTest do
  use ExUnit.Case, async: true

  alias Oli.Activities.Transformers

  defp as_revision(id, model) do
    %Oli.Resources.Revision{
      id: id,
      resource_id: id,
      content: model
    }
  end

  test "no transformers results in no effect" do
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
        "transformations" => []
      }
    }

    assert [{:ok, nil}] = Transformers.apply_transforms([as_revision(1, model)])
  end

  test "applying shuffle" do
    create_model = fn ->
      %{
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
    end

    # Shuffle fifty times.  If none of the shuffles result in
    # the first element changing - we likely have a broken shuffle impl.
    assert Enum.any?(1..50, fn _ ->
             [{:ok, transformed}] =
               Transformers.apply_transforms([as_revision(1, create_model.())])

             transformed["choices"] |> Enum.at(0) |> Map.get("id") != "1"
           end)
  end

  test "applying shuffle for specific part" do
    create_model = fn ->
      %{
        "stem" => "this is the stem",
        "choices" => [
          %{id: "1", content: []},
          %{id: "2", content: []},
          %{id: "3", content: []},
          %{id: "4", content: []}
        ],
        "inputs" => [
          %{
            "choiceIds" => [
              "1",
              "2",
              "3",
              "4"
            ],
            "id" => "1560432564",
            "inputType" => "dropdown",
            "partId" => "4170243249"
          }
        ],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [
                %{
                  "feedback" => %{
                    "content" => [],
                    "id" => "2853247186"
                  },
                  "id" => "297027184",
                  "rule" => "input like {4170243249}",
                  "score" => 1
                },
                %{
                  "feedback" => %{
                    "content" => [],
                    "id" => "269269687"
                  },
                  "id" => "2857138762",
                  "rule" => "input like {.*}",
                  "score" => 0
                }
              ],
              "scoringStrategy" => "best",
              "evaluationStrategy" => "regex"
            }
          ],
          "transformations" => [
            %{"id" => "1", "path" => "choices", "operation" => "shuffle"},
            %{
              "firstAttemptOnly" => true,
              "id" => "2",
              "operation" => "shuffle",
              "partId" => "4170243249",
              "path" => "choices"
            }
          ]
        }
      }
    end

    # Shuffle fifty times.  If none of the shuffles result in
    # the first element changing - we likely have a broken shuffle impl.
    assert Enum.any?(1..50, fn _ ->
             [{:ok, transformed}] =
               Transformers.apply_transforms([as_revision(1, create_model.())])

             transformed["choices"] |> Enum.at(0) |> Map.get("id") != "1"
             transformed["inputs"] |> Enum.at(0) |> Map.get("choiceIds") |> Enum.at(0) != "1"
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

    assert [{:error, ["invalid operation"]}] =
             Transformers.apply_transforms([as_revision(1, model)])
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
          %{"id" => "1", "path" => "this_path_does_not_exist", "operation" => "shuffle"}
        ]
      }
    }

    assert [{:error, :path_not_found}] = Transformers.apply_transforms([as_revision(1, model)])
  end
end
