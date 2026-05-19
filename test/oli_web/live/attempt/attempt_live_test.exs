defmodule OliWeb.Attempt.AttemptLiveTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Test.{AttemptBuilder, SectionBuilder}

  describe "access control" do
    test "redirects unauthenticated users", %{conn: conn} do
      %{section: section, resource_attempt: resource_attempt} = build_attempt_graph()

      assert {:error, {:redirect, _}} =
               live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")
    end

    test "redirects a non-admin author", %{conn: conn} do
      %{section: section, resource_attempt: resource_attempt} = build_attempt_graph()

      conn = log_in_author(conn, insert(:author))

      assert {:error, {:redirect, _}} =
               live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")
    end

    test "redirects a learner-only user", %{conn: conn} do
      %{section: section, resource_attempt: resource_attempt} = build_attempt_graph()

      conn = log_in_user(conn, insert(:user))

      assert {:error, {:redirect, _}} =
               live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")
    end
  end

  describe "sorting activity attempts" do
    setup [:admin_conn, :setup_sorted_attempts]

    test "ignores invalid sort keys" do
      {:ok, table_model} = OliWeb.Attempt.TableModel.new([])
      socket = %Phoenix.LiveView.Socket{assigns: %{table_model: table_model}}

      assert {:noreply, updated_socket} =
               OliWeb.Attempt.AttemptLive.handle_event(
                 "sort",
                 %{"sort_by" => "not_a_real_column"},
                 socket
               )

      assert updated_socket.assigns.table_model.sort_by_spec.name ==
               table_model.sort_by_spec.name

      assert updated_socket.assigns.table_model.sort_order == table_model.sort_order
    end

    test "sorts by date evaluated", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      view
      |> element("th[phx-click='sort'][phx-value-sort_by='date_evaluated']")
      |> render_click(%{sort_by: "date_evaluated"})

      # Column indices: [1=chevron, 2=Updated, 3=Attempt Guid, 4=Resource Id,
      # 5=Attempt Number, 6=Title, ...]. The "Title" column is nth-child(6).
      # Rows alternate data/details because expandable_rows is enabled, so the
      # last data row is nth-last-child(2) (the trailing details row is last).
      assert view
             |> element("tbody tr:first-child td:nth-child(6)")
             |> render() =~ "Early Screen"

      assert view
             |> element("tbody tr:nth-last-child(2) td:nth-child(6)")
             |> render() =~ "Late Screen"

      view
      |> element("th[phx-click='sort'][phx-value-sort_by='date_evaluated']")
      |> render_click(%{sort_by: "date_evaluated"})

      assert view
             |> element("tbody tr:first-child td:nth-child(6)")
             |> render() =~ "Late Screen"

      assert view
             |> element("tbody tr:nth-last-child(2) td:nth-child(6)")
             |> render() =~ "Early Screen"
    end
  end

  describe "detail pane" do
    setup [:admin_conn, :setup_attempts_with_responses]

    test "does not render the Student Responses section before a row is selected", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      {:ok, _view, html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      refute html =~ "Student Responses"
    end

    test "selecting a row renders the student's response fields and typed values", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt,
      mcq_activity: mcq_activity
    } do
      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{mcq_activity.id}"})

      # Heading present
      assert html =~ "Student Responses"
      assert html =~ "Response"

      # Response keys rendered
      assert html =~ "selectedChoice"
      assert html =~ "selectedChoiceText"
      assert html =~ "enabled"
      assert html =~ "randomize"

      # Typed value indicators — boolean true/false rendered as check/cross
      assert html =~ "✓"
      assert html =~ "✗"

      # Response value text rendered
      assert html =~ "Objects with longer half lives"
    end

    test "does not render raw authoring-model JSON", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt,
      mcq_activity: mcq_activity
    } do
      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{mcq_activity.id}"})

      refute html =~ "activitiesRequiredForEvaluation"
      refute html =~ ~s("authoring")
      refute html =~ "<pre"
    end

    test "two different attempts render distinct response content", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt,
      mcq_activity: mcq_activity,
      text_activity: text_activity
    } do
      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      # Expand MCQ only — its content is visible, text activity's is not (still collapsed).
      mcq_html = render_click(view, "toggle_row", %{"id" => "row_#{mcq_activity.id}"})
      assert mcq_html =~ "selectedChoice"
      refute mcq_html =~ "Hello World"

      # Collapse MCQ, then expand text — its content is visible, MCQ's is not.
      _ = render_click(view, "toggle_row", %{"id" => "row_#{mcq_activity.id}"})
      text_html = render_click(view, "toggle_row", %{"id" => "row_#{text_activity.id}"})
      assert text_html =~ "Hello World"
      refute text_html =~ "selectedChoice"
    end

    test "a part attempt with no response shows the fallback message", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt,
      empty_activity: empty_activity
    } do
      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{empty_activity.id}"})

      assert html =~ "No response data recorded"
    end

    test "renders part cards sorted alphabetically by part_id regardless of insertion order",
         %{conn: conn, section: section, resource_attempt: resource_attempt} do
      # Insert parts in non-alphabetical order so we can verify the render sorts them
      tree =
        AttemptBuilder.add_activities(%{}, resource_attempt, [
          {:activity_attempt, "Sort Test Screen",
           [
             {:part_attempt, "zebra", response: %{"x" => 1}},
             {:part_attempt, "alpha", response: %{"y" => 2}},
             {:part_attempt, "middle", response: %{"z" => 3}}
           ]}
        ])

      activity = tree["Sort Test Screen"].activity

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{activity.id}"})

      {alpha_pos, _} = :binary.match(html, "alpha")
      {middle_pos, _} = :binary.match(html, "middle")
      {zebra_pos, _} = :binary.match(html, "zebra")

      assert alpha_pos < middle_pos,
             "Expected 'alpha' to appear before 'middle' in the rendered output"

      assert middle_pos < zebra_pos,
             "Expected 'middle' to appear before 'zebra' in the rendered output"
    end

    test "unwraps a CapiVariable-shaped response entry into a single row", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      tree =
        AttemptBuilder.add_activities(%{}, resource_attempt, [
          {:activity_attempt, "CAPI Unwrap Screen",
           [
             {:part_attempt, "popTemp",
              response: %{
                "isOpen" => %{
                  "key" => "isOpen",
                  "path" => "act-id|stage.popTemp.isOpen",
                  "type" => 4,
                  "value" => false
                }
              }}
           ]}
        ])

      activity = tree["CAPI Unwrap Screen"].activity

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{activity.id}"})

      # The variable name and its boolean-false indicator must both be present
      assert html =~ "isOpen"
      assert html =~ "✗"

      # The CapiVariable metadata (key/path/type) must NOT be rendered as visible labels —
      # the unwrap replaces the 4-level tree with one row.
      refute html =~ "act-id|stage.popTemp.isOpen"

      refute html =~
               ~s(<summary style="cursor: pointer;">\n                <span style="font-weight: 600;">key</span>)
    end

    test "recurses into a plain nested map that is NOT a CapiVariable", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      tree =
        AttemptBuilder.add_activities(%{}, resource_attempt, [
          {:activity_attempt, "Plain Nested Screen",
           [
             {:part_attempt, "metadata_part",
              response: %{
                "metadata" => %{
                  "answered_at" => "2026-04-20",
                  "ip" => "192.168.0.1"
                }
              }}
           ]}
        ])

      activity = tree["Plain Nested Screen"].activity

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{activity.id}"})

      # Both inner keys render with their values — recursion preserved.
      assert html =~ "answered_at"
      assert html =~ "2026-04-20"
      assert html =~ "ip"
      assert html =~ "192.168.0.1"
      # Parent key also present
      assert html =~ "metadata"
    end

    test "handles a mixed response (one CapiVariable + one plain nested map)", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      tree =
        AttemptBuilder.add_activities(%{}, resource_attempt, [
          {:activity_attempt, "Mixed Response Screen",
           [
             {:part_attempt, "mixed_part",
              response: %{
                "selectedChoice" => %{
                  "key" => "selectedChoice",
                  "path" => "act-id|stage.mixed_part.selectedChoice",
                  "type" => 1,
                  "value" => 3
                },
                "metadata" => %{"answered_at" => "2026-04-20"}
              }}
           ]}
        ])

      activity = tree["Mixed Response Screen"].activity

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{activity.id}"})

      # CapiVariable side: key + unwrapped numeric value, no path metadata
      assert html =~ "selectedChoice"
      assert html =~ ">3<"
      refute html =~ "act-id|stage.mixed_part.selectedChoice"

      # Nested-map side: parent + inner key + value all visible
      assert html =~ "metadata"
      assert html =~ "answered_at"
      assert html =~ "2026-04-20"
    end

    test "tolerates CapiVariable entries with extra fields (allowedValues, etc.)", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      tree =
        AttemptBuilder.add_activities(%{}, resource_attempt, [
          {:activity_attempt, "CAPI With Extras Screen",
           [
             {:part_attempt, "status_part",
              response: %{
                "status" => %{
                  "key" => "status",
                  "path" => "act-id|stage.status_part.status",
                  "type" => 5,
                  "value" => "active",
                  "allowedValues" => ["active", "inactive"]
                }
              }}
           ]}
        ])

      activity = tree["CAPI With Extras Screen"].activity

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{activity.id}"})

      # With type-driven rendering (item 3), an ENUM CapiVariable shows its value
      # plus an allowedValues caption. `inactive` now appears in that caption —
      # what we still refute is that `allowedValues` renders as a *labeled nested
      # row* (which would indicate the detector descended into extras).
      assert html =~ "status"
      assert html =~ "active"
      assert html =~ "inactive"
      refute html =~ ">allowedValues<"
    end

    # --- Item 3: type-driven value rendering ------------------------------------

    test "renders a NUMBER-typed value via the declared type", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      activity =
        setup_part_with_capi_response(
          resource_attempt,
          "num_part",
          %{"count" => capi_var("count", 1, 42)}
        )

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{activity.id}"})

      assert html =~ "count"
      assert html =~ ">42<"
    end

    test "renders a STRING-typed value as raw text (no surrounding quotes)", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      activity =
        setup_part_with_capi_response(
          resource_attempt,
          "str_part",
          %{"name" => capi_var("name", 2, "hello")}
        )

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{activity.id}"})

      assert html =~ "name"
      assert html =~ "hello"
      # Raw value, not `inspect`-quoted — the HEEx-escaped "&quot;hello&quot;" form
      # should NOT appear.
      refute html =~ "&quot;hello&quot;"
    end

    test "renders an ARRAY-typed value as JSON", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      activity =
        setup_part_with_capi_response(
          resource_attempt,
          "arr_part",
          %{"ids" => capi_var("ids", 3, [1, 2, 3])}
        )

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{activity.id}"})

      assert html =~ "ids"
      assert html =~ "[1,2,3]"
    end

    test "renders a BOOLEAN-typed true value as check mark", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      activity =
        setup_part_with_capi_response(
          resource_attempt,
          "bool_true_part",
          %{"enabled" => capi_var("enabled", 4, true)}
        )

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{activity.id}"})

      assert html =~ "enabled"
      assert html =~ "✓"
    end

    test "renders a BOOLEAN-typed false value as cross mark", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      activity =
        setup_part_with_capi_response(
          resource_attempt,
          "bool_false_part",
          %{"enabled" => capi_var("enabled", 4, false)}
        )

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{activity.id}"})

      assert html =~ "enabled"
      assert html =~ "✗"
    end

    test "renders an ENUM-typed value with its allowedValues caption", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      activity =
        setup_part_with_capi_response(
          resource_attempt,
          "enum_part",
          %{
            "mode" => capi_var("mode", 5, "edit", %{"allowedValues" => ["view", "edit", "admin"]})
          }
        )

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{activity.id}"})

      assert html =~ "mode"
      # Rendered via OliWeb.Delivery.Content.SelectDropdown: the selected value
      # appears as the dropdown label, and every allowedValue is an <option>
      # button in the list, so all three strings must be present in the HTML.
      assert html =~ "edit"
      assert html =~ "view"
      assert html =~ "admin"
    end

    test "renders a MATH_EXPR-typed value as text", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      activity =
        setup_part_with_capi_response(
          resource_attempt,
          "math_part",
          %{"expr" => capi_var("expr", 6, "2 + 2")}
        )

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{activity.id}"})

      assert html =~ "expr"
      assert html =~ "2 + 2"
    end

    test "renders an ARRAY_POINT-typed value as JSON", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      activity =
        setup_part_with_capi_response(
          resource_attempt,
          "pt_part",
          %{"pts" => capi_var("pts", 7, [[0, 0], [1, 1]])}
        )

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{activity.id}"})

      assert html =~ "pts"
      assert html =~ "[[0,0],[1,1]]"
    end

    test "type BOOLEAN takes priority over a string-shaped value", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      activity =
        setup_part_with_capi_response(
          resource_attempt,
          "divergence_bool_part",
          %{"enabled" => capi_var("enabled", 4, "false")}
        )

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{activity.id}"})

      # Declared type wins — must render as the boolean cross, not as a quoted string.
      assert html =~ "enabled"
      assert html =~ "✗"
    end

    test "type NUMBER takes priority over a string-shaped value", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      activity =
        setup_part_with_capi_response(
          resource_attempt,
          "divergence_num_part",
          %{"count" => capi_var("count", 1, "42")}
        )

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{activity.id}"})

      # Must render inside a monospace value span. Both string and number rendering
      # would include "42" in the output; what proves type-driven dispatch ran is
      # the absence of the NO-LONGER-USED title="42" attribute that the pre-item-3
      # string branch used to emit. With the current render, no type renders title.
      assert html =~ ">42<"
    end

    test "type ARRAY takes priority over a string-shaped value", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      activity =
        setup_part_with_capi_response(
          resource_attempt,
          "divergence_arr_part",
          %{"ids" => capi_var("ids", 3, "[1,2,3]")}
        )

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{activity.id}"})

      # Must render as parsed array content (the JSON-encoded form).
      assert html =~ "[1,2,3]"
    end

    test "unknown type falls back to Elixir-guard rendering", %{
      conn: conn,
      section: section,
      resource_attempt: resource_attempt
    } do
      activity =
        setup_part_with_capi_response(
          resource_attempt,
          "unknown_type_part",
          %{"flag" => capi_var("flag", 99, true)}
        )

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/debugger/#{resource_attempt.attempt_guid}")

      html = render_click(view, "toggle_row", %{"id" => "row_#{activity.id}"})

      # With UNKNOWN(99) we fall back to the guard-based renderer; value is a
      # boolean true at runtime, so the check mark should still appear.
      assert html =~ "flag"
      assert html =~ "✓"
    end
  end

  # --- helpers -----------------------------------------------------------------

  # Builds a CapiVariable-shape map matching the persisted Janus serialization:
  # 4 required keys ({key, path, type, value}) + optional extras (e.g. allowedValues).
  defp capi_var(key, type, value, extras \\ %{}) do
    Map.merge(
      %{
        "key" => key,
        "path" => "act-id|stage.test.#{key}",
        "type" => type,
        "value" => value
      },
      extras
    )
  end

  # Inserts a fresh revision/activity_attempt/part_attempt chain under the given
  # resource_attempt and returns the new activity_attempt so tests can `select` it.
  defp setup_part_with_capi_response(resource_attempt, part_id, response) do
    title = "Type Test - #{part_id}"

    tree =
      AttemptBuilder.add_activities(%{}, resource_attempt, [
        {:activity_attempt, title, [{:part_attempt, part_id, response: response}]}
      ])

    tree[title].activity
  end

  defp build_attempt_graph do
    tree =
      %{}
      |> SectionBuilder.build([{:section, "sec"}, {:user, "stu"}])
      |> AttemptBuilder.build("sec", "stu", {:resource_attempt, "Page"})

    %{
      section: tree["sec"].section,
      resource_attempt: tree["Page"].resource_attempt,
      page_revision: tree["Page"].revision
    }
  end

  defp setup_sorted_attempts(_ctx) do
    tree =
      %{}
      |> SectionBuilder.build([{:section, "sec"}, {:user, "stu"}])
      |> AttemptBuilder.build(
        "sec",
        "stu",
        {:resource_attempt, "Page",
         [
           {:activity_attempt, "Middle Screen", [],
            attempt_number: 2, date_evaluated: ~U[2024-01-02 12:00:00Z]},
           {:activity_attempt, "Late Screen", [],
            attempt_number: 3, date_evaluated: ~U[2024-01-03 12:00:00Z]},
           {:activity_attempt, "Early Screen", [],
            attempt_number: 1, date_evaluated: ~U[2024-01-01 12:00:00Z]}
         ]}
      )

    %{section: tree["sec"].section, resource_attempt: tree["Page"].resource_attempt}
  end

  defp setup_attempts_with_responses(_ctx) do
    tree =
      %{}
      |> SectionBuilder.build([{:section, "sec"}, {:user, "stu"}])
      |> AttemptBuilder.build(
        "sec",
        "stu",
        {:resource_attempt, "Page",
         [
           {:activity_attempt, "MCQ Screen",
            [
              {:part_attempt, "hypothesis",
               response: %{
                 "selectedChoice" => 3,
                 "selectedChoiceText" => "Objects with longer half lives",
                 "enabled" => true,
                 "randomize" => false
               }}
            ]},
           {:activity_attempt, "Text Screen",
            [{:part_attempt, "__default", response: %{"input" => "Hello World"}}]},
           {:activity_attempt, "Unanswered Screen", [{:part_attempt, "__default", response: nil}]}
         ]}
      )

    %{
      section: tree["sec"].section,
      resource_attempt: tree["Page"].resource_attempt,
      mcq_activity: tree["MCQ Screen"].activity,
      text_activity: tree["Text Screen"].activity,
      empty_activity: tree["Unanswered Screen"].activity
    }
  end
end
