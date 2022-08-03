defmodule Oli.Delivery.ActivityProviderTest do
  use Oli.DataCase

  alias Oli.Delivery.ActivityProvider
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Delivery.ActivityProvider.Result

  defp index_of(prototypes, list) do
    collection = MapSet.new(list)
    Enum.find_index(prototypes, fn p -> MapSet.member?(collection, p.revision.resource_id) end)
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
      section: section
    } do
      source = %Source{
        publication_id: publication.id,
        blacklisted_activity_ids: [],
        section_slug: section.slug
      }

      %Result{errors: errors, prototypes: prototypes} =
        ActivityProvider.provide(
          page.revision,
          source,
          [],
          Oli.Publishing.DeliveryResolver
        )

      assert length(errors) == 0

      assert length(prototypes) == 2
      assert Enum.at(prototypes, 0).revision.resource_id == activity1.revision.resource_id
      assert Enum.at(prototypes, 1).revision.resource_id == activity2.revision.resource_id
    end
  end

  describe "fulfilling selections" do
    defp assert_one_of(resource_id, tag_collection) do
      present =
        case(Enum.find(tag_collection, nil, fn t -> t.revision.resource_id == resource_id end)) do
          nil -> false
          _ -> true
        end

      assert present == true
    end

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
      page: page,
      publication: publication,
      section: section,
      o1: o1
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
          %{page.revision | content: content},
          source,
          [],
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

    test "fulfilling multiple statics and selections", %{
      activity1: activity1,
      activity2: activity2,
      activity3: activity3,
      activity6: activity6,
      activity7: activity7,
      page: page,
      publication: publication,
      section: section,
      o1: o1
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
        prototypes: prototypes,
        transformed_content: transformed_content
      } =
        ActivityProvider.provide(
          %{page.revision | content: content},
          source,
          [],
          Oli.Publishing.DeliveryResolver
        )

      assert length(errors) == 0

      assert length(prototypes) == 4
      assert Enum.at(prototypes, 0).revision.resource_id == activity6.revision.resource_id

      assert_one_of(Enum.at(prototypes, 1).revision.resource_id, [activity1, activity2, activity3])

      assert Enum.at(prototypes, 2).revision.resource_id == activity7.revision.resource_id

      assert_one_of(Enum.at(prototypes, 3).revision.resource_id, [activity1, activity2, activity3])

      # This verifies that the second selection cannot pick an activity that the first selection did
      refute Enum.at(prototypes, 1).revision.resource_id ==
               Enum.at(prototypes, 3).revision.resource_id

      model = Map.get(transformed_content, "model")
      assert length(model) == 4

      static_id1 = activity6.revision.resource_id
      banked_id1 = Enum.at(prototypes, 1).revision.resource_id
      static_id2 = activity7.revision.resource_id
      banked_id2 = Enum.at(prototypes, 3).revision.resource_id

      assert [
               %{"type" => "activity-reference", "activity_id" => ^static_id1},
               %{
                 "type" => "activity-reference",
                 "activity_id" => ^banked_id1,
                 "source-selection" => "2"
               },
               %{"type" => "activity-reference", "activity_id" => ^static_id2},
               %{
                 "type" => "activity-reference",
                 "activity_id" => ^banked_id2,
                 "source-selection" => "4"
               }
             ] = model
    end

    test "ensures subsequent selections are constrained via implicit blacklist", %{
      activity1: activity1,
      activity2: activity2,
      activity3: activity3,
      page: page,
      publication: publication,
      section: section,
      o1: o1
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
          %{page.revision | content: content},
          source,
          [],
          Oli.Publishing.DeliveryResolver
        )

      assert length(errors) == 0

      assert length(prototypes) == 3

      assert_one_of(Enum.at(prototypes, 0).revision.resource_id, [activity1, activity2, activity3])

      assert_one_of(Enum.at(prototypes, 1).revision.resource_id, [activity1, activity2, activity3])

      assert_one_of(Enum.at(prototypes, 2).revision.resource_id, [activity1, activity2, activity3])

      # This verifies that the second selection cannot pick an activity that the first selection did.
      # The activity provider internal logic prevents this.
      refute Enum.at(prototypes, 2).revision.resource_id ==
               Enum.at(prototypes, 0).revision.resource_id or
               Enum.at(prototypes, 2).revision.resource_id ==
                 Enum.at(prototypes, 1).revision.resource_id

      model = Map.get(transformed_content, "model")
      assert length(model) == 3

      banked_id1 = Enum.at(prototypes, 0).revision.resource_id
      banked_id2 = Enum.at(prototypes, 1).revision.resource_id
      banked_id3 = Enum.at(prototypes, 2).revision.resource_id

      assert [
               %{
                 "type" => "activity-reference",
                 "activity_id" => ^banked_id1,
                 "source-selection" => "2"
               },
               %{
                 "type" => "activity-reference",
                 "activity_id" => ^banked_id2,
                 "source-selection" => "2"
               },
               %{
                 "type" => "activity-reference",
                 "activity_id" => ^banked_id3,
                 "source-selection" => "4"
               }
             ] = model
    end

    test "triggers a partial selection fulfillment error", %{
      activity1: activity1,
      activity2: activity2,
      activity3: activity3,
      page: page,
      publication: publication,
      section: section,
      o1: o1
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
          %{page.revision | content: content},
          source,
          [],
          Oli.Publishing.DeliveryResolver
        )

      assert length(errors) == 1

      assert String.contains?(
               Enum.at(errors, 0),
               "Selection failed to fulfill completely with 1 missing activities"
             )

      assert length(prototypes) == 3

      assert_one_of(Enum.at(prototypes, 0).revision.resource_id, [activity1, activity2, activity3])

      assert_one_of(Enum.at(prototypes, 1).revision.resource_id, [activity1, activity2, activity3])

      assert_one_of(Enum.at(prototypes, 2).revision.resource_id, [activity1, activity2, activity3])

      # This verifies that the second selection cannot pick an activity that the first selection did.
      # The activity provider internal logic prevents this.
      refute Enum.at(prototypes, 2).revision.resource_id ==
               Enum.at(prototypes, 0).revision.resource_id or
               Enum.at(prototypes, 2).revision.resource_id ==
                 Enum.at(prototypes, 1).revision.resource_id

      model = Map.get(transformed_content, "model")
      assert length(model) == 3

      banked_id1 = Enum.at(prototypes, 0).revision.resource_id
      banked_id2 = Enum.at(prototypes, 1).revision.resource_id
      banked_id3 = Enum.at(prototypes, 2).revision.resource_id

      assert [
               %{
                 "type" => "activity-reference",
                 "activity_id" => ^banked_id1,
                 "source-selection" => "2"
               },
               %{
                 "type" => "activity-reference",
                 "activity_id" => ^banked_id2,
                 "source-selection" => "2"
               },
               %{
                 "type" => "activity-reference",
                 "activity_id" => ^banked_id3,
                 "source-selection" => "4"
               }
             ] = model
    end
  end
end
