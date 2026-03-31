defmodule OliWeb.Components.Delivery.LearningObjectives.ComponentTest do
  use OliWeb.ConnCase, async: true

  import LiveComponentTests
  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.LearningObjectives

  describe "LearningObjectives component" do
    test "renders objectives and sub-objectives in the instructor table and counts respect filters",
         %{
           conn: conn
         } do
      objectives = [
        %{
          resource_id: 1,
          title: "LO.02",
          objective: "LO.02",
          subobjective: nil,
          student_proficiency_obj: "Low",
          student_proficiency_subobj: nil,
          student_proficiency_obj_dist: %{},
          container_ids: [10],
          related_activities_count: 0
        },
        %{
          resource_id: 2,
          title: "Sub.LO.2a",
          objective: "LO.02",
          objective_resource_id: 1,
          subobjective: "Sub.LO.2a",
          student_proficiency_obj: "Low",
          student_proficiency_subobj: "Low",
          student_proficiency_obj_dist: %{},
          student_proficiency_subobj_dist: %{},
          container_ids: [10],
          related_activities_count: 0
        },
        %{
          resource_id: 3,
          title: "Sub.LO.2b",
          objective: "LO.02",
          objective_resource_id: 1,
          subobjective: "Sub.LO.2b",
          student_proficiency_obj: "Low",
          student_proficiency_subobj: "Medium",
          student_proficiency_obj_dist: %{},
          student_proficiency_subobj_dist: %{},
          container_ids: [10],
          related_activities_count: 0
        },
        %{
          resource_id: 4,
          title: "Sub.LO.2c",
          objective: "LO.02",
          objective_resource_id: 1,
          subobjective: "Sub.LO.2c",
          student_proficiency_obj: "Low",
          student_proficiency_subobj: "High",
          student_proficiency_obj_dist: %{},
          student_proficiency_subobj_dist: %{},
          container_ids: [10],
          related_activities_count: 0
        },
        %{
          resource_id: 5,
          title: "LO.99",
          objective: "LO.99",
          subobjective: nil,
          student_proficiency_obj: "Low",
          student_proficiency_subobj: nil,
          student_proficiency_obj_dist: %{},
          container_ids: [99],
          related_activities_count: 0
        },
        %{
          resource_id: 6,
          title: "Sub.LO.99a",
          objective: "LO.99",
          objective_resource_id: 5,
          subobjective: "Sub.LO.99a",
          student_proficiency_obj: "Low",
          student_proficiency_subobj: "Low",
          student_proficiency_obj_dist: %{},
          student_proficiency_subobj_dist: %{},
          container_ids: [99],
          related_activities_count: 0
        }
      ]

      params = %{
        "selected_card_value" => "low_proficiency_outcomes",
        "filter_by" => "10",
        "sort_by" => "objective_instructor_dashboard"
      }

      {:ok, view, _html} =
        live_component_isolated(conn, LearningObjectives, %{
          id: "learning-objectives-test",
          objectives_tab: %{objectives: objectives, navigator_items: []},
          params: params,
          section_slug: "test-section",
          section_id: 1,
          section_title: "Test Section",
          current_user: %{email: "instructor@example.edu"},
          patch_url_type: :instructor_dashboard,
          student_id: nil,
          view: :insights,
          v25_migration: :done
        })

      html = render(view)

      assert html =~ "LO.02"
      assert html =~ "Sub.LO.2a"
      assert html =~ "Sub.LO.2b"
      assert html =~ "Sub.LO.2c"

      assert card_text(html, "low_proficiency_outcomes") =~ "1"
      assert card_text(html, "low_proficiency_skills") =~ "1"
    end

    test "keeps the targeted parent objective visible for tile deep-link context", %{conn: conn} do
      objectives = [
        %{
          resource_id: 1,
          title: "Objective 1",
          objective: "Objective 1",
          subobjective: nil,
          student_proficiency_obj: "Medium",
          student_proficiency_subobj: nil,
          student_proficiency_obj_dist: %{},
          container_ids: [10],
          related_activities_count: 0
        },
        %{
          resource_id: 2,
          title: "Sub-Objective 1.3",
          objective: "Objective 1",
          objective_resource_id: 1,
          subobjective: "Sub-Objective 1.3",
          student_proficiency_obj: "Medium",
          student_proficiency_subobj: "Low",
          student_proficiency_obj_dist: %{},
          student_proficiency_subobj_dist: %{},
          container_ids: [10],
          related_activities_count: 0
        }
      ]

      {:ok, view, _html} =
        live_component_isolated(conn, LearningObjectives, %{
          id: "learning-objectives-deep-link-parent",
          objectives_tab: %{objectives: objectives, navigator_items: []},
          params: %{
            "filter_by" => "10",
            "objective_id" => "1",
            "navigation_source" => "challenging_objectives_tile"
          },
          section_slug: "test-section",
          section_id: 1,
          section_title: "Test Section",
          current_user: %{email: "instructor@example.edu"},
          patch_url_type: :instructor_dashboard,
          student_id: nil,
          view: :insights,
          v25_migration: :done
        })

      assert render(view) =~ "Objective 1"
    end

    test "update seeds expanded rows for tile navigation handoff" do
      objectives = objectives_with_subobjective()

      socket =
        %Phoenix.LiveView.Socket{
          assigns: %{
            __changed__: %{},
            myself: %Phoenix.LiveComponent.CID{cid: 1}
          }
        }

      assigns = %{
        id: "learning-objectives-update-test",
        objectives_tab: %{objectives: objectives, navigator_items: []},
        params: %{
          "filter_by" => "10",
          "objective_id" => "1",
          "navigation_source" => "challenging_objectives_tile"
        },
        section_slug: "test-section",
        section_id: 1,
        section_title: "Test Section",
        current_user: %{email: "instructor@example.edu"},
        patch_url_type: :instructor_dashboard,
        student_id: nil,
        view: :insights,
        v25_migration: :done
      }

      assert {:ok, updated_socket} = LearningObjectives.update(assigns, socket)
      assert updated_socket.assigns.expanded_objectives == MapSet.new(["row_1"])

      assert updated_socket.assigns.table_model.data.expanded_rows ==
               MapSet.new(["row_1"])
    end

    test "initial_expanded_rows expands the targeted parent objective" do
      scoped_objectives = objectives_with_subobjective()

      assert LearningObjectives.initial_expanded_rows(scoped_objectives, %{
               objective_id: 1,
               subobjective_id: nil
             }) == MapSet.new(["row_1"])
    end

    test "initial_expanded_rows expands the subobjective row for a subobjective deep link" do
      scoped_objectives = objectives_with_subobjective()

      assert LearningObjectives.initial_expanded_rows(scoped_objectives, %{
               objective_id: 1,
               subobjective_id: 2
             }) == MapSet.new(["row_2"])
    end

    test "update seeds expanded rows for subobjective tile navigation handoff" do
      objectives = objectives_with_subobjective()

      socket =
        %Phoenix.LiveView.Socket{
          assigns: %{
            __changed__: %{},
            myself: %Phoenix.LiveComponent.CID{cid: 1}
          }
        }

      assigns = %{
        id: "learning-objectives-update-subobjective-test",
        objectives_tab: %{objectives: objectives, navigator_items: []},
        params: %{
          "filter_by" => "10",
          "objective_id" => "1",
          "subobjective_id" => "2",
          "navigation_source" => "challenging_objectives_tile"
        },
        section_slug: "test-section",
        section_id: 1,
        section_title: "Test Section",
        current_user: %{email: "instructor@example.edu"},
        patch_url_type: :instructor_dashboard,
        student_id: nil,
        view: :insights,
        v25_migration: :done
      }

      assert {:ok, updated_socket} = LearningObjectives.update(assigns, socket)
      assert updated_socket.assigns.expanded_objectives == MapSet.new(["row_2"])

      assert updated_socket.assigns.table_model.data.expanded_rows ==
               MapSet.new(["row_2"])
    end

    test "tile navigation adjusts pagination so the targeted objective is present" do
      objectives = paginated_objectives_fixture()

      socket =
        %Phoenix.LiveView.Socket{
          assigns: %{
            __changed__: %{},
            myself: %Phoenix.LiveComponent.CID{cid: 1}
          }
        }

      assigns = %{
        id: "learning-objectives-update-paginated-objective-test",
        objectives_tab: %{objectives: objectives, navigator_items: []},
        params: %{
          "limit" => "1",
          "offset" => "0",
          "objective_id" => "3",
          "navigation_source" => "challenging_objectives_tile"
        },
        section_slug: "test-section",
        section_id: 1,
        section_title: "Test Section",
        current_user: %{email: "instructor@example.edu"},
        patch_url_type: :instructor_dashboard,
        student_id: nil,
        view: :insights,
        v25_migration: :done
      }

      assert {:ok, updated_socket} = LearningObjectives.update(assigns, socket)
      assert updated_socket.assigns.params.offset == 2
      assert Enum.map(updated_socket.assigns.table_model.rows, & &1.resource_id) == [3]
      assert updated_socket.assigns.expanded_objectives == MapSet.new(["row_3"])
    end

    test "tile navigation adjusts pagination so the targeted subobjective is present" do
      objectives = paginated_objectives_fixture()

      socket =
        %Phoenix.LiveView.Socket{
          assigns: %{
            __changed__: %{},
            myself: %Phoenix.LiveComponent.CID{cid: 1}
          }
        }

      assigns = %{
        id: "learning-objectives-update-paginated-subobjective-test",
        objectives_tab: %{objectives: objectives, navigator_items: []},
        params: %{
          "limit" => "1",
          "offset" => "0",
          "objective_id" => "1",
          "subobjective_id" => "4",
          "navigation_source" => "challenging_objectives_tile"
        },
        section_slug: "test-section",
        section_id: 1,
        section_title: "Test Section",
        current_user: %{email: "instructor@example.edu"},
        patch_url_type: :instructor_dashboard,
        student_id: nil,
        view: :insights,
        v25_migration: :done
      }

      assert {:ok, updated_socket} = LearningObjectives.update(assigns, socket)
      assert updated_socket.assigns.params.offset == 3
      assert Enum.map(updated_socket.assigns.table_model.rows, & &1.resource_id) == [4]
      assert updated_socket.assigns.expanded_objectives == MapSet.new(["row_4"])
    end

    test "initial_expanded_rows ignores unresolved deep-link ids" do
      scoped_objectives = objectives_with_subobjective()

      assert LearningObjectives.initial_expanded_rows(scoped_objectives, %{
               objective_id: 99,
               subobjective_id: 999
             }) == MapSet.new()
    end

    test "starting_expanded_objectives resets prior expansion state for tile navigation" do
      socket = %Phoenix.LiveView.Socket{assigns: %{expanded_objectives: MapSet.new(["row_1"])}}

      assert LearningObjectives.starting_expanded_objectives(socket, %{
               navigation_source: "challenging_objectives_tile"
             }) == MapSet.new()
    end

    test "starting_expanded_objectives preserves prior expansion state outside tile navigation" do
      existing = MapSet.new(["row_1"])
      socket = %Phoenix.LiveView.Socket{assigns: %{expanded_objectives: existing}}

      assert LearningObjectives.starting_expanded_objectives(socket, %{}) == existing
    end

    test "emits navigation telemetry when arriving from challenging objectives tile", %{
      conn: conn
    } do
      handler_id = "challenging-objectives-nav-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:oli, :instructor_dashboard, :challenging_objectives, :navigation],
        fn event, measurements, metadata, pid ->
          send(pid, {:telemetry_event, event, measurements, metadata})
        end,
        self()
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      {:ok, _view, _html} =
        live_component_isolated(conn, LearningObjectives, %{
          id: "learning-objectives-telemetry-test",
          objectives_tab: %{objectives: objectives_with_subobjective(), navigator_items: []},
          params: %{
            "navigation_source" => "challenging_objectives_tile",
            "objective_id" => "1",
            "selected_card_value" => "low_proficiency_outcomes",
            "filter_by" => "10"
          },
          section_slug: "test-section",
          section_id: 1,
          section_title: "Test Section",
          current_user: %{email: "instructor@example.edu"},
          patch_url_type: :instructor_dashboard,
          student_id: nil,
          view: :insights,
          v25_migration: :done
        })

      assert_receive {:telemetry_event,
                      [:oli, :instructor_dashboard, :challenging_objectives, :navigation],
                      %{count: 1},
                      %{
                        source: "challenging_objectives_tile",
                        target: "objective",
                        filter_by: 10
                      }}
    end
  end

  defp card_text(html, value) do
    {:ok, document} = Floki.parse_document(html)
    [card] = Floki.find(document, ~s(div[phx-value-selected="#{value}"]))
    Floki.text(card)
  end

  defp objectives_with_subobjective do
    [
      %{
        resource_id: 1,
        title: "LO.01",
        objective: "LO.01",
        subobjective: nil,
        student_proficiency_obj: "Low",
        student_proficiency_subobj: nil,
        student_proficiency_obj_dist: %{},
        container_ids: [10],
        related_activities_count: 0
      },
      %{
        resource_id: 2,
        title: "Sub.LO.01a",
        objective: "LO.01",
        objective_resource_id: 1,
        subobjective: "Sub.LO.01a",
        student_proficiency_obj: "Low",
        student_proficiency_subobj: "Low",
        student_proficiency_obj_dist: %{},
        student_proficiency_subobj_dist: %{},
        container_ids: [10],
        related_activities_count: 0
      }
    ]
  end

  defp paginated_objectives_fixture do
    [
      %{
        resource_id: 1,
        title: "Objective 1",
        objective: "Objective 1",
        subobjective: nil,
        student_proficiency_obj: "Low",
        student_proficiency_subobj: nil,
        student_proficiency_obj_dist: %{},
        container_ids: [10],
        related_activities_count: 0
      },
      %{
        resource_id: 2,
        title: "Objective 2",
        objective: "Objective 2",
        subobjective: nil,
        student_proficiency_obj: "Low",
        student_proficiency_subobj: nil,
        student_proficiency_obj_dist: %{},
        container_ids: [10],
        related_activities_count: 0
      },
      %{
        resource_id: 3,
        title: "Objective 3",
        objective: "Objective 3",
        subobjective: nil,
        student_proficiency_obj: "Low",
        student_proficiency_subobj: nil,
        student_proficiency_obj_dist: %{},
        container_ids: [10],
        related_activities_count: 0
      },
      %{
        resource_id: 4,
        title: "Sub-Objective 3.1",
        objective: "Objective 3",
        objective_resource_id: 3,
        subobjective: "Sub-Objective 3.1",
        student_proficiency_obj: "Low",
        student_proficiency_subobj: "Low",
        student_proficiency_obj_dist: %{},
        student_proficiency_subobj_dist: %{},
        container_ids: [10],
        related_activities_count: 0
      }
    ]
  end
end
