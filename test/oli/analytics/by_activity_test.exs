defmodule Oli.Delivery.Analytics.ByAnalyticsTest do

  use ExUnit.Case, async: true
  alias Oli.Delivery.Attempts.Snapshot

  describe "analytics by activity" do
    setup do
      map = Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(%{title: "one", content: %{"authoring" => "3"}}, :a1)
      |> Seeder.add_activity(%{title: "two", content: %{"stem" => "3"}}, :a2)
      # args: attempt_number, correct, score, out_of, hints
      |> Seeder.add_activity_snapshot(%{
        resource: resource,
        activity: activity,
        user: user,
        section: section,
        objective: objective,
        objective_revision: objective_revision,
        activity_revision: activity_revision
      }, 1, true, 1, 1, 0, :ss1)

      {:ok, map}
    end

    test "number of attempts" do

    end

    test "relative difficulty" do

    end

    test "eventually correct" do

    end

    test "first attempt correct" do

    end
  end

end
