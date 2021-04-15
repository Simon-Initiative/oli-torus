defmodule OliWeb.Api.MediaController do
  @moduledoc tags: ["Media Library Service"]

  @moduledoc """
  The media library service allows operations on a project by project
  basis to create (upload) and access media items.
  """

  alias OpenApiSpex.Schema

  alias Oli.Authoring.MediaLibrary.{MediaItem, ItemOptions}
  alias Oli.Authoring.MediaLibrary
  import OliWeb.ProjectPlugs

  use OliWeb, :controller
  use OpenApiSpex.Controller

  plug :fetch_project when action not in [:index, :create]

  defmodule MediaItemUpload do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Media Item Upload",
      description: "An uploaded media item",
      type: :object,
      properties: %{
        file: %Schema{type: :string, description: "Base 64 encoded content of the file"},
        name: %Schema{type: :string, description: "The file name"}
      },
      required: [:file, :name],
      example: %{
        "file" => "QSBob2xsb3cgdm9pY2Ugc2F5cyBQbHVnaCE=",
        "name" => "untitled.jpg"
      }
    })
  end

  defmodule MediaItemUploadResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Media Item Upload Response",
      description: "An uploaded media item response",
      type: :object,
      properties: %{
        url: %Schema{type: :string, description: "The URL of the item in the media library"}
      },
      required: [:file, :name],
      example: %{
        "url" => "https://torus-media.s3-amazon.com/asdfljk/test.png"
      }
    })
  end

  defmodule MediaItemPageSchema do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Media Item Page",
      description: "A page of items in the media library",
      type: :object,
      properties: %{
        offset: %Schema{type: :integer, description: "The offset setting applied"},
        limit: %Schema{type: :integer, description: "The limit setting applied"},
        order: %Schema{type: :string, description: "The sort order direction applied"},
        orderBy: %Schema{type: :string, description: "The sort order field applied"},
        numResults: %Schema{type: :integer, description: "Number of results in this page"},
        totalResults: %Schema{
          type: :integer,
          description: "Total number of results across all pages"
        },
        results: %Schema{type: :list, description: "Array of media item results"}
      },
      required: [],
      example: %{
        "offset" => 60,
        "limit" => 40,
        "order" => "asc",
        "orderBy" => "fileName",
        "numResults" => 40,
        "totalResults" => 200,
        "results" => [
          %{
            "url" => "https://torus-media.amazon-s3.com/asdloi/untitled.png",
            "dateCreated" => 1_503_368_342,
            "dateUpdated" => 1_606_768_149,
            "guid" => "b89c2272-725c-4cca-bc71-8f37dfe6dbec",
            "fileName" => "untitled.png",
            "mimeType" => "image/png",
            "fileSize" => 129_342
          }
        ]
      }
    })
  end

  @doc """
  List a page of media items from the media library.
  """
  @doc parameters: [
         offset: [
           in: :query,
           schema: %OpenApiSpex.Schema{type: :integer},
           required: false,
           description: "Index offset into the results"
         ],
         limit: [
           in: :query,
           schema: %OpenApiSpex.Schema{type: :integer},
           required: false,
           description: "Limit of the number of results"
         ],
         mime_filter: [
           in: :query,
           schema: %OpenApiSpex.Schema{type: :string},
           required: false,
           description: "Mime filter to apply"
         ],
         url_filter: [
           in: :query,
           schema: %OpenApiSpex.Schema{type: :string},
           required: false,
           description: "URL filter to apply"
         ],
         search_text: [
           in: :query,
           schema: %OpenApiSpex.Schema{type: :string},
           required: false,
           description: "Search text to apply"
         ],
         order: [
           in: :query,
           schema: %OpenApiSpex.Schema{type: :string},
           required: false,
           description: "Sort order to apply, asc or desc"
         ],
         order_field: [
           in: :query,
           schema: %OpenApiSpex.Schema{type: :string},
           required: false,
           description: "Sort field"
         ]
       ],
       responses: %{
         200 =>
           {"Media Item Page", "application/json", OliWeb.MediaController.MediaItemPageSchema}
       }
  def index(conn, %{"project" => project_slug} = params) do
    options = ItemOptions.from_client_options(params)

    case MediaLibrary.items(project_slug, options) do
      {:ok, {items, count}} -> json(conn, to_paginated_response(options, items, count))
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
      results: Enum.map(items, fn i -> to_client_media_item(i) end)
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

  @doc """
  Create a new media library entry by uploading the encoded media file to an Amazon S3 storage bucket.
  """
  @doc parameters: [
         project: [
           in: :url,
           schema: %OpenApiSpex.Schema{type: :string},
           required: true,
           description: "The project id"
         ]
       ],
       request_body:
         {"Request body to add a media library item", "application/json",
          OliWeb.MediaController.MediaItemUpload, required: true},
       responses: %{
         200 =>
           {"Media Item Upload Response", "application/json",
            OliWeb.MediaController.MediaItemUploadResponse}
       }
  def create(conn, %{"project" => project_slug, "file" => file, "name" => name}) do
    case Base.decode64(file) do
      {:ok, contents} ->
        case MediaLibrary.add(project_slug, name, contents) do
          {:ok, %MediaItem{} = item} -> json(conn, %{type: "success", url: item.url})
          {:error, error} -> error(conn, 400, error)
        end

      :error ->
        error(conn, 400, "invalid encoded file")
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
      {:file_exists} ->
        "That file already exists in storage. A file can only be uploaded once."

      {:persistence} ->
        "The file could not be saved in storage. Hopefully, this is a temporary problem, so give it another try, but let us know if it continues to fail."

      {:not_found} ->
        "The project you are trying to upload to could not be found."

      %Ecto.Changeset{} = _changeset ->
        "It looks like something is wrong with that file's metadata. Make sure the image is correct, and if you're still having issues let us know."

      _ ->
        "Something unexpected prevented that file from being uploaded. Try another file or reach out to us for support."
    end
  end
end
