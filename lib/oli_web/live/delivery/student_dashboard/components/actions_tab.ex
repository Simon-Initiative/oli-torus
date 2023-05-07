defmodule OliWeb.Delivery.StudentDashboard.Components.ActionsTab do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
      <div>
        <.live_component
          id="actions_table"
          module={OliWeb.Components.Delivery.Actions}
          user={@user}
          section_slug={@section_slug}
          enrollment_info={@enrollment_info}
        />
      </div>
    """
  end
end
