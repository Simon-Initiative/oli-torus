defmodule OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTabTest do
  use ExUnit.Case, async: true

  alias OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTab

  describe "parse_scope/1" do
    test "parses the course scope" do
      assert IntelligentDashboardTab.parse_scope("course") == %{
               container_type: :course,
               container_id: nil
             }
    end

    test "parses a valid container scope" do
      assert IntelligentDashboardTab.parse_scope("container:123") == %{
               container_type: :container,
               container_id: 123
             }
    end

    test "falls back to the course scope for invalid values" do
      assert IntelligentDashboardTab.parse_scope(nil) == %{
               container_type: :course,
               container_id: nil
             }

      assert IntelligentDashboardTab.parse_scope("container:not-a-number") == %{
               container_type: :course,
               container_id: nil
             }

      assert IntelligentDashboardTab.parse_scope("container:-1") == %{
               container_type: :course,
               container_id: nil
             }

      assert IntelligentDashboardTab.parse_scope("wat") == %{
               container_type: :course,
               container_id: nil
             }
    end
  end

  describe "scope_selector/1" do
    test "builds the canonical selector string for a container scope" do
      assert IntelligentDashboardTab.scope_selector(%{
               container_type: :container,
               container_id: 456
             }) ==
               "container:456"
    end

    test "falls back to course for non-container scopes" do
      assert IntelligentDashboardTab.scope_selector(%{container_type: :course}) == "course"
      assert IntelligentDashboardTab.scope_selector(%{}) == "course"
    end
  end

  describe "path/2" do
    test "builds the canonical dashboard path and url-encodes the scope selector" do
      socket = %Phoenix.LiveView.Socket{assigns: %{section: %{slug: "elixir_30"}}}

      assert IntelligentDashboardTab.path(socket, "container:151334") ==
               "/sections/elixir_30/instructor_dashboard/insights/dashboard?dashboard_scope=container%3A151334"
    end
  end

  describe "parse_student_support_tile_state/1" do
    test "normalizes tile-local dashboard params" do
      assert IntelligentDashboardTab.parse_student_support_tile_state(%{
               "tile_support" => %{
                 "bucket" => "struggling",
                 "filter" => "inactive",
                 "page" => "2",
                 "q" => " ada "
               }
             }) == %{
               selected_bucket_id: "struggling",
               selected_activity_filter: :inactive,
               search_term: "ada",
               page: 2,
               visible_count: 40
             }
    end

    test "falls back safely when tile_support is not a map" do
      assert IntelligentDashboardTab.parse_student_support_tile_state(%{
               "tile_support" => "bad"
             }) == %{
               selected_bucket_id: nil,
               selected_activity_filter: :all,
               search_term: "",
               page: 1,
               visible_count: 20
             }
    end
  end

  describe "parse_assessments_tile_state/1" do
    test "normalizes tile-local dashboard params" do
      assert IntelligentDashboardTab.parse_assessments_tile_state(%{
               "tile_assessments" => %{"expanded" => "123"}
             }) == %{
               expanded_assessment_id: 123
             }
    end

    test "falls back safely when tile_assessments is not a map" do
      assert IntelligentDashboardTab.parse_assessments_tile_state(%{
               "tile_assessments" => "bad"
             }) == %{
               expanded_assessment_id: nil
             }
    end
  end

  describe "student_support_path/2" do
    test "preserves only dashboard and namespaced tile params" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          section: %{slug: "elixir_30"},
          dashboard_scope: "course",
          params: %{
            "view" => "insights",
            "active_tab" => "dashboard",
            "section_slug" => "elixir_30",
            "dashboard_scope" => "course",
            "tile_support" => %{"filter" => "inactive"}
          }
        }
      }

      assert IntelligentDashboardTab.student_support_path(socket, %{bucket: "on_track", page: 1}) ==
               "/sections/elixir_30/instructor_dashboard/insights/dashboard?dashboard_scope=course&tile_support[bucket]=on_track&tile_support[filter]=inactive"
    end
  end

  describe "assessments_path/2" do
    test "preserves only dashboard and namespaced tile params" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          section: %{slug: "elixir_30"},
          dashboard_scope: "course",
          params: %{
            "view" => "insights",
            "active_tab" => "dashboard",
            "section_slug" => "elixir_30",
            "dashboard_scope" => "course",
            "tile_support" => %{"filter" => "inactive"}
          }
        }
      }

      assert IntelligentDashboardTab.assessments_path(socket, %{expanded: 456}) ==
               "/sections/elixir_30/instructor_dashboard/insights/dashboard?dashboard_scope=course&tile_assessments[expanded]=456&tile_support[filter]=inactive"
    end
  end

  describe "parse_progress_tile_state/1" do
    test "normalizes progress tile params" do
      assert IntelligentDashboardTab.parse_progress_tile_state(%{
               "tile_progress" => %{"threshold" => "80", "mode" => "percent", "page" => "3"}
             }) == %{
               completion_threshold: 80,
               y_axis_mode: :percent,
               page: 3
             }
    end

    test "falls back safely when tile_progress is not a map" do
      assert IntelligentDashboardTab.parse_progress_tile_state(%{"tile_progress" => "bad"}) == %{
               completion_threshold: 100,
               y_axis_mode: :count,
               page: 1
             }
    end
  end

  describe "progress_tile_path/2" do
    test "preserves only dashboard and namespaced tile params" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          section: %{slug: "elixir_30"},
          dashboard_scope: "course",
          params: %{
            "view" => "insights",
            "active_tab" => "dashboard",
            "dashboard_scope" => "course",
            "tile_progress" => %{"mode" => "percent"}
          }
        }
      }

      assert IntelligentDashboardTab.progress_tile_path(socket, %{threshold: 80, page: 2}) ==
               "/sections/elixir_30/instructor_dashboard/insights/dashboard?dashboard_scope=course&tile_progress[mode]=percent&tile_progress[page]=2&tile_progress[threshold]=80"
    end

    test "preserves the current page when only threshold changes" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          section: %{slug: "elixir_30"},
          dashboard_scope: "course",
          params: %{
            "dashboard_scope" => "course",
            "tile_progress" => %{"mode" => "percent", "page" => "3", "threshold" => "60"}
          }
        }
      }

      assert IntelligentDashboardTab.progress_tile_path(socket, %{threshold: 80}) ==
               "/sections/elixir_30/instructor_dashboard/insights/dashboard?dashboard_scope=course&tile_progress[mode]=percent&tile_progress[page]=3&tile_progress[threshold]=80"
    end
  end

  describe "path/3" do
    test "resets tile_progress page when the dashboard scope changes" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          section: %{slug: "elixir_30"},
          dashboard_scope: "course",
          params: %{
            "dashboard_scope" => "course",
            "tile_progress" => %{"mode" => "percent", "threshold" => "80", "page" => "3"}
          }
        }
      }

      assert IntelligentDashboardTab.path(socket, "container:123") ==
               "/sections/elixir_30/instructor_dashboard/insights/dashboard?dashboard_scope=container%3A123&tile_progress[mode]=percent&tile_progress[threshold]=80"
    end
  end

  describe "validate_scope_selector/3" do
    test "accepts course scope" do
      assert IntelligentDashboardTab.validate_scope_selector(%{}, nil, "course") ==
               {:ok, "course"}
    end

    test "accepts a valid container from assigned containers" do
      section = %{slug: "example-section"}
      containers = {1, [%{id: 123}]}

      assert IntelligentDashboardTab.validate_scope_selector(section, containers, "container:123") ==
               {:ok, "container:123"}
    end

    test "rejects an invalid container from assigned containers" do
      section = %{slug: "example-section"}
      containers = {1, [%{id: 123}]}

      assert IntelligentDashboardTab.validate_scope_selector(section, containers, "container:999") ==
               :error
    end
  end

  describe "normalize_scope_selector/3" do
    test "falls back to course for an invalid container" do
      section = %{slug: "example-section"}
      containers = {1, [%{id: 123}]}

      assert IntelligentDashboardTab.normalize_scope_selector(
               section,
               containers,
               "container:999"
             ) ==
               "course"
    end

    test "returns the canonical selector for a valid container" do
      section = %{slug: "example-section"}
      containers = {1, [%{id: 123}]}

      assert IntelligentDashboardTab.normalize_scope_selector(
               section,
               containers,
               "container:123"
             ) ==
               "container:123"
    end
  end

  describe "handle_dashboard_request_timeout/2" do
    test "fails closed when no authenticated user id is available" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}, section: %{id: 123}, dashboard_scope: "course"}
      }

      assert {:noreply, updated_socket} =
               IntelligentDashboardTab.handle_dashboard_request_timeout(socket, 1)

      assert updated_socket.assigns.dashboard.runtime_status_text =~ "missing_user_id"
    end
  end

  describe "handle_dashboard_summary_recommendation_result/4" do
    test "applies the active async recommendation result to the dashboard summary" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          dashboard: %{summary_recommendation: nil, summary_status: "Loading recommendation"},
          dashboard_request_token: 101,
          dashboard_scope: "course",
          dashboard_summary_recommendation_request: %{
            request_token: 101,
            scope_selector: "course",
            status: :started
          }
        }
      }

      recommendation = %{
        id: 77,
        state: :ready,
        generation_mode: :implicit,
        message: "Review Module 3 assessment performance."
      }

      assert {:noreply, socket} =
               IntelligentDashboardTab.handle_dashboard_summary_recommendation_result(
                 socket,
                 101,
                 "course",
                 {:ok, recommendation}
               )

      assert socket.assigns.dashboard.summary_recommendation == recommendation
      assert socket.assigns.dashboard.summary_status == "Showing latest recommendation"
    end

    test "ignores stale async recommendation results from an older dashboard load token" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          dashboard: %{summary_recommendation: nil, summary_status: "Loading recommendation"},
          dashboard_request_token: 202,
          dashboard_scope: "container:22",
          dashboard_summary_recommendation_request: %{
            request_token: 202,
            scope_selector: "container:22",
            status: :started
          },
          dashboard_summary_recommendation_job_tokens: %{"container:22" => [202]}
        }
      }

      assert {:noreply, socket} =
               IntelligentDashboardTab.handle_dashboard_summary_recommendation_result(
                 socket,
                 201,
                 "container:22",
                 {:ok,
                  %{
                    id: 90,
                    state: :ready,
                    generation_mode: :implicit,
                    message: "This should be ignored."
                  }}
               )

      assert socket.assigns.dashboard.summary_recommendation == nil
      assert socket.assigns.dashboard.summary_status == "Loading recommendation"
    end

    test "applies a late ok result when scope matches after navigation cleared the request assign" do
      # Coordinator advances `dashboard_request_token` and clears
      # `dashboard_summary_recommendation_request` on scope change, but the async Task still
      # sends the original token. The UI must still accept the completion for the current scope
      # while that token remains registered as in-flight.
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          dashboard: %{
            summary_recommendation: %{state: :generating, message: nil},
            summary_status: "Regenerating recommendation"
          },
          dashboard_request_token: 999,
          dashboard_scope: "course",
          dashboard_summary_recommendation_request: nil,
          dashboard_summary_recommendation_job_tokens: %{"course" => [101]}
        }
      }

      recommendation = %{
        id: 55,
        state: :ready,
        generation_mode: :explicit_regen,
        message: "Updated after scope round-trip."
      }

      assert {:noreply, socket} =
               IntelligentDashboardTab.handle_dashboard_summary_recommendation_result(
                 socket,
                 101,
                 "course",
                 {:ok, recommendation}
               )

      assert socket.assigns.dashboard.summary_recommendation == recommendation
      assert socket.assigns.dashboard.summary_status == "Showing latest regeneration"
    end

    test "ignores a late ok result when the request assign is gone and the token is no longer registered" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          dashboard: %{
            summary_recommendation: %{
              id: 77,
              state: :ready,
              message: "Newest visible recommendation"
            },
            summary_status: "Showing latest recommendation"
          },
          dashboard_request_token: 999,
          dashboard_scope: "course",
          dashboard_summary_recommendation_request: nil,
          dashboard_summary_recommendation_job_tokens: %{}
        }
      }

      recommendation = %{
        id: 55,
        state: :ready,
        generation_mode: :explicit_regen,
        message: "Older late completion that should not overwrite."
      }

      assert {:noreply, socket} =
               IntelligentDashboardTab.handle_dashboard_summary_recommendation_result(
                 socket,
                 101,
                 "course",
                 {:ok, recommendation}
               )

      assert socket.assigns.dashboard.summary_recommendation == %{
               id: 77,
               state: :ready,
               message: "Newest visible recommendation"
             }

      assert socket.assigns.dashboard.summary_status == "Showing latest recommendation"
    end

    test "stashes ok result for another scope when completion arrives while viewing a different scope" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          dashboard: %{summary_recommendation: nil, summary_status: "Loading recommendation"},
          dashboard_request_token: 501,
          dashboard_scope: "container:9",
          dashboard_summary_recommendation_request: nil,
          dashboard_pending_summary_recommendations: %{},
          dashboard_summary_recommendation_job_tokens: %{"course" => [100]}
        }
      }

      recommendation = %{
        id: 42,
        state: :fallback,
        generation_mode: :explicit_regen,
        message: "Fallback after provider failure."
      }

      assert {:noreply, socket} =
               IntelligentDashboardTab.handle_dashboard_summary_recommendation_result(
                 socket,
                 100,
                 "course",
                 {:ok, recommendation}
               )

      assert socket.assigns.dashboard_pending_summary_recommendations["course"] ==
               {100, {:ok, recommendation}}

      assert socket.assigns.dashboard.summary_recommendation == nil
    end

    test "applies late regenerate completion when a newer request is already marked completed for the same scope" do
      # Regression: implicit summary can complete with token 3 while Regenerate (token 1) finishes
      # afterward; the older Task message must still apply if token 1 remains registered.
      recommendation = %{
        id: 86,
        state: :fallback,
        generation_mode: :explicit_regen,
        message: "There is no specific recommendation at this point in time."
      }

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          dashboard: %{
            summary_recommendation: %{state: :generating},
            summary_status: "Generating recommendation"
          },
          dashboard_request_token: 3,
          dashboard_scope: "container:5177",
          dashboard_summary_recommendation_request: %{
            status: :completed,
            request_token: 3,
            scope_selector: "container:5177"
          },
          dashboard_summary_recommendation_job_tokens: %{"container:5177" => [1, 3]}
        }
      }

      assert {:noreply, socket} =
               IntelligentDashboardTab.handle_dashboard_summary_recommendation_result(
                 socket,
                 1,
                 "container:5177",
                 {:ok, recommendation}
               )

      assert socket.assigns.dashboard.summary_recommendation == recommendation
      assert socket.assigns.dashboard.summary_status == "Showing fallback recommendation"
    end

    test "apply_pending_summary_recommendation_for_scope/2 merges a stashed result for the active scope" do
      recommendation = %{
        id: 42,
        state: :fallback,
        generation_mode: :explicit_regen,
        message: "Fallback after provider failure."
      }

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          dashboard: %{
            summary_recommendation: %{state: :generating},
            summary_status: "Generating recommendation"
          },
          dashboard_request_token: 777,
          dashboard_scope: "course",
          dashboard_summary_recommendation_request: nil,
          dashboard_pending_summary_recommendations: %{"course" => {100, {:ok, recommendation}}}
        }
      }

      updated =
        IntelligentDashboardTab.apply_pending_summary_recommendation_for_scope(socket, "course")

      assert updated.assigns.dashboard.summary_recommendation == recommendation
      assert updated.assigns.dashboard.summary_status == "Showing fallback recommendation"
      assert updated.assigns.dashboard_pending_summary_recommendations == %{}
    end
  end

  describe "handle_dashboard_summary_recommendation_trigger/5" do
    test "ignores a trigger when the active request has already changed" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          dashboard_request_token: 303,
          dashboard_scope: "container:22",
          dashboard_summary_recommendation_request: %{
            request_token: 303,
            scope_selector: "container:22",
            status: :scheduled
          },
          dashboard_summary_recommendation_timer_ref: make_ref(),
          dashboard_store: self(),
          dashboard_revisit_cache: Oli.Dashboard.RevisitCache
        }
      }

      oracle_context = %Oli.Dashboard.OracleContext{
        dashboard_context_type: :section,
        dashboard_context_id: 1,
        user_id: 1,
        scope: %Oli.Dashboard.Scope{container_type: :container, container_id: 22}
      }

      assert {:noreply, socket} =
               IntelligentDashboardTab.handle_dashboard_summary_recommendation_trigger(
                 socket,
                 302,
                 "course",
                 oracle_context,
                 %{oracles: %{}}
               )

      assert socket.assigns.dashboard_summary_recommendation_request.status == :scheduled
    end
  end

  describe "remote recommendation PubSub handlers" do
    test "handle_remote_recommendation_generating merges summary when scope and section match" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          section: %{id: 42},
          dashboard_scope: "course",
          active_tab: :dashboard,
          view: :insights,
          dashboard: %{summary_recommendation: nil, summary_status: "Loading recommendation"}
        }
      }

      recommendation = %{state: :generating, message: nil, id: 99}

      assert {:noreply, updated} =
               IntelligentDashboardTab.handle_remote_recommendation_generating(
                 socket,
                 42,
                 "course",
                 recommendation
               )

      assert updated.assigns.dashboard.summary_recommendation == recommendation
      assert updated.assigns.dashboard.summary_status == "Generating recommendation"
    end

    test "handle_remote_recommendation_generating ignores when section differs" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          section: %{id: 1},
          dashboard_scope: "course",
          active_tab: :dashboard,
          view: :insights,
          dashboard: %{}
        }
      }

      assert {:noreply, ^socket} =
               IntelligentDashboardTab.handle_remote_recommendation_generating(
                 socket,
                 2,
                 "course",
                 %{state: :generating, id: 1}
               )
    end

    test "handle_remote_recommendation_updated merges payload without DB when id is absent" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          section: %{id: 7},
          dashboard_scope: "container:3",
          active_tab: :dashboard,
          view: :insights,
          current_user: %{id: 100},
          dashboard: %{summary_recommendation: nil}
        }
      }

      recommendation = %{
        state: :ready,
        message: "Scoped text",
        feedback_summary: %{sentiment_submitted?: false}
      }

      assert {:noreply, updated} =
               IntelligentDashboardTab.handle_remote_recommendation_updated(
                 socket,
                 7,
                 "container:3",
                 recommendation
               )

      assert updated.assigns.dashboard.summary_recommendation == recommendation
      assert updated.assigns.dashboard.summary_status == "Showing latest recommendation"
    end
  end
end
