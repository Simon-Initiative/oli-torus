defmodule Oli.Activities.ParseUtilsTest do
  use ExUnit.Case, async: true

  alias Oli.Activities.ParseUtils

  test "items_or_errors/1 handles empty list" do
    assert {:ok, []} == ParseUtils.items_or_errors([])
  end

  test "items_or_errors/1 handles all oks" do
    assert {:ok, [1, 2, 3]} =
             ParseUtils.items_or_errors([
               {:ok, 1},
               {:ok, 2},
               {:ok, 3}
             ])
  end

  test "items_or_errors/1 handles all errors" do
    assert {:error, [1, 2, 3]} =
             ParseUtils.items_or_errors([
               {:error, 1},
               {:error, 2},
               {:error, 3}
             ])
  end

  test "items_or_errors/1 handles a mixture" do
    assert {:error, [2]} =
             ParseUtils.items_or_errors([
               {:ok, 1},
               {:error, 2},
               {:ok, 3}
             ])
  end

  test "has_content?/1 correctly detects when there's content" do
    has_content1 = %{
      content: %{
        model: [
          %{"children" => [%{"text" => "content"}], "type" => "p"}
        ]
      }
    }

    has_content2 = %{
      content: %{
        model: [
          %{
            "children" => [
              %{"text" => ""},
              %{"type" => "a", "children" => [%{"text" => "content"}]},
              %{"text" => ""}
            ],
            "type" => "p"
          }
        ]
      }
    }

    has_content3 = %{
      "content" => %{
        "model" => [
          %{
            "children" => [
              %{"text" => ""},
              %{"type" => "a", "children" => [%{"text" => "content"}]},
              %{"text" => ""}
            ],
            "type" => "p"
          }
        ]
      }
    }

    has_content4 = %{
      content: [
        %{"children" => [%{"text" => "content"}], "type" => "p"}
      ]
    }

    has_content5 = %{
      content: [
        %{"children" => [%{"text" => "content"}], "type" => "p"}
      ]
    }

    has_content6 = %{
      "content" => [
        %{
          "children" => [
            %{"text" => ""},
            %{"type" => "a", "children" => [%{"text" => "content"}]},
            %{"text" => ""}
          ],
          "type" => "p"
        }
      ]
    }

    has_content7 = %{
      "content" => [
        %{
          "type" => "img"
        }
      ]
    }

    [
      has_content1,
      has_content2,
      has_content3,
      has_content4,
      has_content5,
      has_content6,
      has_content7
    ]
    |> Enum.map(&ParseUtils.has_content?(&1))
    |> Enum.all?()
    |> assert

    no_content1 = %{
      content: %{
        model: [
          %{"children" => [%{"text" => ""}], "type" => "p"}
        ]
      }
    }

    no_content2 = %{
      "content" => %{
        "model" => [
          %{"children" => [%{"text" => ""}], "type" => "p"}
        ]
      }
    }

    no_content3 = %{
      content: [
        %{"children" => [%{"text" => ""}], "type" => "p"}
      ]
    }

    no_content4 = %{
      "content" => [
        %{"children" => [%{"text" => ""}], "type" => "p"}
      ]
    }

    no_content5 = %{
      "content" => [
        %{
          "children" => [
            %{"text" => ""},
            %{"text" => "  "},
            %{"text" => "    \n"}
          ],
          "type" => "p"
        }
      ]
    }

    [
      no_content1,
      no_content2,
      no_content3,
      no_content4,
      no_content5
    ]
    |> Enum.map(&ParseUtils.has_content?(&1))
    |> Enum.any?()
    |> refute
  end
end
