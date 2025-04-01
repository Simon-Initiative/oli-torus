defmodule OliWeb.Api.PlatformInstanceController do
  use OliWeb, :controller

  alias Lti_1p3.DataProviders.EctoProvider.PlatformInstance
  alias Lti_1p3.Platform.LoginHint
  alias Lti_1p3.Platform.LoginHints
  alias Oli.Lti.PlatformInstances

  action_fallback OliWeb.FallbackController

  def index(conn, _params) do
    lti_1p3_platform_instances = PlatformInstances.list_lti_1p3_platform_instances()
    render(conn, "index.json", lti_1p3_platform_instances: lti_1p3_platform_instances)
  end

  def create(conn, %{"platform_instance" => platform_instance_params}) do
    with {:ok, %PlatformInstance{} = platform_instance} <-
           PlatformInstances.create_platform_instance(platform_instance_params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.platform_instance_path(conn, :show, platform_instance)
      )
      |> render("show.json", platform_instance: platform_instance)
    end
  end

  def show(conn, %{"id" => id}) do
    platform_instance = PlatformInstances.get_platform_instance!(id)
    render(conn, "show.json", platform_instance: platform_instance)
  end

  def details(conn, %{"client_id" => client_id}) do
    case PlatformInstances.get_platform_instance_by_client_id(client_id) do
      nil ->
        conn
        |> send_resp(:not_found, "Platform instance not found")
        |> halt()

      platform_instance ->
        author = conn.assigns[:current_author]

        {:ok, %LoginHint{value: login_hint}} = LoginHints.create_login_hint(author.id, "author")

        json(conn, %{
          type: "Ok",
          status: 200,
          statusText: "OK",
          result: %{
            name: platform_instance.name,
            launch_params: %{
              iss: Oli.Utils.get_base_url(),
              login_hint: login_hint,
              client_id: platform_instance.client_id,
              target_link_uri: platform_instance.target_link_uri,
              login_url: platform_instance.login_url
            }
          }
        })
    end
  end

  def update(conn, %{"id" => id, "platform_instance" => platform_instance_params}) do
    platform_instance = PlatformInstances.get_platform_instance!(id)

    with {:ok, %PlatformInstance{} = platform_instance} <-
           PlatformInstances.update_platform_instance(platform_instance, platform_instance_params) do
      render(conn, "show.json", platform_instance: platform_instance)
    end
  end

  def delete(conn, %{"id" => id}) do
    platform_instance = PlatformInstances.get_platform_instance!(id)

    with {:ok, %PlatformInstance{}} <-
           PlatformInstances.delete_platform_instance(platform_instance) do
      send_resp(conn, :no_content, "")
    end
  end
end
