defmodule OliWeb.Api.PlatformInstanceController do
  use OliWeb, :controller

  alias Lti_1p3.DataProviders.EctoProvider.PlatformInstance
  alias Oli.Lti_1p3.PlatformInstances

  action_fallback OliWeb.FallbackController

  def index(conn, _params) do
    lti_1p3_platform_instances = PlatformInstances.list_lti_1p3_platform_instances()
    render(conn, "index.json", lti_1p3_platform_instances: lti_1p3_platform_instances)
  end

  def create(conn, %{"platform_instance" => platform_instance_params}) do
    with {:ok, %PlatformInstance{} = platform_instance} <- PlatformInstances.create_platform_instance(platform_instance_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.platform_instance_path(conn, :show, platform_instance))
      |> render("show.json", platform_instance: platform_instance)
    end
  end

  def show(conn, %{"id" => id}) do
    platform_instance = PlatformInstances.get_platform_instance!(id)
    render(conn, "show.json", platform_instance: platform_instance)
  end

  def update(conn, %{"id" => id, "platform_instance" => platform_instance_params}) do
    platform_instance = PlatformInstances.get_platform_instance!(id)

    with {:ok, %PlatformInstance{} = platform_instance} <- PlatformInstances.update_platform_instance(platform_instance, platform_instance_params) do
      render(conn, "show.json", platform_instance: platform_instance)
    end
  end

  def delete(conn, %{"id" => id}) do
    platform_instance = PlatformInstances.get_platform_instance!(id)

    with {:ok, %PlatformInstance{}} <- PlatformInstances.delete_platform_instance(platform_instance) do
      send_resp(conn, :no_content, "")
    end
  end
end
