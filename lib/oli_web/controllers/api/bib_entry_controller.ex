defmodule OliWeb.Api.BibEntryController do
  @moduledoc """
  Endpoints to provide access to and mutation of bib_entries.
  """

  alias Oli.Authoring.Editing.BibEntryEditor
  import OliWeb.Api.Helpers
  alias Oli.Repo.{Paging}

  use OliWeb, :controller

  def index(conn, %{"project" => project_slug}) do
    author = conn.assigns[:current_author]

    case BibEntryEditor.list(project_slug, author) do
      {:ok, revisions} ->
        json(conn, %{"result" => "success", "rows" => Enum.map(revisions, &serialize_revision/1)})

      {:error, {:not_found}} ->
        error(conn, 404, "not found")

      {:error, {:not_authorized}} ->
        error(conn, 403, "unauthorized")

      _ ->
        error(conn, 500, "server error")
    end
  end

  def new(conn, %{"project" => project_slug, "title" => title, "content" => content}) do
    author = conn.assigns[:current_author]

    case BibEntryEditor.create(project_slug, author, %{"title" => title, "author_id" => author.id, "content" => %{data: Poison.decode!(content)}}) do
      {:ok, {:ok, revision}} ->
        json(conn, %{"result" => "success", "bibentry" => serialize_revision(revision)})

      {:error, {:not_found}} ->
        error(conn, 404, "not found")

      {:error, {:not_authorized}} ->
        error(conn, 403, "unauthorized")

      _ ->
        error(conn, 500, "server error")
    end
  end

  def update(conn, %{"project" => project_slug, "title" => title, "content" => content, "entry" => entry_id}) do
    author = conn.assigns[:current_author]

    case BibEntryEditor.edit(project_slug, entry_id, author, %{"title" => title, "author_id" => author.id, "content" => %{data: Poison.decode!(content)}}) do
      {:ok, revision} ->
        json(conn, %{"result" => "success", "bibentry" => serialize_revision(revision)})

      {:error, {:not_found}} ->
        error(conn, 404, "not found")

      {:error, {:not_authorized}} ->
        error(conn, 403, "unauthorized")

      _ ->
        error(conn, 500, "server error")
    end
  end

  def retrieve(conn, %{"project" => project_slug, "paging" => %{"offset" => offset, "limit" => limit}}) do
    author = conn.assigns[:current_author]
    case BibEntryEditor.retrieve(project_slug, author, %Paging{offset: offset, limit: limit}) do
      {:ok, %{rows: rows, total_count: total_count}} ->
        json(conn, %{
          "result" => "success",
          "queryResult" => %{
            rowCount: length(rows),
            totalCount: total_count,
            rows: Enum.map(rows, &serialize_revision/1)
          }
        })

      {:error, {:not_found}} ->
        error(conn, 404, "not found")

      {:error, {:not_authorized}} ->
        error(conn, 403, "unauthorized")

      _ ->
        error(conn, 500, "server error")
    end
  end

  def delete(conn, %{"project" => project_slug, "entry" => entry_id}) do
    author = conn.assigns[:current_author]

    case BibEntryEditor.delete(project_slug, entry_id, author) do
      {:ok, _} ->
        json(conn, %{"result" => "success"})

      {:error, {:not_found}} ->
        error(conn, 404, "not found")

      {:error, {:not_authorized}} ->
        error(conn, 403, "unauthorized")

      e ->
        {_, msg} = Oli.Utils.log_error("Could not delete bibliography entry", e)
        error(conn, 500, msg)
    end
  end

  defp serialize_revision(%Oli.Resources.Revision{} = revision) do
    %{
      title: revision.title,
      id: revision.resource_id,
      slug: revision.slug,
      content: revision.content
    }
  end
end
