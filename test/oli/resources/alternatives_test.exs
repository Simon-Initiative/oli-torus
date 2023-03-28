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
    "alternatives_id" => "1",
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
    "alternatives_id" => "1",
    "default" => "three",
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

      by_id = %{
        "1" => %{
          id: 1,
          title: "group",
          options: [
            %{"name" => "one"},
            %{"name" => "two"},
          ],
          strategy: "select_all"
        }
      }

      assert Alternatives.select(
               %AlternativesStrategyContext{
                 user: student1,
                 section_slug: section.slug,
                 mode: :delivery,
                 alternative_groups_by_id: by_id
               },
               @select_all_el
             ) == [
               %Oli.Resources.Alternatives.Selection{
                 alternative: %{
                   "children" => [
                     %{
                       "children" => [%{"text" => "this is an example of one alternative"}],
                       "id" => "1805793799",
                       "type" => "p"
                     }
                   ],
                   "id" => "22345",
                   "type" => "alternative",
                   "value" => "one"
                 },
                 hidden: false
               },
               %Oli.Resources.Alternatives.Selection{
                 alternative: %{
                   "children" => [
                     %{
                       "children" => [%{"text" => "this is an example of a second alternative"}],
                       "id" => "18057937800",
                       "type" => "p"
                     }
                   ],
                   "id" => "22346",
                   "type" => "alternative",
                   "value" => "two"
                 },
                 hidden: false
               }
             ]
    end

    test "renders single alternative according to user_section_preference strategy", %{
      student1: student1,
      section: section
    } do
      ExtrinsicState.upsert_section(student1.id, section.slug, %{
        [ExtrinsicState.Key.alternatives_preference("group")] => "one"
      })

      by_id = %{
        "1" => %{
          id: 1,
          title: "group",
          options: [
            %{"name" => "one"},
            %{"name" => "two"},
          ],
          strategy: "user_section_preference"
        }
      }

      assert Alternatives.select(
               %AlternativesStrategyContext{
                 user: student1,
                 section_slug: section.slug,
                 mode: :delivery,
                 alternative_groups_by_id: by_id
               },
               @user_section_preference_el
             ) == [
               %Oli.Resources.Alternatives.Selection{
                 alternative: %{
                   "children" => [
                     %{
                       "children" => [%{"text" => "this is an example of one alternative"}],
                       "id" => "1805793799",
                       "type" => "p"
                     }
                   ],
                   "id" => "22345",
                   "type" => "alternative",
                   "value" => "one"
                 },
                 hidden: false
               },
               %Oli.Resources.Alternatives.Selection{
                 alternative: %{
                   "children" => [
                     %{
                       "children" => [%{"text" => "this is an example of a second alternative"}],
                       "id" => "18057937800",
                       "type" => "p"
                     }
                   ],
                   "id" => "22346",
                   "type" => "alternative",
                   "value" => "two"
                 },
                 hidden: true
               },
               %Oli.Resources.Alternatives.Selection{
                 alternative: %{
                   "children" => [
                     %{
                       "children" => [
                         %{"text" => "this is an example of a default third alternative"}
                       ],
                       "id" => "18057937800",
                       "type" => "p"
                     }
                   ],
                   "id" => "22346",
                   "type" => "alternative",
                   "value" => "three"
                 },
                 hidden: true
               }
             ]
    end

    test "renders default alternative with no preference set according to user_section_preference strategy",
         %{
           student1: student1,
           section: section
         } do

      by_id = %{
        "1" => %{
          id: 1,
          title: "group",
          options: [
            %{"name" => "one"},
            %{"name" => "two"},
          ],
          strategy: "user_section_preference"
        }
      }

      assert Alternatives.select(
               %AlternativesStrategyContext{
                 user: student1,
                 section_slug: section.slug,
                 mode: :delivery,
                 alternative_groups_by_id: by_id
               },
               @user_section_preference_el
             ) == [
               %Oli.Resources.Alternatives.Selection{
                 alternative: %{
                   "children" => [
                     %{
                       "children" => [%{"text" => "this is an example of one alternative"}],
                       "id" => "1805793799",
                       "type" => "p"
                     }
                   ],
                   "id" => "22345",
                   "type" => "alternative",
                   "value" => "one"
                 },
                 hidden: false
               },
               %Oli.Resources.Alternatives.Selection{
                 alternative: %{
                   "children" => [
                     %{
                       "children" => [%{"text" => "this is an example of a second alternative"}],
                       "id" => "18057937800",
                       "type" => "p"
                     }
                   ],
                   "id" => "22346",
                   "type" => "alternative",
                   "value" => "two"
                 },
                 hidden: true
               },
               %Oli.Resources.Alternatives.Selection{
                 alternative: %{
                   "children" => [
                     %{
                       "children" => [
                         %{"text" => "this is an example of a default third alternative"}
                       ],
                       "id" => "18057937800",
                       "type" => "p"
                     }
                   ],
                   "id" => "22346",
                   "type" => "alternative",
                   "value" => "three"
                 },
                 hidden: true
               }
             ]
    end
  end
end
