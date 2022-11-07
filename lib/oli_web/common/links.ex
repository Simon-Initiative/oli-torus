defmodule OliWeb.Common.Links do
  use Phoenix.HTML
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Resources.Numbering

  @doc """
  Returns a path uri for a given revision. If the revision type is not
  routable or of a known type, returns nil
  """
  def resource_path(revision, parent_pages, project_slug) do
    case Oli.Resources.ResourceType.get_type_by_id(revision.resource_type_id) do
      "objective" ->
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.ObjectivesLive.Objectives,
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

      "tag" ->
        Routes.activity_bank_path(
          OliWeb.Endpoint,
          :index,
          project_slug
        )

      _ ->
        nil
    end
  end

  def resource_link(revision, parent_pages, project, numberings \\ %{}, class \\ nil) do
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

        "container" ->
          numbering = Map.get(numberings, revision.id)

          title =
            if numbering do
              Numbering.prefix(numbering) <> ": " <> revision.title
            else
              revision.title
            end

          link(title, to: path, class: class)

        _ ->
          case path do
            nil ->
              revision.title

            _ ->
              link(revision.title,
                to: path,
                class: class
              )
          end
      end
    end
  end
end
