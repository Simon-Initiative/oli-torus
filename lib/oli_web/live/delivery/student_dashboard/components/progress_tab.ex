defmodule OliWeb.Delivery.StudentDashboard.Components.ProgressTab do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
      <div>
        <.live_component
          id="progress_table"
          module={OliWeb.Components.Delivery.Progress}
          params={@params}
          section_slug={@section_slug}
          student_id={@student_id}
          context={@context}
          pages={@pages}
        />
      </div>
    """
  end
end
