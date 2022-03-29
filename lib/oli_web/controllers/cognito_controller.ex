defmodule OliWeb.CognitoController do
  use OliWeb, :controller

  import OliWeb.ViewHelpers, only: [redirect_with_error: 3]

  alias Oli.{Repo, Sections, Accounts}
  alias Oli.Authoring.Course
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
end
