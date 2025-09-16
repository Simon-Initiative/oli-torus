defmodule OliWeb.Common.Links do
  use Phoenix.HTML
  use OliWeb, :verified_routes

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Resources.Numbering
  alias Oli.Accounts.User

  @doc """
  Returns a path uri for a given revision. If the revision type is not
  routable or of a known type, returns nil
  """
  def resource_path(revision, parent_pages, project_slug, workspace \\ nil) do
    do_resource_path(revision, parent_pages, project_slug, workspace)
  end

  def do_resource_path(revision, parent_pages, project_slug, workspace) do
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
        if workspace == :workspace do
          ~p"/workspaces/course_author/#{project_slug}/curriculum/#{revision.slug}"
        else
          Routes.container_path(
            OliWeb.Endpoint,
            :index,
            project_slug,
            revision.slug
          )
        end

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

  @doc """
  Returns the correct path to the my courses page based on the user's role.
  """
  def my_courses_path(%User{can_create_sections: true}), do: ~p"/workspaces/instructor"

  def my_courses_path(_), do: ~p"/workspaces/student"
end
