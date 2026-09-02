defmodule Oli.Resources.AlternativesTest do
  use Oli.DataCase

  import Oli.Factory
  import Oli.Utils.Seeder.Utils
  import ExUnit.CaptureLog

  alias Oli.Utils.Seeder
  alias Oli.Resources.Alternatives
  alias Oli.Resources.Alternatives.AlternativesStrategyContext
  alias Oli.Delivery.ExtrinsicState
  alias Oli.Delivery.Metrics
  alias Oli.Experiments.Scope
  alias Oli.Experiments.Schemas.{Assignment, Condition, ExperimentDefinition, ExperimentSection}

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

  describe "normalize_strategy/1" do
    test "normalizes the legacy experiment alias and accepts the canonical strategy" do
      assert {:ok, "experiment_controlled"} =
               Alternatives.normalize_strategy("upgrade_decision_point")

      assert {:ok, "experiment_controlled"} =
               Alternatives.normalize_strategy("experiment_controlled")
    end

    test "fails closed for unsupported strategies" do
      assert {:error, :unsupported_strategy} = Alternatives.normalize_strategy("unknown")
    end
  end

  describe "apply_experiment_decisions/3" do
    test "keeps only each persisted root selection for activity realization" do
      content = %{
        "model" => [
          experiment_placement("placement-a", 10, %{
            "control" => [activity_reference(101)],
            "variant" => [activity_reference(102), activity_reference(103)]
          }),
          experiment_placement("placement-b", 20, %{
            "control" => [activity_reference(201), activity_reference(202)],
            "variant" => [activity_reference(203)]
          }),
          activity_reference(999)
        ]
      }

      groups = %{
        10 => %{strategy: "experiment_controlled"},
        20 => %{strategy: "upgrade_decision_point"}
      }

      decisions = %{
        "placement-a" => %{status: :assigned, option_id: "variant"},
        "placement-b" => %{status: :assigned, option_id: "control"}
      }

      selected = Alternatives.apply_experiment_decisions(content, groups, decisions)

      assert activity_ids(selected) == [102, 103, 201, 202, 999]
    end

    test "uses the first local branch for an applicable experiment placement without assignment" do
      content = %{
        "model" => [
          experiment_placement("placement", 10, %{
            "control" => [activity_reference(101)],
            "variant" => [activity_reference(102)]
          })
        ]
      }

      selected =
        Alternatives.apply_experiment_decisions(
          content,
          %{10 => %{strategy: "experiment_controlled"}},
          %{"placement" => %{status: :no_experiment}}
        )

      assert activity_ids(selected) == [101]
    end

    test "applies experiment decisions inside ordinary containers" do
      placement =
        experiment_placement("nested-in-group", 10, %{
          "control" => [activity_reference(101)],
          "variant" => [activity_reference(102)]
        })

      content = %{
        "model" => [%{"type" => "group", "id" => "group", "children" => [placement]}]
      }

      selected =
        Alternatives.apply_experiment_decisions(
          content,
          %{10 => %{strategy: "experiment_controlled"}},
          %{"nested-in-group" => %{status: :assigned, option_id: "variant"}}
        )

      assert activity_ids(selected) == [102]
    end

    test "fails closed to the first branch for Alternatives nested within Alternatives" do
      nested =
        experiment_placement("nested", 10, %{
          "control" => [activity_reference(101)],
          "variant" => [activity_reference(102)]
        })

      content = %{
        "model" => [
          experiment_placement("learner-choice", 20, %{
            "one" => [%{"type" => "group", "id" => "group", "children" => [nested]}]
          })
        ]
      }

      parent = self()

      log =
        capture_log(fn ->
          selected =
            Alternatives.apply_experiment_decisions(
              content,
              %{
                10 => %{strategy: "experiment_controlled"},
                20 => %{strategy: "user_section_preference"}
              },
              %{"nested" => %{status: :assigned, option_id: "variant"}}
            )

          send(parent, {:selected, selected})
        end)

      assert_receive {:selected, selected}
      assert log =~ "Rendering invalid Alternatives placement nested within Alternatives"

      [outer] = selected["model"]
      [outer_branch] = outer["children"]
      [group] = outer_branch["children"]
      [collapsed_nested] = group["children"]
      assert length(collapsed_nested["children"]) == 1
      assert activity_ids(selected) == [101]
    end

    test "visible activities alone drive partial and exact 100 percent page completion" do
      section = insert(:section)
      user = insert(:user)
      page_revision = insert(:revision, full_progress_pct: 100)

      activity_revisions =
        Map.new(1..7, fn id ->
          revision = insert(:revision)
          {id, revision}
        end)

      content = %{
        "model" => [
          experiment_placement("placement-a", 10, %{
            "control" => [activity_reference(activity_revisions[1].resource_id)],
            "variant" => [
              activity_reference(activity_revisions[2].resource_id),
              activity_reference(activity_revisions[3].resource_id)
            ]
          }),
          experiment_placement("placement-b", 20, %{
            "control" => [
              activity_reference(activity_revisions[4].resource_id),
              activity_reference(activity_revisions[5].resource_id)
            ],
            "variant" => [activity_reference(activity_revisions[6].resource_id)]
          }),
          activity_reference(activity_revisions[7].resource_id)
        ]
      }

      groups = %{
        10 => %{strategy: "experiment_controlled"},
        20 => %{strategy: "experiment_controlled"}
      }

      selected =
        Alternatives.apply_experiment_decisions(content, groups, %{
          "placement-a" => %{status: :assigned, option_id: "variant"},
          "placement-b" => %{status: :assigned, option_id: "control"}
        })

      selected_ids = activity_ids(selected)

      refute activity_revisions[1].resource_id in selected_ids
      refute activity_revisions[6].resource_id in selected_ids

      resource_access =
        insert(:resource_access,
          user: user,
          section: section,
          resource: page_revision.resource,
          progress: 0.0
        )

      resource_attempt =
        insert(:resource_attempt,
          resource_access: resource_access,
          revision: page_revision,
          content: selected
        )

      revisions_by_resource_id =
        Map.new(activity_revisions, fn {_key, revision} -> {revision.resource_id, revision} end)

      attempts =
        Enum.map(selected_ids, fn resource_id ->
          revision = Map.fetch!(revisions_by_resource_id, resource_id)

          insert(:activity_attempt,
            resource_attempt: resource_attempt,
            revision: revision,
            resource: revision.resource,
            scoreable: true,
            lifecycle_state: :active
          )
        end)

      [first, second | remaining] = attempts

      Enum.each([first, second], fn attempt ->
        attempt
        |> Ecto.Changeset.change(lifecycle_state: :evaluated)
        |> Repo.update!()
      end)

      assert {:ok, :updated} = Metrics.update_page_progress(first)
      assert_in_delta Repo.reload(resource_access).progress, 0.4, 0.0001

      Enum.each(remaining, fn attempt ->
        attempt
        |> Ecto.Changeset.change(lifecycle_state: :evaluated)
        |> Repo.update!()
      end)

      assert {:ok, :updated} = Metrics.update_page_progress(List.last(attempts))
      assert Repo.reload(resource_access).progress == 1.0
    end
  end

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
            %{"name" => "two"}
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
            %{"name" => "two"}
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
            %{"name" => "two"}
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

    test "review mode renders the originally assigned native decision point condition without exposure" do
      %{context: context, element: element} =
        native_decision_point_setup(children: ["alt-b", "alt-a"])

      assert [
               %{alternative: %{"value" => "alt-b"}, hidden: true},
               %{alternative: %{"value" => "alt-a"}, hidden: false}
             ] = Alternatives.select(context, element)

      review_context = %{context | mode: :review}

      assert [
               %{alternative: %{"value" => "alt-b"}, hidden: true},
               %{alternative: %{"value" => "alt-a"}, hidden: false}
             ] = Alternatives.select(review_context, element)

      assert Repo.aggregate(Assignment, :count, :id) == 1
    end

    test "review mode prefers the branch containing attempted activities" do
      %{context: context, element: element} =
        native_decision_point_setup(children: [{"alt-b", 222}, {"alt-a", 111}])

      review_context = %{context | mode: :review, activity_resource_ids: [111]}

      assert [
               %{alternative: %{"value" => "alt-b"}, hidden: true},
               %{alternative: %{"value" => "alt-a"}, hidden: false}
             ] = Alternatives.select(review_context, element)

      assert Repo.aggregate(Assignment, :count, :id) == 0
    end

    test "review mode renders no branch when no prior native assignment can be proven" do
      %{context: context, element: element} = native_decision_point_setup(active?: false)

      assert [] = Alternatives.select(%{context | mode: :review}, element)

      assert Repo.aggregate(Assignment, :count, :id) == 0
    end

    test "preview modes return every branch without assignment or exposure state" do
      %{context: context, element: element} = native_decision_point_setup([])

      for mode <- [:author_preview, :instructor_preview] do
        assert [
                 %{alternative: %{"value" => "alt-a"}, hidden: false},
                 %{alternative: %{"value" => "alt-b"}, hidden: false}
               ] = Alternatives.select(%{context | mode: mode}, element)
      end

      assert Repo.aggregate(Assignment, :count, :id) == 0
    end
  end

  defp experiment_placement(id, alternatives_id, branches) do
    %{
      "type" => "alternatives",
      "id" => id,
      "alternatives_id" => alternatives_id,
      "children" =>
        Enum.map(branches, fn {value, children} ->
          %{
            "type" => "alternative",
            "id" => "#{id}-#{value}",
            "value" => value,
            "children" => children
          }
        end)
    }
  end

  defp activity_reference(id), do: %{"type" => "activity-reference", "activity_id" => id}

  defp activity_ids(content) do
    content
    |> Oli.Resources.PageContent.flat_filter(&(&1["type"] == "activity-reference"))
    |> Enum.map(& &1["activity_id"])
  end

  defp native_decision_point_setup(opts) do
    active? = Keyword.get(opts, :active?, true)
    options = Keyword.get(opts, :options, native_options())
    children = Keyword.get(opts, :children, ["alt-a", "alt-b"])

    institution = insert(:institution)
    project = insert(:project)
    publication = insert(:publication, project: project)

    section = insert(:section, institution: institution, base_project: project)

    user = insert(:user)
    enrollment = insert(:enrollment, section: section, user: user)

    revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_alternatives(),
        content: %{
          "strategy" => "upgrade_decision_point",
          "options" => options
        }
      )

    page_revision =
      insert(:revision, resource_type_id: Oli.Resources.ResourceType.id_for_page())

    insert(:project_resource, project_id: project.id, resource_id: revision.resource_id)
    insert(:project_resource, project_id: project.id, resource_id: page_revision.resource_id)

    insert(:section_project_publication,
      section: section,
      project: project,
      publication: publication
    )

    insert(:published_resource,
      publication: publication,
      resource: revision.resource,
      revision: revision
    )

    insert(:published_resource,
      publication: publication,
      resource: page_revision.resource,
      revision: page_revision
    )

    insert(:section_resource,
      section: section,
      project: project,
      resource_id: revision.resource_id
    )

    scope = %Scope{
      institution_id: institution.id,
      project_id: project.id,
      publication_id: publication.id,
      section_id: section.id,
      user_id: user.id,
      enrollment_id: enrollment.id
    }

    if active? do
      create_native_experiment(scope, revision, hd(options)["id"])
    end

    alternatives_id = revision.resource_id

    %{
      context: %AlternativesStrategyContext{
        enrollment_id: enrollment.id,
        user: user,
        institution_id: section.institution_id,
        project_id: project.id,
        publication_id: publication.id,
        section_id: section.id,
        section_slug: section.slug,
        mode: :delivery,
        project_slug: project.slug,
        page_resource_id: page_revision.resource_id,
        page_revision_id: page_revision.id,
        alternative_groups_by_id: %{
          alternatives_id => %{
            id: alternatives_id,
            revision_id: revision.id,
            title: "Decision point",
            options: options,
            strategy: "upgrade_decision_point"
          }
        }
      },
      element: %{
        "type" => "alternatives",
        "id" => "native-alternatives-placement",
        "alternatives_id" => alternatives_id,
        "children" =>
          Enum.map(children, fn value ->
            alternative_child(value)
          end)
      }
    }
  end

  defp alternative_child({value, activity_id}) do
    %{
      "type" => "alternative",
      "value" => value,
      "children" => [
        %{
          "type" => "activity-reference",
          "activity_id" => activity_id
        }
      ]
    }
  end

  defp alternative_child(value) do
    %{"type" => "alternative", "value" => value, "children" => []}
  end

  defp create_native_experiment(%Scope{} = scope, revision, condition_code) do
    definition =
      %ExperimentDefinition{}
      |> ExperimentDefinition.changeset(%{
        project_id: scope.project_id,
        slug: "runtime-#{System.unique_integer([:positive])}",
        name: "Runtime experiment",
        state: :active,
        algorithm: :weighted_random,
        alternatives_resource_id: revision.resource_id
      })
      |> Repo.insert!()

    %ExperimentSection{}
    |> ExperimentSection.changeset(%{experiment_id: definition.id, section_id: scope.section_id})
    |> Repo.insert!()

    for {code, option_id, weight, position} <- [
          {condition_code, condition_code, 1.0, 0},
          {"other", "alt-b", 0.0, 1}
        ] do
      %Condition{}
      |> Condition.changeset(%{
        experiment_id: definition.id,
        condition_code: code,
        label: code,
        option_id: option_id,
        weight: weight,
        active: true,
        position: position
      })
      |> Repo.insert!()
    end
  end

  defp native_options do
    [
      %{"id" => "alt-a", "name" => "condition-a"},
      %{"id" => "alt-b", "name" => "condition-b"}
    ]
  end
end
