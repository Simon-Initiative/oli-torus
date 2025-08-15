defmodule Oli.Delivery.ActivityProviderTest do
  use Oli.DataCase

  alias Oli.Delivery.ActivityProvider
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Delivery.ActivityProvider.{Result, AttemptPrototype}

  defp index_of(prototypes, list) do
    collection = MapSet.new(list)
    Enum.find_index(prototypes, fn p -> MapSet.member?(collection, p.revision.resource_id) end)
  end

  defp index_of_except(prototypes, list, except) do
    collection = MapSet.new(list)

    Enum.with_index(prototypes)
    |> Enum.find_index(fn {p, index} ->
      index != except and MapSet.member?(collection, p.revision.resource_id)
    end)
  end

  describe "fulfilling static activity references with adaptive page" do
    setup do
      content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [
                %{
                  "rule" => "input like {a}",
                  "score" => 10,
                  "id" => "r1",
                  "feedback" => %{"id" => "1", "content" => "yes"}
                }
              ],
              "hints" => [],
              "scoringStrategy" => "best",
              "evaluationStrategy" => "regex"
            }
          ]
        }
      }

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_objective("objective one", :o1)

      attached = %{"1" => [map.o1.revision.resource_id]}

      # Create banked activities
      map =
        Seeder.add_activity(
          map,
          %{title: "one", content: content, objectives: attached, scope: "embedded"},
          :activity1
        )
        |> Seeder.add_activity(
          %{title: "two", content: content, objectives: attached, scope: "embedded"},
          :activity2
        )
        |> Seeder.add_user(%{}, :user1)

      attrs = %{
        title: "page1",
        content: %{
          "advancedDelivery" => true,
          "model" => [
            %{
              "type" => "group",
              "id" => "1",
              "children" => [
                %{
                  "type" => "activity-reference",
                  "activity_id" => map.activity1.revision.resource_id,
                  "id" => "2"
                },
                %{
                  "type" => "group",
                  "children" => [
                    %{
                      "type" => "activity-reference",
                      "activity_id" => map.activity2.revision.resource_id,
                      "id" => "4"
                    }
                  ],
                  "id" => "3"
                }
              ]
            }
          ]
        }
      }

      Seeder.add_page(map, attrs, :page)
      |> Seeder.create_section_resources()
    end

    test "fulfills static references below groups", %{
      activity1: activity1,
      activity2: activity2,
      page: page,
      publication: publication,
      section: section,
      user1: user
    } do
      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: section.slug
      }

      %Result{errors: errors, prototypes: prototypes} =
        ActivityProvider.provide(
          page.revision.content,
          source,
          [],
          [],
          user,
          section.slug,
          Oli.Publishing.DeliveryResolver
        )

      assert length(errors) == 0

      assert length(prototypes) == 2
      assert Enum.at(prototypes, 0).revision.resource_id == activity1.revision.resource_id
      assert Enum.at(prototypes, 1).revision.resource_id == activity2.revision.resource_id
    end
  end

  describe "fulfilling selections" do
    setup do
      content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [
                %{
                  "rule" => "input like {a}",
                  "score" => 10,
                  "id" => "r1",
                  "feedback" => %{"id" => "1", "content" => "yes"}
                }
              ],
              "hints" => [],
              "scoringStrategy" => "best",
              "evaluationStrategy" => "regex"
            }
          ]
        }
      }

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_objective("objective one", :o1)

      attached = %{"1" => [map.o1.revision.resource_id]}
      no_attached = %{"1" => []}

      # Create banked activities
      map =
        Seeder.add_activity(
          map,
          %{title: "one", content: content, objectives: attached, scope: "banked"},
          :activity1
        )
        |> Seeder.add_activity(
          %{title: "two", content: content, objectives: attached, scope: "banked"},
          :activity2
        )
        |> Seeder.add_activity(
          %{title: "three", content: content, objectives: attached, scope: "banked"},
          :activity3
        )
        |> Seeder.add_activity(
          %{title: "four", content: content, objectives: no_attached, scope: "banked"},
          :activity4
        )
        |> Seeder.add_activity(
          %{title: "five", content: content, objectives: no_attached, scope: "banked"},
          :activity5
        )
        # Create activities to place statically in the page
        |> Seeder.add_activity(
          %{title: "six", content: content, objectives: no_attached, scope: "embedded"},
          :activity6
        )
        |> Seeder.add_activity(
          %{title: "seven", content: content, objectives: no_attached, scope: "embedded"},
          :activity7
        )
        |> Seeder.add_user(%{}, :user1)

      attrs = %{
        title: "page1",
        content: %{
          "model" => []
        }
      }

      Seeder.add_page(map, attrs, :page)
      |> Seeder.create_section_resources()
    end

    test "fulfilling one static and one selection", %{
      activity1: activity1,
      activity2: activity2,
      activity3: activity3,
      activity6: activity6,
      publication: publication,
      section: section,
      o1: o1,
      user1: user
    } do
      content = %{
        "model" => [
          %{
            "type" => "activity-reference",
            "activity_id" => activity6.revision.resource_id,
            "id" => "1"
          },
          %{
            "type" => "selection",
            "count" => 1,
            "purpose" => "none",
            "logic" => %{
              "conditions" => %{
                "fact" => "objectives",
                "operator" => "contains",
                "value" => [o1.revision.resource_id]
              }
            },
            "id" => "2"
          }
        ]
      }

      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: section.slug
      }

      %Result{
        errors: errors,
        prototypes: prototypes,
        transformed_content: transformed_content
      } =
        ActivityProvider.provide(
          content,
          source,
          [],
          [],
          user,
          section.slug,
          Oli.Publishing.DeliveryResolver
        )

      assert length(errors) == 0

      assert length(prototypes) == 2

      index6 = index_of(prototypes, [activity6.revision.resource_id])

      other =
        index_of(prototypes, [
          activity1.revision.resource_id,
          activity2.revision.resource_id,
          activity3.revision.resource_id
        ])

      refute index6 == other
      refute is_nil(other)
      refute is_nil(index6)

      model = Map.get(transformed_content, "model")
      assert length(model) == 2

      static_id = activity6.revision.resource_id
      banked_id = Enum.at(prototypes, other).revision.resource_id

      assert [
               %{"type" => "activity-reference", "activity_id" => ^static_id},
               %{
                 "type" => "activity-reference",
                 "activity_id" => ^banked_id,
                 "source-selection" => "2"
               }
             ] = model
    end

    test "completely constraining a selection via existing prototypes", %{
      activity1: activity1,
      publication: publication,
      section: section,
      o1: o1,
      user1: user
    } do
      content = %{
        "model" => [
          %{
            "type" => "selection",
            "count" => 1,
            "purpose" => "none",
            "logic" => %{
              "conditions" => %{
                "fact" => "objectives",
                "operator" => "contains",
                "value" => [o1.revision.resource_id]
              }
            },
            "id" => "2"
          }
        ]
      }

      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: section.slug
      }

      %Result{
        errors: errors,
        prototypes: prototypes
      } =
        ActivityProvider.provide(
          content,
          source,
          [],
          [%AttemptPrototype{revision: activity1.revision, selection_id: "2"}],
          user,
          section.slug,
          Oli.Publishing.DeliveryResolver
        )

      assert length(errors) == 0
      assert length(prototypes) == 1
      assert Enum.at(prototypes, 0).revision.id == activity1.revision.id
    end

    test "partially constraining a selection via existing prototypes", %{
      activity1: activity1,
      activity2: activity2,
      activity3: activity3,
      publication: publication,
      section: section,
      o1: o1,
      user1: user
    } do
      content = %{
        "model" => [
          %{
            "type" => "selection",
            "count" => 3,
            "purpose" => "none",
            "logic" => %{
              "conditions" => %{
                "fact" => "objectives",
                "operator" => "contains",
                "value" => [o1.revision.resource_id]
              }
            },
            "id" => "2"
          }
        ]
      }

      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: section.slug
      }

      %Result{
        errors: errors,
        prototypes: prototypes
      } =
        ActivityProvider.provide(
          content,
          source,
          [],
          [
            %AttemptPrototype{revision: activity1.revision, selection_id: "2"},
            %AttemptPrototype{revision: activity2.revision, selection_id: "2"}
          ],
          user,
          section.slug,
          Oli.Publishing.DeliveryResolver
        )

      assert length(errors) == 0
      assert length(prototypes) == 3

      index1 = index_of(prototypes, [activity1.revision.resource_id])
      index2 = index_of(prototypes, [activity2.revision.resource_id])
      index3 = index_of(prototypes, [activity3.revision.resource_id])

      assert MapSet.new([index1, index2, index3]) |> MapSet.size() == 3
      refute is_nil(index1)
      refute is_nil(index2)
      refute is_nil(index3)
    end

    test "fulfilling multiple statics and selections", %{
      activity1: activity1,
      activity2: activity2,
      activity3: activity3,
      activity6: activity6,
      activity7: activity7,
      publication: publication,
      section: section,
      o1: o1,
      user1: user
    } do
      content = %{
        "model" => [
          %{
            "type" => "activity-reference",
            "activity_id" => activity6.revision.resource_id,
            "id" => "1"
          },
          %{
            "type" => "selection",
            "count" => 1,
            "purpose" => "none",
            "logic" => %{
              "conditions" => %{
                "fact" => "objectives",
                "operator" => "contains",
                "value" => [o1.revision.resource_id]
              }
            },
            "id" => "2"
          },
          %{
            "type" => "activity-reference",
            "activity_id" => activity7.revision.resource_id,
            "id" => "3"
          },
          %{
            "type" => "selection",
            "count" => 1,
            "purpose" => "none",
            "logic" => %{
              "conditions" => %{
                "fact" => "objectives",
                "operator" => "contains",
                "value" => [o1.revision.resource_id]
              }
            },
            "id" => "4"
          }
        ]
      }

      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: section.slug
      }

      %Result{
        errors: errors,
        prototypes: prototypes
      } =
        ActivityProvider.provide(
          content,
          source,
          [],
          [],
          user,
          section.slug,
          Oli.Publishing.DeliveryResolver
        )

      assert length(errors) == 0
      assert length(prototypes) == 4

      index6 = index_of(prototypes, [activity6.revision.resource_id])
      index7 = index_of(prototypes, [activity7.revision.resource_id])

      other =
        index_of(prototypes, [
          activity1.revision.resource_id,
          activity2.revision.resource_id,
          activity3.revision.resource_id
        ])

      other2 =
        index_of_except(
          prototypes,
          [
            activity1.revision.resource_id,
            activity2.revision.resource_id,
            activity3.revision.resource_id
          ],
          other
        )

      assert MapSet.new([index6, index7, other, other2]) |> MapSet.size() == 4

      # This verifies that the second selection cannot pick an activity that the first selection did
      refute Enum.at(prototypes, other).revision.resource_id ==
               Enum.at(prototypes, other2).revision.resource_id
    end

    test "ensures subsequent selections are constrained via implicit blacklist", %{
      activity1: activity1,
      activity2: activity2,
      activity3: activity3,
      publication: publication,
      section: section,
      o1: o1,
      user1: user
    } do
      content = %{
        "model" => [
          %{
            "type" => "selection",
            "count" => 2,
            "purpose" => "none",
            "logic" => %{
              "conditions" => %{
                "fact" => "objectives",
                "operator" => "contains",
                "value" => [o1.revision.resource_id]
              }
            },
            "id" => "2"
          },
          %{
            "type" => "selection",
            "count" => 1,
            "purpose" => "none",
            "logic" => %{
              "conditions" => %{
                "fact" => "objectives",
                "operator" => "contains",
                "value" => [o1.revision.resource_id]
              }
            },
            "id" => "4"
          }
        ]
      }

      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: section.slug
      }

      %Result{
        errors: errors,
        prototypes: prototypes,
        transformed_content: transformed_content
      } =
        ActivityProvider.provide(
          content,
          source,
          [],
          [],
          user,
          section.slug,
          Oli.Publishing.DeliveryResolver
        )

      assert length(errors) == 0

      assert length(prototypes) == 3

      activities = [
        activity1.revision.resource_id,
        activity2.revision.resource_id,
        activity3.revision.resource_id
      ]

      index1 = index_of(prototypes, activities)

      activities =
        Enum.filter(activities, fn a -> Enum.at(prototypes, index1).revision.resource_id != a end)

      index2 = index_of(prototypes, activities)

      activities =
        Enum.filter(activities, fn a -> Enum.at(prototypes, index2).revision.resource_id != a end)

      index3 = index_of(prototypes, activities)

      refute is_nil(index1)
      refute is_nil(index2)
      refute is_nil(index3)

      assert MapSet.new([index1, index2, index3]) |> MapSet.size() == 3

      model = Map.get(transformed_content, "model")
      assert length(model) == 3

      assert [
               %{
                 "type" => "activity-reference"
               },
               %{
                 "type" => "activity-reference"
               },
               %{
                 "type" => "activity-reference"
               }
             ] = model
    end

    test "triggers a partial selection fulfillment error", %{
      activity1: activity1,
      activity2: activity2,
      activity3: activity3,
      publication: publication,
      section: section,
      o1: o1,
      user1: user
    } do
      content = %{
        "model" => [
          %{
            "type" => "selection",
            "count" => 2,
            "purpose" => "none",
            "logic" => %{
              "conditions" => %{
                "fact" => "objectives",
                "operator" => "contains",
                "value" => [o1.revision.resource_id]
              }
            },
            "id" => "2"
          },
          %{
            "type" => "selection",
            # this is the key change to trigger the partial failure
            "count" => 2,
            "purpose" => "none",
            "logic" => %{
              "conditions" => %{
                "fact" => "objectives",
                "operator" => "contains",
                "value" => [o1.revision.resource_id]
              }
            },
            "id" => "4"
          }
        ]
      }

      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: section.slug
      }

      %Result{
        errors: errors,
        prototypes: prototypes,
        transformed_content: transformed_content
      } =
        ActivityProvider.provide(
          content,
          source,
          [],
          [],
          user,
          section.slug,
          Oli.Publishing.DeliveryResolver
        )

      assert length(errors) == 1

      assert String.contains?(
               Enum.at(errors, 0),
               "Selection failed to fulfill completely with 1 missing activities"
             )

      assert length(prototypes) == 3

      activities = [
        activity1.revision.resource_id,
        activity2.revision.resource_id,
        activity3.revision.resource_id
      ]

      index1 = index_of(prototypes, activities)

      activities =
        Enum.filter(activities, fn a -> Enum.at(prototypes, index1).revision.resource_id != a end)

      index2 = index_of(prototypes, activities)

      activities =
        Enum.filter(activities, fn a -> Enum.at(prototypes, index2).revision.resource_id != a end)

      index3 = index_of(prototypes, activities)

      refute is_nil(index1)
      refute is_nil(index2)
      refute is_nil(index3)

      assert MapSet.new([index1, index2, index3]) |> MapSet.size() == 3

      model = Map.get(transformed_content, "model")
      assert length(model) == 3

      assert [
               %{
                 "type" => "activity-reference"
               },
               %{
                 "type" => "activity-reference"
               },
               %{
                 "type" => "activity-reference"
               }
             ] = model
    end
  end
end
