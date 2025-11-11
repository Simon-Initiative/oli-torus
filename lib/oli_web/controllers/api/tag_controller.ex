defmodule OliWeb.Api.TagController do
  @moduledoc """
  Endpoints to provide access to and mutation of tags.
  """

  alias Oli.Authoring.Editing.ResourceEditor
  import OliWeb.Api.Helpers

  use OliWeb, :controller

  def index(conn, %{"project" => project_slug}) do
    author = conn.assigns[:current_author]

    case ResourceEditor.list(
           project_slug,
           author,
           Oli.Resources.ResourceType.id_for_tag()
         ) do
      {:ok, revisions} ->
        json(conn, %{"result" => "success", "tags" => Enum.map(revisions, &serialize_revision/1)})

      {:error, {:not_found}} ->
        error(conn, 404, "not found")

      {:error, {:not_authorized}} ->
        error(conn, 403, "unauthorized")

      _ ->
        error(conn, 500, "server error")
    end
  end

  def new(conn, %{"project" => project_slug, "title" => title}) do
    author = conn.assigns[:current_author]

    case ResourceEditor.get_or_create_tag(project_slug, author, title) do
      {:ok, revision} ->
        json(conn, %{"result" => "success", "tag" => serialize_revision(revision)})

      {:error, {:not_found}} ->
        error(conn, 404, "not found")

      {:error, {:not_authorized}} ->
        error(conn, 403, "unauthorized")

      _ ->
        error(conn, 500, "server error")
    end
  end

  defp serialize_revision(%Oli.Resources.Revision{} = revision) do
    %{
      title: revision.title,
      id: revision.resource_id
    }
  end
end
