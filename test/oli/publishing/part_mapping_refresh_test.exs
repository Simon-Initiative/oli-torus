defmodule Oli.Publishing.PartMappingRefreshTest do
  use Oli.DataCase

  alias Oli.Publishing.PartMappingRefreshWorker

  describe "part mapping refresh" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "part mapping refresh works with well formed parts", %{
      project: project,
      publication: publication,
      author: author
    } do
      good_parts = %{
        "authoring" => %{
          "parts" => [
            %{"id" => "1", "gradingApproach" => "automatic"},
            %{"id" => "2", "gradingApproach" => "manual"},
            %{"id" => "3"}
          ]
        }
      }

      %{revision: revision} =
        Seeder.create_activity(%{content: good_parts}, publication, project, author)

      Oli.Publishing.update_publication(publication, %{published: DateTime.utc_now()})

      PartMappingRefreshWorker.perform_now()

      %{rows: rows, num_rows: 3} =
        Ecto.Adapters.SQL.query!(
          Oli.Repo,
          "SELECT * FROM part_mapping",
          []
        )

      entries =
        Enum.reduce(rows, %{}, fn [_, approach, _] = row, m -> Map.put(m, approach, row) end)

      assert Map.get(entries, "automatic") == ["1", "automatic", revision.id]
      assert Map.get(entries, "manual") == ["2", "manual", revision.id]
      assert Map.get(entries, nil) == ["3", nil, revision.id]
    end

    test "part mapping refresh works with duplicated part ids and distinct grading approaches", %{
      project: project,
      publication: publication,
      author: author
    } do
      good_parts = %{
        "authoring" => %{
          "parts" => [
            %{"id" => "1", "gradingApproach" => "automatic"},
            %{"id" => "1", "gradingApproach" => "manual"},
            %{"id" => "1"}
          ]
        }
      }

      %{revision: revision} =
        Seeder.create_activity(%{content: good_parts}, publication, project, author)

      Oli.Publishing.update_publication(publication, %{published: DateTime.utc_now()})

      PartMappingRefreshWorker.perform_now()

      %{rows: rows, num_rows: 3} =
        Ecto.Adapters.SQL.query!(
          Oli.Repo,
          "SELECT * FROM part_mapping",
          []
        )

      entries =
        Enum.reduce(rows, %{}, fn [_, approach, _] = row, m -> Map.put(m, approach, row) end)

      assert Map.get(entries, "manual") == ["1", "manual", revision.id]
      assert Map.get(entries, "automatic") == ["1", "automatic", revision.id]
      assert Map.get(entries, nil) == ["1", nil, revision.id]
    end

    test "part mapping refresh works with duplicated part ids and duplicated grading approaches",
         %{
           project: project,
           publication: publication,
           author: author
         } do
      good_parts = %{
        "authoring" => %{
          "parts" => [
            %{"id" => "1", "gradingApproach" => "automatic"},
            %{"id" => "1", "gradingApproach" => "automatic"},
            %{"id" => "1", "gradingApproach" => "automatic"}
          ]
        }
      }

      %{revision: %{id: revision_id}} =
        Seeder.create_activity(%{content: good_parts}, publication, project, author)

      Oli.Publishing.update_publication(publication, %{published: DateTime.utc_now()})

      PartMappingRefreshWorker.perform_now()

      %{rows: rows, num_rows: 1} =
        Ecto.Adapters.SQL.query!(
          Oli.Repo,
          "SELECT * FROM part_mapping",
          []
        )

      assert [["1", "automatic", ^revision_id]] = rows
    end

    test "part mapping refresh works with missing part ids",
         %{
           project: project,
           publication: publication,
           author: author
         } do
      good_parts = %{
        "authoring" => %{
          "parts" => [
            %{"gradingApproach" => "automatic"},
            %{"gradingApproach" => "automatic"},
            %{"gradingApproach" => "automatic"}
          ]
        }
      }

      %{revision: %{id: revision_id}} =
        Seeder.create_activity(%{content: good_parts}, publication, project, author)

      Oli.Publishing.update_publication(publication, %{published: DateTime.utc_now()})

      PartMappingRefreshWorker.perform_now()

      %{rows: rows, num_rows: 1} =
        Ecto.Adapters.SQL.query!(
          Oli.Repo,
          "SELECT * FROM part_mapping",
          []
        )

      assert [[nil, "automatic", ^revision_id]] = rows
    end
  end
end
