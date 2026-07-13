defmodule Oli.Resources.AlternativesTest do
  use Oli.DataCase

  import Oli.Factory
  import Oli.Utils.Seeder.Utils

  alias Oli.Experiments
  alias Oli.Utils.Seeder
  alias Oli.Resources.Alternatives
  alias Oli.Resources.Alternatives.AlternativesStrategyContext
  alias Oli.Delivery.ExtrinsicState
  alias Oli.Experiments.{CreateExperimentRequest, LifecycleRequest, Scope}
  alias Oli.Experiments.Schemas.{Assignment, Condition, DecisionPoint, Exposure}

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

    test "renders assigned native decision point condition and records exposure" do
      %{context: context, element: element} = native_decision_point_setup()

      assert [
               %{alternative: %{"value" => "alt-a"}, hidden: false},
               %{alternative: %{"value" => "alt-b"}, hidden: true}
             ] = Alternatives.select(context, element)

      assignment = Repo.one!(Assignment)
      exposure = Repo.one!(Exposure)

      assert assignment.section_id == context.section_id
      assert exposure.assignment_id == assignment.id
      assert exposure.publication_id == context.publication_id
      assert exposure.idempotency_key =~ ":assignment:#{assignment.id}"
    end

    test "renders assigned native decision point condition for an institutionless open/free section" do
      %{context: context, element: element} =
        native_decision_point_setup(section_institution?: false)

      assert [
               %{alternative: %{"value" => "alt-a"}, hidden: false},
               %{alternative: %{"value" => "alt-b"}, hidden: true}
             ] = Alternatives.select(context, element)

      assignment = Repo.one!(Assignment)
      exposure = Repo.one!(Exposure)

      assert context.institution_id == nil
      assert assignment.section_id == context.section_id
      assert assignment.enrollment_id == context.enrollment_id
      assert exposure.assignment_id == assignment.id
    end

    test "reuses sticky native assignment on repeat delivery selection" do
      %{context: context, element: element} = native_decision_point_setup()

      Alternatives.select(context, element)
      Alternatives.select(context, element)

      assert Repo.aggregate(Assignment, :count, :id) == 1
      assert Repo.aggregate(Exposure, :count, :id) == 1
    end

    test "renders first option when no native experiment matches" do
      %{context: context, element: element} = native_decision_point_setup(active?: false)

      assert [
               %{alternative: %{"value" => "alt-a"}, hidden: false},
               %{alternative: %{"value" => "alt-b"}, hidden: true}
             ] = Alternatives.select(context, element)

      assert Repo.aggregate(Assignment, :count, :id) == 0
      assert Repo.aggregate(Exposure, :count, :id) == 0
    end

    @tag capture_log: true
    test "renders first option without exposure when assigned condition is not renderable" do
      %{context: context, element: element} =
        native_decision_point_setup(options: [%{"id" => "missing-alt", "name" => "condition-a"}])

      assert [
               %{alternative: %{"value" => "alt-a"}, hidden: false},
               %{alternative: %{"value" => "alt-b"}, hidden: true}
             ] = Alternatives.select(context, element)

      assert Repo.aggregate(Assignment, :count, :id) == 1
      assert Repo.aggregate(Exposure, :count, :id) == 0
    end
  end

  defp native_decision_point_setup(opts \\ []) do
    active? = Keyword.get(opts, :active?, true)
    options = Keyword.get(opts, :options, native_options())
    section_institution? = Keyword.get(opts, :section_institution?, true)

    institution = insert(:institution)
    project = insert(:project)
    publication = insert(:publication, project: project)

    section =
      if section_institution? do
        insert(:section, institution: institution, base_project: project, has_experiments: true)
      else
        insert(:section,
          institution: nil,
          base_project: project,
          has_experiments: true,
          open_and_free: true
        )
      end

    user = insert(:user)
    enrollment = insert(:enrollment, section: section, user: user)
    revision = insert(:revision)

    insert(:project_resource, project_id: project.id, resource_id: revision.resource_id)

    insert(:section_project_publication,
      section: section,
      project: project,
      publication: publication
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
        "alternatives_id" => alternatives_id,
        "children" => [
          %{"type" => "alternative", "value" => "alt-a", "children" => []},
          %{"type" => "alternative", "value" => "alt-b", "children" => []}
        ]
      }
    }
  end

  defp create_native_experiment(%Scope{} = scope, revision, condition_code) do
    {:ok, definition} =
      Experiments.create_experiment(%CreateExperimentRequest{
        scope: scope,
        slug: "runtime-#{System.unique_integer([:positive])}",
        name: "Runtime experiment",
        algorithm: :weighted_random
      })

    {:ok, active} =
      Experiments.activate_experiment(definition.id, %LifecycleRequest{scope: scope})

    decision_point =
      %DecisionPoint{}
      |> DecisionPoint.changeset(%{
        experiment_id: active.id,
        alternatives_resource_id: revision.resource_id,
        alternatives_revision_id: revision.id,
        decision_point_key: "alternatives:#{revision.resource_id}"
      })
      |> Repo.insert!()

    %Condition{}
    |> Condition.changeset(%{
      experiment_id: active.id,
      decision_point_id: decision_point.id,
      condition_code: condition_code,
      label: condition_code,
      weight: 1.0,
      position: 0
    })
    |> Repo.insert!()
  end

  defp native_options do
    [
      %{"id" => "alt-a", "name" => "condition-a"},
      %{"id" => "alt-b", "name" => "condition-b"}
    ]
  end
end
