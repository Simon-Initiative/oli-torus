defmodule Oli.MCP.Resources.ExampleResource do
  @moduledoc """
  Individual example resource for activity examples.
  """

  use Anubis.Server.Component, type: :resource, uri: "torus://examples/oli_multiple_choice"

  alias Anubis.Server.Response

  @impl true
  def uri, do: "torus://examples/oli_multiple_choice"

  @impl true
  def mime_type, do: "application/json"

  @impl true
  def read(_params, frame) do
    example = %{
      "stem" => %{
        "id" => "stem_1",
        "content" => [
          %{
            "type" => "p",
            "children" => [%{"text" => "What is the capital of France?"}]
          }
        ]
      },
      "choices" => [
        %{
          "id" => "choice_1",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "London"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        %{
          "id" => "choice_2",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Paris", "bold" => true}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        %{
          "id" => "choice_3",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Berlin", "italic" => true}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        %{
          "id" => "choice_4",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Madrid"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        }
      ],
      "authoring" => %{
        "parts" => [
          %{
            "id" => "part_1",
            "responses" => [
              %{
                "rule" => "choice_2",
                "score" => 1,
                "id" => "response_1",
                "feedback" => %{
                  "id" => "feedback_1",
                  "content" => [
                    %{
                      "type" => "p",
                      "children" => [%{"text" => "Correct! Paris is the capital of France."}]
                    }
                  ]
                }
              },
              %{
                "rule" => "choice_1 choice_3 choice_4",
                "score" => 0,
                "id" => "response_2",
                "feedback" => %{
                  "id" => "feedback_2",
                  "content" => [
                    %{
                      "type" => "p",
                      "children" => [%{"text" => "Incorrect. Paris is the capital of France."}]
                    }
                  ]
                }
              }
            ],
            "scoringStrategy" => "average",
            "evaluationStrategy" => "regex"
          }
        ],
        "targeted" => [],
        "previewText" => "",
        "transformations" => []
      }
    }

    {:reply, Response.json(Response.resource(), example), frame}
  end
end