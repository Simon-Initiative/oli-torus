defmodule Oli.Qa.AccessibilityTest do
  use Oli.DataCase
  alias Oli.Qa.Reviewers.Accessibility
  alias Oli.Qa.Warnings

  describe "qa accessibility checks" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.add_review("content", :review)
      |> Seeder.add_page(
        %{
          content: %{
            "model" => [
              %{
                "children" => [
                  %{
                    "children" => [
                      %{
                        "type" => "img",
                        "src" =>
                          "https://upload.wikimedia.org/wikipedia/commons/8/86/Map_of_territorial_growth_1775.jpg",
                        "children" => [
                          %{
                            "text" => ""
                          }
                        ],
                        "id" => 2_607_239_386,
                        "caption" =>
                          "Eastern North America in 1775. The British Province of Quebec, the Thirteen Colonies on the Atlantic coast, and the Indian Reserve as defined by the Royal Proclamation of 1763. The border between the red and pink areas represents the 1763 \"Proclamation line\", while the orange area represents the Spanish claim.",
                        "alt" => "Boundary between Mississippi River and 49th Parallel"
                      }
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
        },
        :image_has_alt
      )
      |> Seeder.add_page(
        %{
          content: %{
            "model" => [
              %{
                "children" => [
                  %{
                    "type" => "img",
                    "src" =>
                      "https://upload.wikimedia.org/wikipedia/commons/8/86/Map_of_territorial_growth_1775.jpg",
                    "children" => [
                      %{
                        "text" => ""
                      }
                    ],
                    "id" => "1",
                    "caption" =>
                      "Eastern North America in 1775. The British Province of Quebec, the Thirteen Colonies on the Atlantic coast, and the Indian Reserve as defined by the Royal Proclamation of 1763. The border between the red and pink areas represents the 1763 \"Proclamation line\", while the orange area represents the Spanish claim."
                  },
                  %{
                    "type" => "img",
                    "src" =>
                      "https://upload.wikimedia.org/wikipedia/commons/f/ff/Wikipedia_logo_593.jpg",
                    "children" => [
                      %{
                        "text" => ""
                      }
                    ],
                    "id" => "2",
                    "caption" => "Wikipedia logo"
                  }
                ],
                "id" => "481882791",
                "purpose" => "None",
                "type" => "content"
              }
            ]
          }
        },
        :image_no_alt
      )
    end

    test "missing alt text", %{
      project: project,
      review: review,
      image_has_alt: image_has_alt,
      image_no_alt: image_no_alt
    } do
      Accessibility.missing_alt_text(review)
      warnings = Warnings.list_active_warnings(project.id)

      # images
      # no alt text
      assert Enum.find(warnings, &(&1.revision.id == image_no_alt.revision.id))
      # has alt text
      assert !Enum.find(warnings, &(&1.revision.id == image_has_alt.revision.id))

      assert Enum.any?(warnings, &(&1.content["id"] == "1"))
      assert Enum.any?(warnings, &(&1.content["id"] == "2"))
    end
  end
end
