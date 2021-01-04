defmodule OliWeb.Grades.Export do
  use OliWeb, :live_component

  def render(assigns) do

    link_text = dgettext("grades", "Export and Download Gradebook")

    ~L"""
    <div class="card">
      <div class="card-body">
        <h5 class="card-title">Export Grades</h5>

        <p class="card-text">The current grades for all students and all graded pages can be exported as a <code>.csv</code> file.</p>

      </div>

      <div class="card-footer">
       <%= link link_text, to: Routes.page_delivery_path(OliWeb.Endpoint, :export_gradebook, @context_id), class: "btn btn-primary" %>
      </div>
    </div>
    """
  end

end
