defmodule OliWeb.Api.PublisherController do
  @moduledoc """
  Endpoint for publishers data request.
  """
  use OliWeb, :controller
  use OpenApiSpex.Controller

  import OliWeb.Api.Helpers

  alias Oli.Inventories
  alias OpenApiSpex.Schema

  plug Oli.Plugs.ValidateProductApiKey

  action_fallback OliWeb.FallbackController

  @moduledoc tags: ["Publishers Service"]

  defmodule PublisherResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Publisher response",
      description: "Publisher attributes",
      type: :object,
      properties: %{
        id: %Schema{type: :integer, description: "Publisher id"},
        name: %Schema{type: :string, description: "Publisher name"},
        email: %Schema{type: :string, description: "Publisher email"},
        address: %Schema{type: :string, description: "Publisher address"},
        main_contact: %Schema{type: :string, description: "Publisher main contact"},
        website_url: %Schema{type: :string, description: "Publisher website url"}
      },
      required: [:id, :name, :email],
      example: %{
        "publisher" => [
          %{
            "id" => 1,
            "name" => "Torus Publisher",
            "email" => "publisher@torus.com",
            "address" => "Torus Address",
            "main_contact" => "Torus Contact",
            "website_url" => "toruspublisher.com"
          }
        ]
      }
    })
  end

  defmodule PublisherListingResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Publisher listing reponse",
      description: "A collection of publishers available in the system",
      type: :object,
      properties: %{
        publishers: %Schema{
          type: :list,
          description: "List of the publishers and their details"
        },
        result: %Schema{type: :string, description: "success"}
      },
      required: [:publishers, :result],
      example: %{
        "result" => "success",
        "publishers" => [
          %{
            "id" => 1,
            "name" => "Torus Publisher",
            "email" => "publisher@torus.com",
            "address" => "Torus Address",
            "main_contact" => "Torus Contact",
            "website_url" => "toruspublisher.com"
          }
        ]
      }
    })
  end

  @doc """
  Access a publisher by id.
  """
  @doc parameters: [
         publisher_id: [
           in: :path,
           description: "The publisher identifier",
           type: :integer,
           required: true,
           example: 1
         ]
       ],
       security: [%{"bearer-authorization" => []}],
       responses: %{
         200 =>
           {"Publisher Response", "application/json",
            OliWeb.Api.PublisherController.PublisherResponse}
       }
  def show(conn, %{"publisher_id" => publisher_id}) do
    case Inventories.get_publisher_by(%{id: publisher_id, available_via_api: true}) do
      nil ->
        error(conn, 404, "Not found")

      publisher ->
        render(conn, "show.json", publisher: publisher)
    end
  end

  @doc """
  Access the list of available publishers.
  """
  @doc parameters: [],
       security: [%{"bearer-authorization" => []}],
       responses: %{
         200 =>
           {"Publisher Listing Response", "application/json",
            OliWeb.Api.PublisherController.PublisherListingResponse}
       }
  def index(conn, _) do
    publishers = Inventories.search_publishers(%{available_via_api: true})
    render(conn, "index.json", publishers: publishers)
  end
end
