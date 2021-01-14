defmodule OliWeb.PlatformController do
  use OliWeb, :controller

  alias Oli.Lti_1p3.Platform
  alias Oli.Lti_1p3.Platforms

  action_fallback OliWeb.FallbackController

  def index(conn, _params) do
    lti_1p3_platforms = Platforms.list_lti_1p3_platforms()
    render(conn, "index.json", lti_1p3_platforms: lti_1p3_platforms)
  end

  def create(conn, %{"platform" => platform_params}) do
    with {:ok, %Platform{} = platform} <- Platforms.create_platform(platform_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.platform_path(conn, :show, platform))
      |> render("show.json", platform: platform)
    end
  end

  def show(conn, %{"id" => id}) do
    platform = Platforms.get_platform!(id)
    render(conn, "show.json", platform: platform)
  end

  def update(conn, %{"id" => id, "platform" => platform_params}) do
    platform = Platforms.get_platform!(id)

    with {:ok, %Platform{} = platform} <- Platforms.update_platform(platform, platform_params) do
      render(conn, "show.json", platform: platform)
    end
  end

  def delete(conn, %{"id" => id}) do
    platform = Platforms.get_platform!(id)

    with {:ok, %Platform{}} <- Platforms.delete_platform(platform) do
      send_resp(conn, :no_content, "")
    end
  end
end
