defmodule Oli.RegistrarTest do
  use Oli.DataCase

  alias Oli.Activities
  alias Oli.Registrar

  describe "activity registration" do

    setup do
      Seeder.base_project_with_resource()
    end

    test "register_local_activities/0 registers", _ do

      assert length(Activities.list_activity_registrations()) == 0

      Registrar.register_local_activities()

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

  end
end
