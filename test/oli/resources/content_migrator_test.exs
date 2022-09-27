defmodule Oli.Resources.ContentMigratorTest do
  use ExUnit.Case, async: true

  use Oli.DataCase

  alias Oli.Seeder
  alias Oli.Resources.ContentMigrator

  @content %{
    "model" => [
      %{
        "children" => [
          %{
            "children" => [
              %{
                "text" => "this is an example"
              }
            ],
            "id" => "1805793799",
            "type" => "p"
          },
          %{
            "children" => [
              %{
                "text" => ""
              }
            ],
            "display" => "block",
            "id" => "514519685",
            "src" => "https://example.png",
            "type" => "img"
          },
          %{
            "children" => [
              %{
                "text" => ""
              }
            ],
            "code" => "import SomeModule\n\ndef main() do\n  IO.inspect(\"Hello world!\")\nend",
            "id" => "2989562021",
            "language" => "Elixir",
            "type" => "code"
          }
        ],
        "id" => "2582575239",
        "purpose" => "example",
        "type" => "content"
      },
      %{
        "children" => [
          %{
            "children" => [
              %{
                "text" => "this is regular content without a purpose"
              }
            ],
            "id" => "1805793799",
            "type" => "p"
          }
        ],
        "id" => "2582575239",
        "purpose" => "none",
        "type" => "content"
      },
      %{
        "activity_id" => 32156,
        "children" => [],
        "id" => "1267008075",
        "purpose" => "none",
        "type" => "activity-reference"
      },
      %{
        "activity_id" => 31738,
        "children" => [],
        "id" => "873115071",
        "purpose" => "didigetthis",
        "type" => "activity-reference"
      }
    ]
  }

  @adaptive_content %{
    "advancedAuthoring" => true,
    "advancedDelivery" => true,
    "model" => [],
    "displayApplicationChrome" => false
  }

  describe "content migration" do
    setup %{} do
      author = author_fixture()

      Seeder.base_project_with_resource(author)
    end

    test "migrate to 0.1.0", %{publication: publication, project: project, author: author} do
      %{revision: revision} =
        Seeder.create_page("Page with Unversioned Model", publication, project, author, @content)

      migrated_content = ContentMigrator.migrate(revision.content, :page, to: :v0_1_0)

      assert migrated_content |> Map.get("version") == "0.1.0"

      assert migrated_content |> Map.get("model") |> Enum.at(0) |> Map.get("type") == "group"
      assert migrated_content |> Map.get("model") |> Enum.at(0) |> Map.get("purpose") == "example"

      assert migrated_content
             |> Map.get("model")
             |> Enum.at(0)
             |> Map.get("children")
             |> Enum.at(0)
             |> Map.get("type") == "content"

      assert migrated_content
             |> Map.get("model")
             |> Enum.at(0)
             |> Map.get("children")
             |> Enum.at(0)
             |> Map.get("id") == "2582575239"

      assert migrated_content |> Map.get("model") |> Enum.at(1) |> Map.get("type") == "content"
      assert migrated_content |> Map.get("model") |> Enum.at(1) |> Map.get("purpose") == nil

      assert migrated_content
             |> Map.get("model")
             |> Enum.at(1)
             |> Map.get("children")
             |> Enum.at(0)
             |> Map.get("type") == "p"

      assert migrated_content
             |> Map.get("model")
             |> Enum.at(1)
             |> Map.get("children")
             |> Enum.at(0)
             |> Map.get("id") == "1805793799"

      assert migrated_content |> Map.get("model") |> Enum.at(2) |> Map.get("type") ==
               "activity-reference"

      assert migrated_content |> Map.get("model") |> Enum.at(2) |> Map.get("purpose") == nil
      assert migrated_content |> Map.get("model") |> Enum.at(2) |> Map.get("id") == "1267008075"
      assert migrated_content |> Map.get("model") |> Enum.at(2) |> Map.get("children") == []
      assert migrated_content |> Map.get("model") |> Enum.at(2) |> Map.get("activity_id") == 32156

      assert migrated_content |> Map.get("model") |> Enum.at(3) |> Map.get("type") == "group"

      assert migrated_content |> Map.get("model") |> Enum.at(3) |> Map.get("purpose") ==
               "didigetthis"

      assert migrated_content
             |> Map.get("model")
             |> Enum.at(3)
             |> Map.get("children")
             |> Enum.at(0)
             |> Map.get("type") == "activity-reference"

      assert migrated_content
             |> Map.get("model")
             |> Enum.at(3)
             |> Map.get("children")
             |> Enum.at(0)
             |> Map.get("purpose") == nil

      assert migrated_content
             |> Map.get("model")
             |> Enum.at(3)
             |> Map.get("children")
             |> Enum.at(0)
             |> Map.get("id") == "873115071"

      assert migrated_content
             |> Map.get("model")
             |> Enum.at(3)
             |> Map.get("children")
             |> Enum.at(0)
             |> Map.get("children") == []

      assert migrated_content
             |> Map.get("model")
             |> Enum.at(3)
             |> Map.get("children")
             |> Enum.at(0)
             |> Map.get("activity_id") == 31738
    end

    test "adaptive page migration is skipped", %{
      publication: publication,
      project: project,
      author: author
    } do
      %{revision: revision} =
        Seeder.create_page(
          "Adaptive Page with Unversioned Model",
          publication,
          project,
          author,
          @adaptive_content
        )

      content = ContentMigrator.migrate(revision.content, :page, to: :v0_1_0)

      assert content |> Map.get("version") == nil

      assert content == @adaptive_content
    end
  end
end
