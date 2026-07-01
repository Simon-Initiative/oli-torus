defmodule Oli.Activities.ManifestTest do
  use ExUnit.Case, async: true

  alias Oli.Activities.Manifest

  test "parse/1 includes preview mode when provided" do
    json = %{
      "id" => "oli_multiple_choice",
      "friendlyName" => "Multiple Choice",
      "petiteLabel" => "MCQ",
      "description" => "Choice-based question type with single choice selection",
      "delivery" => %{
        "element" => "oli-multiple-choice-delivery",
        "entry" => "./delivery-entry.ts"
      },
      "authoring" => %{
        "element" => "oli-multiple-choice-authoring",
        "entry" => "./authoring-entry.ts"
      },
      "preview" => %{"element" => "oli-multiple-choice-preview", "entry" => "./preview-entry.ts"}
    }

    assert {:ok, manifest} = Manifest.parse(json)
    assert manifest.preview.element == "oli-multiple-choice-preview"
    assert manifest.preview.entry == "./preview-entry.ts"
  end

  test "parse/1 leaves preview nil when not provided" do
    json = %{
      "id" => "oli_multiple_choice",
      "friendlyName" => "Multiple Choice",
      "petiteLabel" => "MCQ",
      "description" => "Choice-based question type with single choice selection",
      "delivery" => %{
        "element" => "oli-multiple-choice-delivery",
        "entry" => "./delivery-entry.ts"
      },
      "authoring" => %{
        "element" => "oli-multiple-choice-authoring",
        "entry" => "./authoring-entry.ts"
      }
    }

    assert {:ok, manifest} = Manifest.parse(json)
    assert manifest.preview == nil
  end
end
