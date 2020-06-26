defmodule Oli.Qa.ContentTest do
  use Oli.DataCase
  alias Oli.Qa.Reviewers.Content
  alias Oli.Qa.Warnings

  describe "qa content checks" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.add_review("content", :review)
      |> Seeder.add_page(%{
        content: %{
          "model" => [
            %{
              "children" => [
                %{
                  "children" => [
                    %{"text" => " "},
                    %{
                      "children" => [%{"text" => "link"}],
                      "href" => "gg",
                      "id" => "1914651063",
                      "target" => "self",
                      "type" => "a"
                    },
                    %{"text" => ""}
                  ],
                  "id" => "3636822762",
                  "type" => "p"
                }
              ],
              "id" => "481882791",
              "purpose" => "None",
              "type" => "content"
            }
          ]
        }
      }, :page_invalid_link)
      |> Seeder.add_page(%{
        content: %{
          "model" => [
            %{
              "children" => [
                %{
                  "children" => [
                    %{"text" => " "},
                    %{
                      "children" => [%{"text" => "link"}],
                      "href" => "https://www.google.com",
                      "id" => "1914651063",
                      "target" => "self",
                      "type" => "a"
                    },
                    %{"text" => ""}
                  ],
                  "id" => "3636822762",
                  "type" => "p"
                }
              ],
              "id" => "481882791",
              "purpose" => "None",
              "type" => "content"
            }
          ]
        }
      }, :page_valid_link)
    end

    test "validates uris", %{project: project, review: review, page_invalid_link: page_invalid_link, page_valid_link: page_valid_link} do

      Content.broken_uris(review, project.slug)
      warnings = Warnings.list_active_warnings(project.id)

      # valid link
      assert !Enum.find(warnings, & &1.revision.id == page_valid_link.revision.id)
      # invalid link
      assert Enum.find(warnings, & &1.revision.id == page_invalid_link.revision.id)
    end

  end
end
