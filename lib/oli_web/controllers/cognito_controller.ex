defmodule OliWeb.CognitoController do
  use OliWeb, :controller
  use OliWeb, :verified_routes

  import OliWeb.ViewHelpers, only: [redirect_with_error: 3]
  import Oli.Utils

  alias Oli.{Repo, Sections, Accounts}
  alias Oli.Authoring.{Clone, Course}
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias OliWeb.{UserAuth, AuthorAuth}

  @sign_in_failed "Unable to sign in. Please try again."

  def index(
        conn,
        %{"id_token" => _jwt, "error_url" => _error_url, "community_id" => community_id} = params
      ) do
    with {:ok, user, author} <- Accounts.setup_sso_user(conn.assigns.claims, community_id),
         {:ok, conn} <- create_sessions(conn, user, author) do
      redirect(conn, to: ~p"/workspaces/instructor")
    else
      {:error, %Ecto.Changeset{}} ->
        redirect_with_error(conn, get_error_url(params), "Invalid parameters")

      {:error, :session_not_issued} ->
        redirect_with_error(conn, get_error_url(params), @sign_in_failed)

      {:error, _reason} ->
        redirect_with_error(conn, get_error_url(params), @sign_in_failed)
    end
  end

  def index(conn, params) do
    redirect_with_error(conn, get_error_url(params), "Missing parameters")
  end

  def launch(
        conn,
        %{"id_token" => _jwt, "error_url" => _error_url, "community_id" => community_id} = params
      ) do
    with anchor when not is_nil(anchor) <- fetch_product_or_project(params),
         {:ok, user, author} <- Accounts.setup_sso_user(conn.assigns.claims, community_id),
         {:ok, conn} <- create_sessions(conn, user, author) do
      create_or_prompt(conn, user, anchor)
    else
      nil ->
        redirect_with_error(conn, get_error_url(params), "Invalid template or project")

      {:error, %Ecto.Changeset{}} ->
        redirect_with_error(conn, get_error_url(params), "Invalid parameters")

      {:error, :session_not_issued} ->
        redirect_with_error(conn, get_error_url(params), @sign_in_failed)

      {:error, _reason} ->
        redirect_with_error(conn, get_error_url(params), @sign_in_failed)
    end
  end

  def launch(conn, params) do
    redirect_with_error(conn, get_error_url(params), "Missing parameters")
  end

  def launch_clone(
        conn,
        %{
          "id_token" => _jwt,
          "error_url" => _error_url,
          "community_id" => community_id
        } = params
      ) do
    with anchor when not is_nil(anchor) <- fetch_product_or_project(params),
         {:ok, author} <- Accounts.setup_sso_author(conn.assigns.claims, community_id),
         {:ok, conn} <- AuthorAuth.create_session(conn, author, :cognito) do
      clone_or_prompt(conn, author, anchor, get_error_url(params))
    else
      nil ->
        redirect_with_error(conn, get_error_url(params), "Invalid template or project")

      {:error, %Ecto.Changeset{}} ->
        redirect_with_error(conn, get_error_url(params), "Invalid parameters")

      {:error, :session_not_issued} ->
        redirect_with_error(conn, get_error_url(params), @sign_in_failed)

      {:error, _reason} ->
        redirect_with_error(conn, get_error_url(params), @sign_in_failed)
    end
  end

  def launch_clone(conn, params) do
    redirect_with_error(conn, get_error_url(params), "Missing parameters")
  end

  def clone(conn, %{"project_slug" => project_slug}) do
    author = conn.assigns.current_author

    case Course.get_project_by_slug(project_slug) do
      %Project{allow_duplication: true} ->
        clone_project(conn, project_slug, author, get_error_url(%{}))

      %Project{} ->
        redirect_with_error(conn, get_error_url(%{}), "This project does not allow duplication")

      _ ->
        redirect_with_error(conn, get_error_url(%{}), "Invalid template or project")
    end
  end

  def clone(conn, params) do
    redirect_with_error(conn, get_error_url(params), "Missing parameters")
  end

  def prompt_clone(conn, %{"project_slug" => project_slug}) do
    author = conn.assigns.current_author
    projects = Clone.existing_clones(project_slug, author)

    render(conn, "clone_prompt.html",
      title: "Clone",
      projects: projects,
      project_slug: project_slug
    )
  end

  def prompt_create(conn, params) do
    case fetch_product_or_project(params) do
      nil ->
        redirect_with_error(conn, get_error_url(%{}), "Invalid template or project")

      anchor ->
        render(conn, "create_prompt.html",
          title: "Create",
          create_section_url: create_section_url(conn, anchor)
        )
    end
  end

  defp get_error_url(%{"error_url" => error_url}), do: error_url
  defp get_error_url(_params), do: "/unauthorized"

  defp fetch_product_or_project(%{"project_slug" => slug}) do
    Course.get_project_by_slug(slug)
  end

  defp fetch_product_or_project(%{"product_slug" => slug}) do
    Sections.get_section_by(slug: slug)
  end

  defp create_section_url(conn, %Project{} = project) do
    Routes.independent_sections_path(conn, :new, source_id: "project:#{project.id}")
  end

  defp create_section_url(conn, %Section{} = product) do
    Routes.independent_sections_path(conn, :new, source_id: "product:#{product.id}")
  end

  defp prompt_redirect_url(conn, %Project{slug: project_slug}, :create),
    do: Routes.prompt_project_create_path(conn, :prompt_create, project_slug)

  defp prompt_redirect_url(conn, %Section{slug: section_slug}, :create),
    do: Routes.prompt_product_create_path(conn, :prompt_create, section_slug)

  defp prompt_redirect_url(conn, %Project{slug: project_slug}, :clone),
    do: Routes.prompt_project_clone_path(conn, :prompt_clone, project_slug)

  defp prompt_redirect_url(conn, _, _),
    do: redirect_with_error(conn, get_error_url(%{}), "This is not supported")

  defp create_or_prompt(conn, user, anchor) do
    path =
      case Repo.preload(user, :enrollments).enrollments do
        [] ->
          create_section_url(conn, anchor)

        _ ->
          prompt_redirect_url(conn, anchor, :create)
      end

    redirect(conn, to: path)
  end

  defp clone_or_prompt(conn, _author, %Project{allow_duplication: false}, error_url),
    do: redirect_with_error(conn, error_url, "This project does not allow duplication")

  defp clone_or_prompt(conn, _author, %Section{} = _product, error_url),
    do: redirect_with_error(conn, error_url, "This is not supported")

  defp clone_or_prompt(conn, author, %Project{slug: project_slug} = project, error_url) do
    if Clone.already_has_clone?(project_slug, author) do
      redirect(conn, to: prompt_redirect_url(conn, project, :clone))
    else
      clone_project(conn, project_slug, author, error_url)
    end
  end

  defp clone_project(conn, project_slug, author, error_url) do
    case Clone.clone_project(project_slug, author, author_in_project_title: true) do
      {:ok, dupe} ->
        redirect(conn,
          to: ~p"/workspaces/course_author/#{dupe.slug}/overview"
        )

      {:error, error} ->
        redirect_with_error(conn, error_url, snake_case_to_friendly(error))
    end
  end

  # Issues the user session and then the author session; the author session is not issued when
  # the user session fails.
  defp create_sessions(conn, user, author) do
    with {:ok, conn} <- UserAuth.create_session(conn, user, :cognito) do
      AuthorAuth.create_session(conn, author, :cognito)
    end
  end
end
