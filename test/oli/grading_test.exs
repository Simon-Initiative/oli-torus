defmodule Oli.GradingTest do
  use Oli.DataCase

  alias Oli.Grading

  describe "grading" do
    defp set_resources_as_graded(%{revision1: revision1, revision2: revision2} = map) do
      {:ok, revision1} = Oli.Resources.update_revision(revision1, %{graded: true})
      {:ok, revision2} = Oli.Resources.update_revision(revision2, %{graded: true})
      map = put_in(map.revision1, revision1)
      map = put_in(map.revision2, revision2)

      map
    end

    setup do
      Oli.Seeder.base_project_with_resource2()
      |> set_resources_as_graded
      |> Oli.Seeder.create_section()
      |> Oli.Seeder.create_section_resources()
      |> Oli.Seeder.add_users_to_section(:section, [:user1, :user2, :user3])
      |> Oli.Seeder.add_resource_accesses(:section, %{
        revision1: %{
          out_of: 20,
          scores: %{
            user1: 12,
            user2: 20,
            user3: 19
          }
        },
        revision2: %{
          out_of: 5,
          scores: %{
            user1: 0,
            user2: 3,
            user3: 5
          }
        }
      })
    end

    test "determine_page_out_of/2 correctly determines the adaptive max out of", %{
      section: section,
      revision1: r
    } do
      r = %{
        r
        | content: %{
            "advancedDelivery" => true
          }
      }

      assert Grading.determine_page_out_of(section.slug, r) == 1.0

      r = %{
        r
        | content: %{
            "advancedDelivery" => true,
            "custom" => %{}
          }
      }

      assert Grading.determine_page_out_of(section.slug, r) == 1.0

      r = %{
        r
        | content: %{
            "advancedDelivery" => true,
            "custom" => %{"totalScore" => "2.0"}
          }
      }

      assert Grading.determine_page_out_of(section.slug, r) == 2.0

      r = %{
        r
        | content: %{
            "advancedDelivery" => true,
            "custom" => %{"totalScore" => "not a number"}
          }
      }

      assert Grading.determine_page_out_of(section.slug, r) == 1.0

      r = %{
        r
        | content: %{
            "advancedDelivery" => true,
            "custom" => %{"totalScore" => 5}
          }
      }

      assert Grading.determine_page_out_of(section.slug, r) == 5

      r = %{
        r
        | content: %{
            "advancedDelivery" => true,
            "custom" => %{"totalScore" => 5.4}
          }
      }

      assert Grading.determine_page_out_of(section.slug, r) == 5.4

      r = %{
        r
        | content: %{
            "advancedDelivery" => true,
            "custom" => %{"totalScore" => %{"something" => "else"}}
          }
      }

      assert Grading.determine_page_out_of(section.slug, r) == 1.0

      r = %{
        r
        | content: %{
            "advancedDelivery" => true,
            "custom" => %{"totalScore" => 0.0}
          }
      }

      assert Grading.determine_page_out_of(section.slug, r) == 1.0
    end

    test "returns valid gradebook for section", %{
      section: section,
      revision1: revision1,
      revision2: revision2,
      user1: user1,
      user2: user2,
      user3: user3
    } do
      {gradebook, columns} = Grading.generate_gradebook_for_section(section)

      expected_gradebook =
        [
          %Grading.GradebookRow{
            scores: [
              %Grading.GradebookScore{
                label: "Page one",
                out_of: 20,
                resource_id: revision1.resource_id,
                score: 12,
                was_late: false
              },
              %Grading.GradebookScore{
                label: "Page two",
                out_of: 5,
                resource_id: revision2.resource_id,
                score: 0,
                was_late: false
              }
            ],
            user: user1
          },
          %Grading.GradebookRow{
            scores: [
              %Grading.GradebookScore{
                label: "Page one",
                out_of: 20,
                resource_id: revision1.resource_id,
                score: 20,
                was_late: false
              },
              %Grading.GradebookScore{
                label: "Page two",
                out_of: 5,
                resource_id: revision2.resource_id,
                score: 3,
                was_late: false
              }
            ],
            user: user2
          },
          %Grading.GradebookRow{
            scores: [
              %Grading.GradebookScore{
                label: "Page one",
                out_of: 20,
                resource_id: revision1.resource_id,
                score: 19,
                was_late: false
              },
              %Grading.GradebookScore{
                label: "Page two",
                out_of: 5,
                resource_id: revision2.resource_id,
                score: 5,
                was_late: false
              }
            ],
            user: user3
          }
        ]
        |> Enum.sort_by(& &1.user.email)

      expected_column_labels = ["Page one", "Page two"]

      assert {expected_gradebook, expected_column_labels} ==
               {gradebook |> Enum.sort_by(& &1.user.email), Enum.sort(columns)}
    end

    test "exports gradebook as CSV", %{section: section} do
      expected_csv = """
      Student,Page one,Page two\r
          Points Possible,20.0,5.0\r
      "Doe, Jane 0 (jane0@platform.example.edu)",12.0,0.0\r
      "Doe, Jane 1 (jane1@platform.example.edu)",20.0,3.0\r
      "Doe, Jane 2 (jane2@platform.example.edu)",19.0,5.0\r
      """

      csv = Grading.export_csv(section) |> Enum.join("")

      assert expected_csv == csv
    end
  end
end
