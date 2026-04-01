defmodule OliWeb.Delivery.Pages.ActivitiesTableModelTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Delivery.Pages.ActivitiesTableModel

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

  test "render_assessment_details marks instructor preview panes to use the preview activity bridge" do
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
        selected_activities: [current_activity],
        expanded_activity_ids: MapSet.new([2]),
        target: nil
      }
    }

    html =
      render_component(fn assigns ->
        assigns = Map.merge(assigns, %{model: model, activity_types_map: %{}})
        ActivitiesTableModel.render_assessment_details(assigns, assessment)
      end)

    assert html =~ ~s(phx-hook="LoadSurveyScripts")
    assert html =~ ~s(data-preview-activity-bridge="true")
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
        selected_activities: [current_activity],
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
        selected_activities: [current_activity],
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
        selected_activities: [current_activity],
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
end
