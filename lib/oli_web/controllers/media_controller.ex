defmodule OliWeb.MediaController do

  alias Oli.Authoring.MediaLibrary.{MediaItem, ItemOptions}
  alias Oli.Authoring.MediaLibrary
  import OliWeb.ProjectPlugs

  use OliWeb, :controller

  plug :fetch_project when action not in [:index, :create]

  def index(conn, %{"project" => project_slug} = params) do

    options = ItemOptions.from_client_options(params)

    case MediaLibrary.items(project_slug, options) do
      {:ok, {items, count}} -> json conn, to_paginated_response(options, items, count)
    end

  end

  # changing this structure requires updating the definition
  # of PaginatedResponse type in the client codebase
  defp to_paginated_response(options, items, total) do
    %{
      type: "success",
      offset: options.offset,
      limit: options.limit,
      order: options.order,
      orderBy: options.order_field,
      numResults: length(items),
      totalResults: total,
      results: Enum.map(items, fn i -> to_client_media_item(i) end),
    }
  end

  defp to_client_media_item(%MediaItem{} = item) do
    %{
      rev: 1,
      dateCreated: item.inserted_at,
      dateUpdated: item.updated_at,
      guid: Integer.to_string(item.id),
      url: item.url,
      fileName: item.file_name,
      mimeType: item.mime_type,
      fileSize: item.file_size
    }
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

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, prettify_error(reason))
    |> halt()
  end

  # Match on MediaLibrary.add error reasons
  defp prettify_error(reason) do
    case reason do
      {:file_exists} -> "That file already exists in storage. A file can only be uploaded once."
      {:persistence} -> "The file could not be saved in storage. Hopefully, this is a temporary problem, so give it another try, but let us know if it continues to fail."
      {:not_found} -> "The project you are trying to upload to could not be found."
      %Ecto.Changeset{} = _changeset -> "It looks like something is wrong with that file's metadata. Make sure the image is correct, and if you're still having issues let us know."
      _ -> "Something unexpected prevented that file from being uploaded. Try another file or reach out to us for support."
    end
  end
end
