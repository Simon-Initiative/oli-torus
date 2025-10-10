defmodule OliWeb.Grades.Export do
  use OliWeb, :html

  attr(:section_slug, :string)

  def render(assigns) do
    assigns = assign(assigns, :link_text, dgettext("grades", "Download Scorebook"))

    ~H"""
    <div class="card">
      <div class="card-body">
        <h5 class="card-title">Export Scores</h5>

        <p class="card-text">
          The current scores for all students and all scored pages can be exported as a
          <code>.csv</code>
          file.
        </p>
      </div>

      <div class="card-footer mt-4">
        {link(@link_text,
          to: Routes.page_delivery_path(OliWeb.Endpoint, :export_gradebook, @section_slug),
          class: "btn btn-primary"
        )}
      </div>
    </div>
    """
  end
end
