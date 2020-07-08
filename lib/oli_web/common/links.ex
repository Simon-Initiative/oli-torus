defmodule OliWeb.Common.Links do

  use Phoenix.HTML
  alias OliWeb.Router.Helpers, as: Routes

  def resource_link(revision, parent_pages, project) do
    case Oli.Resources.ResourceType.get_type_by_id(revision.resource_type_id) do
      "objective" -> link revision.title, to: Routes.live_path(OliWeb.Endpoint, OliWeb.Objectives.Objectives, project.slug)
      "page" -> link revision.title, to: Routes.resource_path(OliWeb.Endpoint, :edit, project, revision.slug)
      "activity" -> link revision.title, to: Routes.resource_path(OliWeb.Endpoint, :edit, project, Map.get(parent_pages, revision.resource_id).slug)
      "container" -> link revision.title, to: Routes.live_path(OliWeb.Endpoint, OliWeb.Curriculum.Container, project.slug)
    end

  end
end
