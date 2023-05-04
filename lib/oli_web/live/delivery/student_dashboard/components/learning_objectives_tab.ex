defmodule OliWeb.Delivery.StudentDashboard.Components.LearningObjectivesTab do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div>
      <.live_component
        id="objectives_table"
        module={OliWeb.Components.Delivery.LearningObjectives}
        params={@params}
        section_slug={@section_slug}
        objectives_tab={@objectives_tab}
        student_id={@student_id}
        patch_url_type={:student_dashboard}
      />
    </div>
    """
  end
end
