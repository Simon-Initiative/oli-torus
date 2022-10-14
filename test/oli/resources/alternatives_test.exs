defmodule Oli.Resources.AlternativesTest do
  use Oli.DataCase

  import Oli.Utils.Seeder.Utils

  alias Oli.Utils.Seeder
  alias Oli.Resources.Alternatives
  alias Oli.Resources.Alternatives.AlternativesStrategyContext
  alias Oli.Delivery.ExtrinsicState

  @select_all_el %{
    "type" => "alternatives",
    "id" => "12345",
    "strategy" => "select_all",
    "children" => [
      %{
        "type" => "alternative",
        "id" => "22345",
        "value" => "one",
        "children" => [
          %{
            "children" => [
              %{
                "text" => "this is an example of one alternative"
              }
            ],
            "id" => "1805793799",
            "type" => "p"
          }
        ]
      },
      %{
        "type" => "alternative",
        "id" => "22346",
        "value" => "two",
        "children" => [
          %{
            "children" => [
              %{
                "text" => "this is an example of a second alternative"
              }
            ],
            "id" => "18057937800",
            "type" => "p"
          }
        ]
      }
    ]
  }

  @user_section_preference_el %{
    "type" => "alternatives",
    "id" => "12345",
    "strategy" => "user_section_preference",
    "default" => "three",
    "preference_name" => "statistics_flavor",
    "children" => [
      %{
        "type" => "alternative",
        "id" => "22345",
        "value" => "one",
        "children" => [
          %{
            "children" => [
              %{
                "text" => "this is an example of one alternative"
              }
            ],
            "id" => "1805793799",
            "type" => "p"
          }
        ]
      },
      %{
        "type" => "alternative",
        "id" => "22346",
        "value" => "two",
        "children" => [
          %{
            "children" => [
              %{
                "text" => "this is an example of a second alternative"
              }
            ],
            "id" => "18057937800",
            "type" => "p"
          }
        ]
      },
      %{
        "type" => "alternative",
        "id" => "22346",
        "value" => "three",
        "children" => [
          %{
            "children" => [
              %{
                "text" => "this is an example of a default third alternative"
              }
            ],
            "id" => "18057937800",
            "type" => "p"
          }
        ]
      }
    ]
  }

  describe "alternatives" do
    setup do
      %{}
      |> Seeder.Project.create_author(author_tag: :author)
      |> Seeder.Project.create_sample_project(
        ref(:author),
        project_tag: :proj,
        publication_tag: :pub,
        unscored_page1_tag: :unscored_page1,
        unscored_page1_activity_tag: :unscored_page1_activity,
        scored_page2_tag: :scored_page2,
        scored_page2_activity_tag: :scored_page2_activity
      )
      |> Seeder.Project.ensure_published(ref(:pub))
      |> Seeder.Section.create_section(
        ref(:proj),
        ref(:pub),
        nil,
        %{},
        section_tag: :section
      )
      |> Seeder.Section.create_and_enroll_learner(
        ref(:section),
        %{},
        user_tag: :student1
      )
    end

    test "renders all alternatives using the select_all strategy", %{
      student1: student1,
      section: section
    } do
      assert Alternatives.select(
               %AlternativesStrategyContext{user: student1, section_slug: section.slug},
               @select_all_el
             ) == [
               %{
                 "type" => "alternative",
                 "id" => "22345",
                 "value" => "one",
                 "children" => [
                   %{
                     "children" => [
                       %{
                         "text" => "this is an example of one alternative"
                       }
                     ],
                     "id" => "1805793799",
                     "type" => "p"
                   }
                 ]
               },
               %{
                 "type" => "alternative",
                 "id" => "22346",
                 "value" => "two",
                 "children" => [
                   %{
                     "children" => [
                       %{
                         "text" => "this is an example of a second alternative"
                       }
                     ],
                     "id" => "18057937800",
                     "type" => "p"
                   }
                 ]
               }
             ]
    end

    test "renders single alternative according to user_section_preference strategy", %{
      student1: student1,
      section: section
    } do
      ExtrinsicState.upsert_section(student1.id, section.slug, %{
        [ExtrinsicState.Key.alternatives_preference("statistics_flavor")] => "two"
      })

      assert Alternatives.select(
               %AlternativesStrategyContext{user: student1, section_slug: section.slug},
               @user_section_preference_el
             ) == [
               %{
                 "type" => "alternative",
                 "id" => "22346",
                 "value" => "two",
                 "children" => [
                   %{
                     "children" => [
                       %{
                         "text" => "this is an example of a second alternative"
                       }
                     ],
                     "id" => "18057937800",
                     "type" => "p"
                   }
                 ]
               }
             ]
    end

    test "renders default alternative with no preference set according to user_section_preference strategy",
         %{
           student1: student1,
           section: section
         } do
      assert Alternatives.select(
               %AlternativesStrategyContext{user: student1, section_slug: section.slug},
               @user_section_preference_el
             ) == [
               %{
                 "type" => "alternative",
                 "id" => "22346",
                 "value" => "three",
                 "children" => [
                   %{
                     "children" => [
                       %{
                         "text" => "this is an example of a default third alternative"
                       }
                     ],
                     "id" => "18057937800",
                     "type" => "p"
                   }
                 ]
               }
             ]
    end
  end
end
