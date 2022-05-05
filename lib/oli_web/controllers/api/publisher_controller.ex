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
    case Inventories.get_publisher(publisher_id) do
      nil ->
        error(conn, 404, "Not found")

      publisher ->
        render(conn, "show.json", publisher: publisher)
    end
  end
end
