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
end
