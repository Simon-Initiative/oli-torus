defmodule Oli.Authoring.Editing.ActivityBankTest do
  use Oli.DataCase

  alias Oli.Authoring.Editing.ActivityBank
  alias Oli.Seeder

  describe "query/4" do
    setup [:project_with_activity_bank]

    test "queries banked activities from JSON-like logic and paging maps", %{
      author: author,
      project: project
    } do
      assert {:ok, result} =
               ActivityBank.query(
                 project.slug,
                 author,
                 %{
                   "conditions" => %{
                     "fact" => "objectives",
                     "operator" => "contains",
                     "value" => [2]
                   }
                 },
                 %{"limit" => 5, "offset" => 0}
               )

      assert result.totalCount == 1
      assert result.rowCount == 1
      assert [%{title: "Banked objective 2"}] = result.rows
    end

    test "does not return embedded or deleted activities", %{author: author, project: project} do
      assert {:ok, result} =
               ActivityBank.query(
                 project.slug,
                 author,
                 %{"conditions" => nil},
                 %{"limit" => 10, "offset" => 0}
               )

      assert Enum.map(result.rows, & &1.title) == ["Banked objective 1", "Banked objective 2"]
      assert result.totalCount == 2
    end
  end

  describe "context/2" do
    setup [:project_with_activity_bank]

    test "builds the Activity Bank editor context", %{author: author, project: project} do
      assert {:ok, context} = ActivityBank.context(project.slug, author)

      assert context.authorEmail == author.email
      assert context.projectSlug == project.slug
      assert context.totalCount == 2
      assert is_map(context.editorMap)
      assert is_list(context.allObjectives)
      assert is_list(context.allTags)
    end
  end

  defp project_with_activity_bank(_context) do
    map = Seeder.base_project_with_resource2()

    Seeder.create_activity(
      %{
        scope: :banked,
        objectives: %{"1" => [1]},
        title: "Banked objective 1",
        content: %{model: %{stem: "this is the first question"}}
      },
      map.publication,
      map.project,
      map.author
    )

    Seeder.create_activity(
      %{
        scope: :banked,
        objectives: %{"1" => [2]},
        title: "Banked objective 2",
        content: %{model: %{stem: "this is the second question"}}
      },
      map.publication,
      map.project,
      map.author
    )

    Seeder.create_activity(
      %{
        scope: :banked,
        deleted: true,
        objectives: %{"1" => [2]},
        title: "Deleted banked",
        content: %{model: %{stem: "this is deleted"}}
      },
      map.publication,
      map.project,
      map.author
    )

    Seeder.create_activity(
      %{
        scope: :embedded,
        objectives: %{"1" => [2]},
        title: "Embedded",
        content: %{model: %{stem: "this is embedded"}}
      },
      map.publication,
      map.project,
      map.author
    )

    {:ok, map}
  end
end
