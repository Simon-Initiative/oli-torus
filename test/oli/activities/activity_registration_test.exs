defmodule Oli.Activities.ActivityRegistrationTest do
  use Oli.DataCase, async: true

  alias Oli.Activities.ActivityRegistration

  describe "changeset/2" do
    test "accepts preview fields when provided" do
      attrs = %{
        slug: "oli_multiple_choice",
        title: "Multiple Choice",
        petite_label: "MCQ",
        icon: "list-ul",
        description: "Choice-based question type with single choice selection",
        delivery_element: "oli-multiple-choice-delivery",
        authoring_element: "oli-multiple-choice-authoring",
        preview_element: "oli-multiple-choice-preview",
        delivery_script: "oli_multiple_choice_delivery.js",
        authoring_script: "oli_multiple_choice_authoring.js",
        preview_script: "oli_multiple_choice_preview.js"
      }

      changeset = ActivityRegistration.changeset(%ActivityRegistration{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :preview_element) == "oli-multiple-choice-preview"
      assert get_change(changeset, :preview_script) == "oli_multiple_choice_preview.js"
    end

    test "does not require preview fields" do
      attrs = %{
        slug: "oli_multiple_choice",
        title: "Multiple Choice",
        petite_label: "MCQ",
        icon: "list-ul",
        description: "Choice-based question type with single choice selection",
        delivery_element: "oli-multiple-choice-delivery",
        authoring_element: "oli-multiple-choice-authoring",
        delivery_script: "oli_multiple_choice_delivery.js",
        authoring_script: "oli_multiple_choice_authoring.js"
      }

      changeset = ActivityRegistration.changeset(%ActivityRegistration{}, attrs)

      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :preview_element)
      refute Map.has_key?(changeset.changes, :preview_script)
    end
  end
end
