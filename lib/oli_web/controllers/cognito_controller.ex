defmodule OliWeb.CognitoController do
  use OliWeb, :controller

  import OliWeb.ViewHelpers, only: [redirect_with_error: 3]
  import Oli.Utils

  alias Oli.{Repo, Sections, Accounts}
  alias Oli.Authoring.{Clone, Course}
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section

  def index(
        conn,
        %{
          "id_token" => _jwt,
          "error_url" => _error_url,
          "community_id" => community_id
        } = params
      ) do
    case Accounts.setup_sso_user(conn.assigns.claims, community_id) do
      {:ok, user} ->
        conn
        |> use_pow_config(:user)
        |> Pow.Plug.create(user)
        |> redirect(to: Routes.delivery_path(conn, :open_and_free_index))

      {:error, %Ecto.Changeset{}} ->
        redirect_with_error(conn, get_error_url(params), "Invalid parameters")
    end
  end

  def index(conn, params) do
    redirect_with_error(conn, get_error_url(params), "Missing parameters")
  end

  def launch(
        conn,
        %{
          "cognito_id_token" => _jwt,
          "error_url" => _error_url,
          "community_id" => community_id
        } = params
      ) do
    with anchor when not is_nil(anchor) <- fetch_product_or_project(params),
         {:ok, user} <- Accounts.setup_sso_user(conn.assigns.claims, community_id) do
      conn
      |> use_pow_config(:user)
      |> Pow.Plug.create(user)
      |> redirect(to: redirect_path(conn, user, anchor))
    else
      nil ->
        redirect_with_error(conn, get_error_url(params), "Invalid product or project")

      {:error, %Ecto.Changeset{}} ->
        redirect_with_error(conn, get_error_url(params), "Invalid parameters")
    end
  end

  def launch(conn, params) do
    redirect_with_error(conn, get_error_url(params), "Missing parameters")
  end

  def launch_clone(
        conn,
        %{
          "cognito_id_token" => _jwt,
          "error_url" => _error_url,
          "community_id" => community_id
        } = params
      ) do
    with anchor when not is_nil(anchor) <- fetch_product_or_project(params),
         {:ok, author} <- Accounts.setup_sso_author(conn.assigns.claims, community_id) do
      conn
      |> use_pow_config(:author)
      |> Pow.Plug.create(author)
      |> clone_or_prompt(author, anchor, get_error_url(params))
    else
      nil ->
        redirect_with_error(conn, get_error_url(params), "Invalid product or project")

      {:error, %Ecto.Changeset{}} ->
        redirect_with_error(conn, get_error_url(params), "Invalid parameters")
    end
  end

  def launch_clone(conn, params) do
    redirect_with_error(conn, get_error_url(params), "Missing parameters")
  end

  def prompt(conn, %{"project_slug" => project_slug}) do
    author = conn.assigns.current_author
    projects = Clone.existing_clones(project_slug, author)

    render(conn, "index.html", projects: projects, project_slug: project_slug)
  end

  def clone(conn, %{"project_slug" => project_slug}) do
    author = conn.assigns.current_author

    case Course.get_project_by_slug(project_slug) do
      %Project{allow_duplication: true} ->
        clone_project(conn, project_slug, author, get_error_url(%{}))

      %Project{} ->
        redirect_with_error(conn, get_error_url(%{}), "This project does not allow duplication")

      _ ->
        redirect_with_error(conn, get_error_url(%{}), "Invalid product or project")
    end
  end

  def clone(conn, params) do
    redirect_with_error(conn, get_error_url(params), "Missing parameters")
  end

  defp get_error_url(%{"error_url" => error_url}), do: error_url
  defp get_error_url(_params), do: "/unauthorized"

  defp fetch_product_or_project(%{"project_slug" => slug}) do
    Course.get_project_by_slug(slug)
  end

  defp fetch_product_or_project(%{"product_slug" => slug}) do
    Sections.get_section_by(slug: slug)
  end

  defp redirect_path(conn, user, anchor) do
    case Repo.preload(user, :enrollments).enrollments do
      [] ->
        create_section_url(conn, anchor)

      _ ->
        Routes.delivery_path(conn, :open_and_free_index)
    end
  end

  defp create_section_url(conn, %Project{} = project) do
    Routes.independent_sections_path(conn, :new, source_id: "project:#{project.id}")
  end

  defp create_section_url(conn, %Section{} = product) do
    Routes.independent_sections_path(conn, :new, source_id: "product:#{product.id}")
  end

  defp clone_or_prompt(conn, _author, %Project{allow_duplication: false}, error_url),
    do: redirect_with_error(conn, error_url, "This project does not allow duplication")

  defp clone_or_prompt(conn, _author, %Section{} = _product, error_url),
    do: redirect_with_error(conn, error_url, "This is not supported")

  defp clone_or_prompt(conn, author, %Project{slug: project_slug}, error_url) do
    if Clone.already_has_clone?(project_slug, author) do
      redirect(conn, to: Routes.cognito_path(conn, :prompt, project_slug))
    else
      clone_project(conn, project_slug, author, error_url)
    end
  end

  defp clone_project(conn, project_slug, author, error_url) do
    case Clone.clone_project(project_slug, author, author_in_project_title: true) do
      {:ok, dupe} ->
        redirect(conn, to: Routes.project_path(conn, :overview, dupe.slug))

      {:error, error} ->
        redirect_with_error(conn, error_url, snake_case_to_friendly(error))
    end
  end
end
