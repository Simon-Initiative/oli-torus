defmodule OliWeb.Api.MediaController do
  @moduledoc tags: ["Media Library Service"]

  @moduledoc """
  The media library service allows operations on a project by project
  basis to create (upload) and access media items.
  """

  @image_size {224, 224}
  @mean [0.485, 0.456, 0.406]
  @std [0.229, 0.224, 0.225]


  alias OpenApiSpex.Schema

  alias Oli.Authoring.MediaLibrary.{MediaItem, ItemOptions}
  alias Oli.Authoring.MediaLibrary
  import OliWeb.ProjectPlugs

  use OliWeb, :controller
  use OpenApiSpex.Controller

  plug(:fetch_project when action not in [:index, :create, :delete])

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

  defmodule MediaItemsDelete do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Media Items Delete",
      description: "Deleted media items",
      type: :object,
      properties: %{
        mediaItemIds: %Schema{type: :list, description: "The media items ids"}
      },
      required: [:mediaItemIds],
      example: %{
        "mediaItemIds" => [1, 2, 3]
      }
    })
  end

  defmodule MediaItemsDeleteResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Media Items Delete Response",
      description: "Deleted media items response",
      type: :object,
      properties: %{
        type: %Schema{type: :string, description: "Success"},
        count: %Schema{type: :integer, description: "Count of media deleted"}
      },
      required: [:result],
      example: %{
        "result" => "success"
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
        url: %Schema{type: :string, description: "The URL of the item in the media library"},
        duplicate: %Schema{type: :boolean, description: "Was this a duplicate file?"},
        filename: %Schema{
          type: :string,
          description: "Name of the file (may differ from requested if there was a duplicate)"
        }
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
           {"Media Item Page", "application/json", OliWeb.Api.MediaController.MediaItemPageSchema}
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
          OliWeb.Api.MediaController.MediaItemUpload, required: true},
       responses: %{
         200 =>
           {"Media Item Upload Response", "application/json",
            OliWeb.Api.MediaController.MediaItemUploadResponse}
       }
  def create(conn, %{"project" => project_slug, "file" => file, "name" => name}) do
    case Base.decode64(file) do
      {:ok, contents} ->
        case MediaLibrary.add(project_slug, name, contents) do
          {:ok, %MediaItem{} = item} ->

            accessibility = perform_accessibility_check(contents)

            json(conn, %{type: "success", accessibility: accessibility, url: item.url, duplicate: false, filename: name})

          {:duplicate, %MediaItem{} = item} ->
            json(conn, %{
              type: "success",
              url: item.url,
              duplicate: true,
              filename: item.file_name
            })

          {:error, error} ->
            {_id, err_msg} = Oli.Utils.log_error("failed to add media", error)
            error(conn, 400, err_msg)
        end

      _ ->
        error(conn, 400, "invalid encoded file")
    end
  end

  @doc """
  Mark a list of media items as deleted.
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
         {"Request body to delete a list of media items", "application/json",
          OliWeb.Api.MediaController.MediaItemsDelete, required: true},
       responses: %{
         200 =>
           {"Media Items Delete Response", "application/json",
            OliWeb.Api.MediaController.MediaItemsDeleteResponse}
       }
  def delete(conn, %{"project" => project_slug, "mediaItemIds" => media_item_ids}) do
    case MediaLibrary.delete_media_items(project_slug, media_item_ids) do
      {:ok, count} ->
        json(conn, %{type: "success", count: count})

      {:error, err_msg} ->
        error(conn, 400, err_msg)
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
        "A file with that name already exists. Please rename your file or use the existing file."

      {:persistence} ->
        "The file could not be uploaded. Please try again or contact support."

      {:not_found} ->
        "The project you are trying to upload to could not be found."

      %Ecto.Changeset{} = _changeset ->
        "The file metadata could not be read. Please make sure the file is valid or contact support."

      _ ->
        "An unexpected error has occurred. Please try again or contact support."
    end
  end

  def image_from_content(content) do
    image = Evision.imdecode(content, Evision.Constant.cv_IMREAD_COLOR())
    resized_image = Evision.resize(image, @image_size)

    # Convert the image to Nx tensor and normalize it
    Nx.from_binary(Evision.Mat.to_binary(resized_image), {:u, 8})
    |> Nx.reshape({@image_size |> elem(0), @image_size |> elem(1), 3})
    |> Nx.divide(255.0)  # Scale pixel values from [0, 255] to [0, 1]
    |> normalize_image()
  end

  def normalize_image(image_tensor) do
    mean_tensor = Nx.tensor(@mean, backend: Nx.BinaryBackend)
    std_tensor = Nx.tensor(@std, backend: Nx.BinaryBackend)

    image_tensor
    |> Nx.subtract(mean_tensor)
    |> Nx.divide(std_tensor)
  end

  # Check to see if this file is perhaps a screenshot of source code
  # or a screenshot of a table.  If so, we flag it as an accessiblity issue.
  defp perform_accessibility_check(contents) do

    inputs = %{"pixel_values" => image_from_content(contents) |> Nx.new_axis(0)}

    batch = Nx.Batch.concatenate([inputs])
    result = Nx.Serving.batched_run(ImageClassifier, batch)

    softmax = fn t ->
      exp_tensor = Nx.exp(t)
      sum_exp = Nx.sum(exp_tensor, axes: [-1], keep_axes: true)
      Nx.divide(exp_tensor, sum_exp)
    end

    # Apply softmax to logits
    probabilities = softmax.(result.logits) |> Nx.to_flat_list()

    case Enum.zip(probabilities, Oli.ImageClassifier.labels())
    |> Enum.sort(fn {a, _}, {b, _} -> a > b end)
    |> hd() do
      {_, "other"} -> nil
      {_, "code"} -> "This image appears to be a screenshot of source code. Not good for accessibiilty!"
      {_, "table"} -> "This image appears to be a screenshot of a table. Not good for accessibiilty!."
    end
  end

end
