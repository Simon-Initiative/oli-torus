defmodule OliWeb.Workspaces.CourseAuthor.Datasets.Common do
  use OliWeb, :html

  def age_warning(assigns) do
    ~H"""
    <div class="alert alert-info mt-5" role="alert">
      <strong>Note:</strong> Dataset results can trail behind student activity by up to 24 hours.
    </div>
    """
  end
end
