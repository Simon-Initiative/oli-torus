defmodule OliWeb.MediaController do

  alias Oli.Authoring.MediaLibrary.{MediaItem, ItemOptions}
  alias Oli.Authoring.MediaLibrary
  import OliWeb.ProjectPlugs

  use OliWeb, :controller

  plug :fetch_project when action not in [:index, :create]

  def index(conn, %{"project" => project_slug, "options" => client_options}) do

    options = ItemOptions.from_client_options(client_options)

    case MediaLibrary.items(project_slug, options) do
      {:ok, {items, count}} -> json conn, %{items: items, count: count}
    end

  end

  def create(conn, %{"project" => project_slug, "file" => file, "name" => name}) do

    case Base.decode64(file) do
      {:ok, contents} ->
        case MediaLibrary.add(project_slug, name, contents) do
          {:ok, %MediaItem{} = item} -> json conn, %{type: "success", url: item.url}
          {:error, error} -> error(conn, 400, error)
        end
      :error -> error(conn, 400, "invalid encoded file")
    end

  end

  def view(conn, %{"project_id" => _project_slug}) do

    render(conn, "view.html", title: "Media")

  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end

end
