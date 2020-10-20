defmodule OliWeb.Common.Links do
  use Phoenix.HTML
  alias OliWeb.Router.Helpers, as: Routes

  def resource_path(revision, parent_pages, project_slug) do
    case Oli.Resources.ResourceType.get_type_by_id(revision.resource_type_id) do
      "objective" ->
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Objectives.Objectives,
          project_slug
        )

      "page" ->
        Routes.resource_path(
          OliWeb.Endpoint,
          :edit,
          project_slug,
          revision.slug
        )

      "activity" ->
        case Map.get(parent_pages, revision.resource_id) do
          nil ->
            revision.title

          parent_page ->
            Routes.resource_path(
              OliWeb.Endpoint,
              :edit,
              project_slug,
              parent_page.slug
            )
        end

      "container" ->
        Routes.container_path(
          OliWeb.Endpoint,
          :index,
          project_slug,
          revision.slug
        )
    end
  end

  def resource_link(revision, parent_pages, project, class \\ nil) do
    with path <- resource_path(revision, parent_pages, project.slug),
         resource_type <- Oli.Resources.ResourceType.get_type_by_id(revision.resource_type_id) do
      case resource_type do
        "activity" ->
          case Map.get(parent_pages, revision.resource_id) do
            nil ->
              revision.title

            _ ->
              link(revision.title,
                to: path,
                class: class
              )
          end

        _ ->
          link(revision.title,
            to: path,
            class: class
          )
      end
    end
  end
end
