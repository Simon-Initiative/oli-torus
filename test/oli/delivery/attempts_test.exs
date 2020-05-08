defmodule Oli.Delivery.AttemptsTest do

  use Oli.DataCase

  alias Oli.Delivery.Attempts
  alias Oli.Activities.Model.Part

  describe "attempts context" do

    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_user(%{}, :user2)

      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user1, :page1, :revision1, :attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: 1, responses: [], hints: []}, :attempt1, :part1_attempt1)

      |> Seeder.create_resource_attempt(%{attempt_number: 2}, :user1, :page1, :revision1, :attempt2)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: 1, responses: [], hints: []}, :attempt2, :part1_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 2}, %Part{id: 1, responses: [], hints: []}, :attempt2, :part1_attempt2)
      |> Seeder.create_part_attempt(%{attempt_number: 3}, %Part{id: 1, responses: [], hints: []}, :attempt2, :part1_attempt3)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: 2, responses: [], hints: []}, :attempt2, :part2_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: 3, responses: [], hints: []}, :attempt2, :part3_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 2}, %Part{id: 3, responses: [], hints: []}, :attempt2, :part3_attempt2)
    end

    test "creating an access record", %{user1: user1, user2: user2, section: section, page1: page1} do

      Attempts.track_access(page1.id, section.id, user1.id)
      Attempts.track_access(page1.id, section.id, user1.id)

      entries = Oli.Repo.all(Oli.Delivery.Attempts.ResourceAccess)
      assert length(entries) == 1
      assert hd(entries).access_count == 4

      Attempts.track_access(page1.id, section.id, user2.id)
      entries = Oli.Repo.all(Oli.Delivery.Attempts.ResourceAccess)
      assert length(entries) == 2
      assert hd(entries).access_count == 4

    end

    test "fetching attempt records", %{user1: user1, section: section, page1: page1} do

      results = Attempts.get_latest_part_attempts([page1.id], section.context_id, user1.id)

      assert length(Map.keys(results)) == 1
      assert Map.has_key?(results, page1.id)

      assert results[page1.id][1].attempt_number == 3
      assert results[page1.id][2].attempt_number == 1
      assert results[page1.id][3].attempt_number == 2
    end

  end

end
