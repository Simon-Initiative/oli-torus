defmodule OliWeb.ProjectView do
  use OliWeb, :view
  alias Oli.Publishing

  def resource_link(activity_map, slug, title, conn, project) do
    if Map.get(activity_map, slug) do
      link title, to: Routes.activity_path(conn, :edit, project, hd(Map.get(activity_map, slug)), slug)
    else
      link title, to: Routes.resource_path(conn, :edit, project, slug)
    end
  end

end
