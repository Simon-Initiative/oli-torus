defmodule OliWeb.Delivery.StudentDashboard.Components.ContentTab do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div>
      <.live_component
        id="content_table"
        module={OliWeb.Components.Delivery.Content}
        params={@params}
        section_slug={@section_slug}
        containers={@containers}
        student_id={@student_id}
        patch_url_type={:student_dashboard}
      />
    </div>
    """
  end
end
