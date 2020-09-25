defmodule OliWeb.Curriculum.ActivityDeltaTest do

  use Oli.DataCase

  alias OliWeb.Curriculum.ActivityDelta

  describe "activity delta test setup" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.add_page(%{
        content: %{
          "model" => [
           %{
              "activity_id" => 10,
              "children" => [],
              "id" => "3781635590",
              "purpose" => "None",
              "type" => "activity-reference"
            }
          ]
        }
      }, :page)
    end

    test "removing one", %{page: %{revision: page}} do

      updated = Map.put(page, :content, %{"model" => []})
      {:ok, delta} = ActivityDelta.new(updated, page)

      assert delta.current == MapSet.new()
      assert length(delta.deleted) == 1
      assert length(delta.added) == 0

    end

    test "adding one", %{page: %{revision: page}} do

      model = [
        %{
          "activity_id" => 10,
          "children" => [],
          "id" => "3781635590",
          "purpose" => "None",
          "type" => "activity-reference"
        },
        %{
          "activity_id" => 11,
          "children" => [],
          "id" => "3781635590",
          "purpose" => "None",
          "type" => "activity-reference"
        }
      ]

      updated = Map.put(page, :content, %{"model" => model})
      {:ok, delta} = ActivityDelta.new(updated, page)

      assert MapSet.size(delta.current) == 2
      assert length(delta.deleted) == 0
      assert length(delta.added) == 1

    end

    test "add one, remove one", %{page: %{revision: page}} do

      model = [
        %{
          "activity_id" => 11,
          "children" => [],
          "id" => "3781635590",
          "purpose" => "None",
          "type" => "activity-reference"
        }
      ]

      updated = Map.put(page, :content, %{"model" => model})
      {:ok, delta} = ActivityDelta.new(updated, page)

      assert MapSet.size(delta.current) == 1
      assert length(delta.deleted) == 1
      assert length(delta.added) == 1

    end

  end

end
