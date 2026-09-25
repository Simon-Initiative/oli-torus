defmodule OliWeb.Delivery.Pages.ActivitiesTableModelTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Delivery.Pages.ActivitiesTableModel

  test "linked mode retains expansion, question, attempts, and score columns only" do
    {:ok, model} = ActivitiesTableModel.new([], columns: :linked_activities)

    assert Enum.map(model.column_specs, & &1.label) == [
             nil,
             "Question Stem",
             "Attempts",
             "% Correct"
           ]
  end

  test "the percent correct header stays on one line, as the design specifies" do
    {:ok, model} = ActivitiesTableModel.new([], columns: :linked_activities)

    score_column = Enum.find(model.column_specs, &(&1.name == :avg_score))

    assert score_column.th_class =~ "whitespace-nowrap"
  end

  test "an unknown column mode raises instead of silently rendering the default columns" do
    assert_raise FunctionClauseError, fn ->
      ActivitiesTableModel.new([], columns: :not_a_mode)
    end
  end

  test "default mode retains order and learning objective columns" do
    {:ok, model} = ActivitiesTableModel.new([])

    assert Enum.map(model.column_specs, & &1.name) == [
             nil,
             :order,
             :title,
             :learning_objectives,
             :total_attempts,
             :avg_score
           ]
  end

  test "render_question_column omits the empty subtitle for adaptive screens" do
    activity = %{
      title: "Second Screen",
      resource_id: 2,
      has_lti_activity: false,
      content: %{"partsLayout" => []}
    }

    html =
      render_component(fn assigns ->
        ActivitiesTableModel.render_question_column(assigns, activity, nil)
      end)

    assert html =~ "Second Screen:"
    refute html =~ "[Empty]"
  end

  test "render_assessment_details uses activity detail hooks and marks instructor preview panes to use the preview activity bridge" do
    assessment = %{
      title: "Second Screen",
      resource_id: 2,
      content: %{"partsLayout" => []}
    }

    current_activity = %{
      resource_id: 2,
      id: 2,
      first_attempt_pct: 1.0,
      all_attempt_pct: 1.0,
      preview_rendered: nil
    }

    model = %{
      data: %{
        activity_summary_cache: %{2 => current_activity},
        expanded_activity_ids: MapSet.new([2]),
        scripts: ["/js/janus_mcq_delivery.js"],
        target: nil
      }
    }

    html =
      render_component(fn assigns ->
        assigns = Map.merge(assigns, %{model: model, activity_types_map: %{}})
        ActivitiesTableModel.render_assessment_details(assigns, assessment)
      end)

    assert html =~ ~s(phx-hook="ActivityDetailHooks")
    assert html =~ ~s(data-preview-activity-bridge="true")
    assert html =~ ~s(data-script-sources="[&quot;/js/janus_mcq_delivery.js&quot;]")
  end

  test "render_assessment_details falls back to cached activity summaries when selected activities are empty" do
    assessment = %{
      title: "Welcome Screen",
      resource_id: 9,
      content: %{"partsLayout" => []}
    }

    cached_activity = %{
      resource_id: 9,
      id: 9,
      revision: %{activity_type_id: 1},
      first_attempt_pct: 1.0,
      all_attempt_pct: 0.5,
      preview_rendered: "<div>cached preview</div>"
    }

    model = %{
      data: %{
        selected_activities: [],
        activity_summary_cache: %{9 => cached_activity},
        expanded_activity_ids: MapSet.new([9]),
        scripts: [],
        target: nil
      }
    }

    html =
      render_component(fn assigns ->
        assigns = Map.merge(assigns, %{model: model, activity_types_map: %{}})
        ActivitiesTableModel.render_assessment_details(assigns, assessment)
      end)

    assert html =~ "cached preview"
    assert html =~ "100%"
    assert html =~ "50%"
  end

  test "render_assessment_details preserves the expanded activity content and analytics" do
    assessment = %{
      title: "Question with analytics",
      resource_id: 10,
      content: %{"partsLayout" => []}
    }

    current_activity = %{
      resource_id: 10,
      id: 10,
      revision: %{activity_type_id: 1},
      first_attempt_pct: 0.5,
      all_attempt_pct: 0.75,
      preview_rendered: """
      <div>Answer Key</div>
      <div>Hints</div>
      <div>Explanation</div>
      <div>Dynamic Variables</div>
      <div>Answer distribution: Correct 1 of 2</div>
      """
    }

    model = %{
      data: %{
        activity_summary_cache: %{10 => current_activity},
        expanded_activity_ids: MapSet.new([10]),
        scripts: [],
        target: nil
      }
    }

    html =
      render_component(fn assigns ->
        assigns = Map.merge(assigns, %{model: model, activity_types_map: %{}})
        ActivitiesTableModel.render_assessment_details(assigns, assessment)
      end)

    assert html =~ "Answer Key"
    assert html =~ "Hints"
    assert html =~ "Explanation"
    assert html =~ "Dynamic Variables"
    assert html =~ "Answer distribution: Correct 1 of 2"
    assert html =~ "First Try Correct"
    assert html =~ "Eventually Correct"
    assert html =~ "50%"
    assert html =~ "75%"
  end

  test "render_assessment_details defaults missing aggregate percentages to zero" do
    assessment = %{
      title: "Manual Screen",
      resource_id: 53,
      content: %{"partsLayout" => []}
    }

    current_activity = %{
      resource_id: 53,
      id: 53,
      preview_rendered: nil
    }

    model = %{
      data: %{
        activity_summary_cache: %{53 => current_activity},
        expanded_activity_ids: MapSet.new([53]),
        target: nil
      }
    }

    html =
      render_component(fn assigns ->
        assigns = Map.merge(assigns, %{model: model, activity_types_map: %{}})
        ActivitiesTableModel.render_assessment_details(assigns, assessment)
      end)

    assert html =~ "First Try Correct"
    assert html =~ "Eventually Correct"
    assert html =~ "0%"
  end

  test "render_assessment_details distinguishes the three summary states" do
    assessment = %{title: "Question", resource_id: 55, content: %{"partsLayout" => []}}

    render_status = fn current_activity ->
      model = %{
        data: %{
          activity_summary_cache: %{55 => current_activity},
          expanded_activity_ids: MapSet.new([55]),
          target: nil
        }
      }

      render_component(fn assigns ->
        assigns = Map.merge(assigns, %{model: model, activity_types_map: %{}})
        ActivitiesTableModel.render_assessment_details(assigns, assessment)
      end)
    end

    base = %{
      resource_id: 55,
      id: 55,
      preview_rendered: nil,
      first_attempt_pct: 0.0,
      all_attempt_pct: 0.0
    }

    no_observations = render_status.(Map.put(base, :summary_status, :no_observations))

    assert no_observations =~ "No attempt registered for this question"
    refute no_observations =~ "Value cannot be computed"
    assert no_observations =~ "First Try Correct"
    assert no_observations =~ "pct-bar-"

    unavailable = render_status.(Map.put(base, :summary_status, :unavailable))

    refute unavailable =~ "No attempt registered for this question"
    refute unavailable =~ "Question analytics are not available"

    # The designer asked for the copy in place of each bar, one per label, so each metric group must
    # carry its own message and neither chart may render.
    assert metric_groups(unavailable) == [
             "First Try Correct Value cannot be computed",
             "Eventually Correct Value cannot be computed"
           ]

    refute unavailable =~ "pct-bar-"

    legacy = render_status.(base)

    assert legacy =~ "No attempt registered for this question"
    assert legacy =~ "First Try Correct"
  end

  test "render_assessment_details omits the percentage bars when metrics are unavailable" do
    assessment = %{
      title: "Manual Screen",
      resource_id: 54,
      content: %{"partsLayout" => []}
    }

    current_activity = %{
      resource_id: 54,
      id: 54,
      preview_rendered: nil,
      metrics_unavailable: true
    }

    model = %{
      data: %{
        activity_summary_cache: %{54 => current_activity},
        expanded_activity_ids: MapSet.new([54]),
        target: nil
      }
    }

    html =
      render_component(fn assigns ->
        assigns = Map.merge(assigns, %{model: model, activity_types_map: %{}})
        ActivitiesTableModel.render_assessment_details(assigns, assessment)
      end)

    # A failed summary load must not render 0%, which reads as genuinely zero performance. The labels
    # stay so the reader knows which metric is missing.
    assert metric_groups(html) == [
             "First Try Correct Value cannot be computed",
             "Eventually Correct Value cannot be computed"
           ]

    refute html =~ "Question analytics are not available"
    refute html =~ "0%"
    refute html =~ "pct-bar-"
  end

  test "render_assessment_details shows a repair notice while adaptive analytics refresh is in progress" do
    assessment = %{
      title: "Legacy Adaptive Screen",
      resource_id: 77,
      content: %{"partsLayout" => []}
    }

    current_activity = %{
      resource_id: 77,
      id: 77,
      first_attempt_pct: 0.0,
      all_attempt_pct: 0.0,
      revision: %{activity_type_id: 99},
      preview_rendered: "<div>preview</div>",
      adaptive_input_summaries: [],
      adaptive_summary_repair_status: :refreshing
    }

    model = %{
      data: %{
        activity_summary_cache: %{77 => current_activity},
        expanded_activity_ids: MapSet.new([77]),
        target: nil
      }
    }

    html =
      render_component(fn assigns ->
        assigns =
          Map.merge(assigns, %{model: model, activity_types_map: %{99 => %{slug: "oli_adaptive"}}})

        ActivitiesTableModel.render_assessment_details(assigns, assessment)
      end)

    assert html =~ "Refreshing adaptive analytics"
    assert html =~ "background refresh is running"
  end

  test "render_assessment_details shows a refreshed notice after adaptive analytics finish reloading" do
    assessment = %{
      title: "Legacy Adaptive Screen",
      resource_id: 78,
      content: %{"partsLayout" => []}
    }

    current_activity = %{
      resource_id: 78,
      id: 78,
      first_attempt_pct: 0.25,
      all_attempt_pct: 0.5,
      revision: %{activity_type_id: 99},
      preview_rendered: "<div>preview</div>",
      adaptive_input_summaries: [],
      adaptive_summary_repair_status: :refreshed
    }

    model = %{
      data: %{
        activity_summary_cache: %{78 => current_activity},
        expanded_activity_ids: MapSet.new([78]),
        target: nil
      }
    }

    html =
      render_component(fn assigns ->
        assigns =
          Map.merge(assigns, %{model: model, activity_types_map: %{99 => %{slug: "oli_adaptive"}}})

        ActivitiesTableModel.render_assessment_details(assigns, assessment)
      end)

    assert html =~ "Adaptive analytics refreshed"
    assert html =~ "have been reloaded"
  end

  defp metric_groups(html) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find("div[class*=\"justify-start\"]")
    |> Enum.map(fn group -> group |> Floki.text(sep: " ") |> String.split() |> Enum.join(" ") end)
  end
end
