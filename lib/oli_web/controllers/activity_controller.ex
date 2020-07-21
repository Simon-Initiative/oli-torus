defmodule OliWeb.ActivityController do
  use OliWeb, :controller

  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Accounts
  alias Oli.Delivery.Attempts
  alias Oli.Delivery.Attempts.StudentInput
  alias Oli.Publishing

  import OliWeb.ProjectPlugs

  plug :fetch_project when action in [:edit]
  plug :authorize_project when action in [:edit]

  def edit(conn, %{"project_id" => project_slug, "revision_slug" => revision_slug, "activity_slug" => activity_slug}) do

    author = conn.assigns[:current_author]
    is_admin? = Accounts.is_admin?(author)

    lock_author = Publishing.retrieve_lock_author(project_slug, revision_slug)
    # Return nil if author is the same as edit requester
    lock_author = if lock_author == nil || lock_author.email == author.email do
      nil
    else
      lock_author
    end

    case ActivityEditor.create_context(project_slug, revision_slug, activity_slug, author) do
      {:ok, context} -> render(conn, "edit.html", active: :curriculum, title: "Activity Editor", project_slug: project_slug, author: lock_author, is_admin?: is_admin?, activity_slug: activity_slug, script: context.authoringScript, context: Jason.encode!(context))
      {:error, :not_found} -> render conn, OliWeb.SharedView, "_not_found.html"
    end

  end

  def create(conn, %{"project" => project_slug, "activity_type" => activity_type_slug, "model" => model, "objectives" => objectives}) do

    author = conn.assigns[:current_author]

    case ActivityEditor.create(project_slug, activity_type_slug, author, model, objectives) do
      {:ok, {%{slug: slug}, transformed}} -> json conn, %{ "type" => "success", "revisionSlug" => slug, "transformed" => transformed}
      {:error, {:not_found}} -> error(conn, 404, "not found")
      {:error, {:not_authorized}} -> error(conn, 403, "unauthorized")
      _ -> error(conn, 500, "server error")
    end

  end

  def update(conn, %{"project" => project_slug, "resource" => resource_slug, "activity" => activity_slug, "update" => update }) do
    author = conn.assigns[:current_author]

    case ActivityEditor.edit(project_slug, resource_slug, activity_slug, author.email, update) do
      {:ok, %{slug: slug}} -> json conn, %{ "type" => "success", "revisionSlug" => slug}
      {:error, {:not_found}} -> error(conn, 404, "not found")
      {:error, {:not_authorized}} -> error(conn, 403, "unauthorized")
      _ -> error(conn, 500, "server error")
    end
  end

  # endpoint for test mode evaluation
  def evaluate(conn, %{"model" => model, "partResponses" => part_inputs}) do
    parsed = Enum.map(part_inputs, fn %{"attemptGuid" => part_id, "response" => input} ->
      %{part_id: part_id, input: %StudentInput{input: Map.get(input, "input")}} end)

    case Attempts.perform_test_evaluation(model, parsed) do
      {:ok, evaluations} -> json conn, %{ "type" => "success", "evaluations" => evaluations}
      {:error, _} -> error(conn, 500, "server error")
    end
  end

  def transform(conn, %{"model" => model}) do
    case Attempts.perform_test_transformation(model) do
      {:ok, transformed} -> json conn, %{ "type" => "success", "transformed" => transformed}
      {:error, _} -> error(conn, 500, "server error")
    end
  end

  def delete(conn, %{"project" => _project_slug, "activity" => _activity_slug }) do

    _author = conn.assigns[:current_author]

  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end

end
