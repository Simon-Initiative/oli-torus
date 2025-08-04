defmodule OliWeb.Api.ProductController do
  @moduledoc """
  Endpoint for payment code bulk request.
  """
  use OliWeb, :controller
  use OpenApiSpex.Controller

  alias Oli.Delivery.Sections
  alias OpenApiSpex.Schema

  plug Oli.Plugs.ValidateProductApiKey

  action_fallback OliWeb.FallbackController

  @moduledoc tags: ["Paywall Interop"]

  defmodule ProductListingResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Product listing reponse",
      description: "A collection of products available in the system",
      type: :object,
      properties: %{
        products: %Schema{
          type: :list,
          description: "List of the products and their details"
        },
        result: %Schema{type: :string, description: "success"}
      },
      required: [:products, :result],
      example: %{
        "result" => "success",
        "products" => [
          %{
            "slug" => "my_first_product",
            "title" => "Introduction to World Cultures",
            "description" => "World Cultures is a great....",
            "status" => "active",
            "requires_payment" => true,
            "pay_by_institution" => false,
            "amount" => Money.new(100, "USD"),
            "has_grace_period" => true,
            "grace_period_days" => 10,
            "grace_period_strategy" => "relative_to_student",
            "publisher_id" => 10,
            "cover_image" => "https://www.someurl.com/some-image.png"
          }
        ]
      }
    })
  end

  @doc """
  Access the list of available products.
  """
  @doc parameters: [],
       security: [%{"bearer-authorization" => []}],
       responses: %{
         200 =>
           {"Product Listing Response", "application/json",
            OliWeb.Api.ProductController.ProductListingResponse}
       }
  def index(conn, _params) do
    products = Sections.list_blueprint_sections()
    render(conn, "index.json", products: products)
  end
end
