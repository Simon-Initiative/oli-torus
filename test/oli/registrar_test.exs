defmodule Oli.RegistrarTest do
  use Oli.DataCase

  alias Oli.Activities

  describe "activity registration" do

    test "register_local_activities/0 registers", _ do

      registrations = Activities.list_activity_registrations()
      assert length(registrations) == 1

      r = hd(registrations)

      assert r.title == "Multiple Choice"
      assert r.description == "A traditional multiple choice question with one correct answer"
      assert r.authoring_script == "oli-multiple-choice-authoring.js"
      assert r.delivery_script == "oli-multiple-choice-delivery.js"
      assert r.authoring_element == "oli-multiple-choice-authoring"
      assert r.delivery_element == "oli-multiple-choice-delivery"

    end

    test "create_registered_activity_map/0 creates correctly", _ do

      map = Activities.create_registered_activity_map()

      assert (Map.keys(map) |> length) == 1

      r = Map.get(map, "oli-multiple-choice")

      assert r.slug == "oli-multiple-choice"
      assert r.description == "A traditional multiple choice question with one correct answer"
      assert r.friendlyName == "Multiple Choice"
      assert r.authoringElement == "oli-multiple-choice-authoring"
      assert r.deliveryElement == "oli-multiple-choice-delivery"

    end

  end
end
