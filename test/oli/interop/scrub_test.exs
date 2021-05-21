defmodule Oli.Interop.ScrubTest do
  use ExUnit.Case, async: true

  alias Oli.Interop.Scrub

  # helper routine to traverse an arbitrary path through content
  def traverse(content, path) do
    String.split(path, " ")
    |> Enum.reduce(content, fn step, current ->
      case Integer.parse(step) do
        {index, _} -> Enum.at(current, index)
        :error -> Map.get(current, step)
      end
    end)
  end

  test "scrub with nothing to do" do
    content = %{
      "model" => [
        %{
          "type" => "content",
          "children" => [%{"type" => "p", "children" => [%{"type" => "text", "text" => "Hello"}]}]
        }
      ]
    }

    {[], updated} = Scrub.scrub(content)

    assert "Hello" == traverse(updated, "model 0 children 0 children 0 text")
  end

  test "scrub works on activities" do
    content = %{
      "model" => %{
        "stem" => %{
          "content" => [
            %{
              "type" => "code",
              "children" => [
                %{"type" => "p", "children" => [%{"type" => "text", "text" => "Hello"}]},
                %{"type" => "code_line", "children" => [%{"type" => "text", "text" => "There"}]}
              ]
            }
          ]
        },
        "choices" => [
          %{
            "content" => [
              %{
                "type" => "code",
                "children" => [
                  %{"type" => "p", "children" => [%{"type" => "text", "text" => "Hello"}]},
                  %{"type" => "code_line", "children" => [%{"type" => "text", "text" => "There"}]}
                ]
              }
            ]
          }
        ],
        "authoring" => %{
          "parts" => [
            %{
              "responses" => [
                %{
                  "feedback" => %{
                    "content" => [
                      %{
                        "type" => "code",
                        "children" => [
                          %{
                            "type" => "p",
                            "children" => [%{"type" => "text", "text" => "Hello"}]
                          },
                          %{
                            "type" => "code_line",
                            "children" => [%{"type" => "text", "text" => "There"}]
                          }
                        ]
                      }
                    ]
                  }
                }
              ]
            }
          ]
        }
      }
    }

    {changes, updated} = Scrub.scrub(content)
    assert length(changes) == 3
    assert "code_line" == traverse(updated, "model stem content 0 children 0 type")
    assert "code_line" == traverse(updated, "model choices 0 content 0 children 0 type")

    assert "code_line" ==
             traverse(
               updated,
               "model authoring parts 0 responses 0 feedback content 0 children 0 type"
             )

    # verify that the nodes that did not specify ids had them assigned during scrubbing
    assert traverse(updated, "model") |> Map.has_key?("id")
    assert traverse(updated, "model stem") |> Map.has_key?("id")
    assert traverse(updated, "model stem content 0") |> Map.has_key?("id")
    assert traverse(updated, "model choices 0") |> Map.has_key?("id")
    assert traverse(updated, "model authoring parts 0") |> Map.has_key?("id")
    assert traverse(updated, "model authoring parts 0 responses 0") |> Map.has_key?("id")
    assert traverse(updated, "model authoring parts 0 responses 0 feedback") |> Map.has_key?("id")
  end

  test "scrub with a well formed code block" do
    content = %{
      "model" => [
        %{
          "type" => "content",
          "children" => [
            %{
              "type" => "code",
              "children" => [
                %{"type" => "code_line", "children" => [%{"type" => "text", "text" => "Hello"}]},
                %{"type" => "code_line", "children" => [%{"type" => "text", "text" => "There"}]}
              ]
            }
          ]
        }
      ]
    }

    {[], updated} = Scrub.scrub(content)

    assert "Hello" == traverse(updated, "model 0 children 0 children 0 children 0 text")
    assert "There" == traverse(updated, "model 0 children 0 children 1 children 0 text")
  end

  test "scrub with report more than one change" do
    content = %{
      "model" => [
        %{
          "type" => "content",
          "children" => [
            %{
              "type" => "code",
              "children" => [
                %{"type" => "p", "children" => [%{"type" => "text", "text" => "Hello"}]},
                %{"type" => "code_line", "children" => [%{"type" => "text", "text" => "There"}]}
              ]
            },
            %{
              "type" => "code",
              "children" => [
                %{"type" => "p", "children" => [%{"type" => "text", "text" => "Hello"}]},
                %{"type" => "code_line", "children" => [%{"type" => "text", "text" => "There"}]}
              ]
            }
          ]
        }
      ]
    }

    {changes, _} = Scrub.scrub(content)

    assert length(changes) == 2
  end

  test "scrub with a bad code block" do
    content = %{
      "model" => [
        %{
          "type" => "content",
          "children" => [
            %{
              "type" => "code",
              "children" => [
                %{"type" => "p", "children" => [%{"type" => "text", "text" => "Hello"}]},
                %{"type" => "p", "children" => [%{"type" => "text", "text" => "There"}]}
              ]
            }
          ]
        }
      ]
    }

    {changes, updated} = Scrub.scrub(content)

    assert length(changes) == 1
    assert "Hello" == traverse(updated, "model 0 children 0 children 0 children 0 text")
    assert "code_line" == traverse(updated, "model 0 children 0 children 0 type")
    assert "There" == traverse(updated, "model 0 children 0 children 1 children 0 text")
    assert "code_line" == traverse(updated, "model 0 children 0 children 1 type")
  end

  test "scrub with a one bad code block entry" do
    content = %{
      "model" => [
        %{
          "type" => "content",
          "children" => [
            %{
              "type" => "code",
              "children" => [
                %{"type" => "code_line", "children" => [%{"type" => "text", "text" => "Hello"}]},
                %{"type" => "p", "children" => [%{"type" => "text", "text" => "There"}]}
              ]
            }
          ]
        }
      ]
    }

    {changes, updated} = Scrub.scrub(content)
    assert length(changes) == 1
    assert "Hello" == traverse(updated, "model 0 children 0 children 0 children 0 text")
    assert "code_line" == traverse(updated, "model 0 children 0 children 0 type")
    assert "There" == traverse(updated, "model 0 children 0 children 1 children 0 text")
    assert "code_line" == traverse(updated, "model 0 children 0 children 1 type")
  end

  test "scrub deeply extracts text correctly" do
    content = %{
      "model" => [
        %{
          "type" => "content",
          "children" => [
            %{
              "type" => "code",
              "children" => [
                %{
                  "type" => "p",
                  "children" => [
                    %{"type" => "text", "text" => "This", "bold" => true},
                    %{"type" => "text", "text" => " is "},
                    %{
                      "type" => "a",
                      "children" => [
                        %{"type" => "text", "text" => "deeply "},
                        %{"type" => "text", "text" => "nested"},
                        %{"type" => "text", "text" => " text"}
                      ]
                    },
                    %{"type" => "text", "text" => " extracted correctly."}
                  ]
                }
              ]
            }
          ]
        }
      ]
    }

    {changes, updated} = Scrub.scrub(content)
    assert length(changes) == 1

    assert "This is deeply nested text extracted correctly." ==
             traverse(updated, "model 0 children 0 children 0 children 0 text")

    assert "code_line" == traverse(updated, "model 0 children 0 children 0 type")
  end
end
