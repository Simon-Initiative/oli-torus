defmodule OliWeb.Api.ProductController do
  @moduledoc """
  Endpoint for payment code bulk request.
  """

  alias OpenApiSpex.Schema

  alias Oli.Delivery.Sections
  import OliWeb.Api.Helpers

  use OliWeb, :controller
  use OpenApiSpex.Controller

  plug :valid_product_api_key

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
            "amount" => "$100.00",
            "has_grace_period" => true,
            "grace_period_days" => 10,
            "grace_period_strategy" => "relative_to_student"
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

  defp valid_product_api_key(conn, _options) do
    if is_valid_api_key?(conn, &Oli.Interop.validate_for_products/1) do
      conn
    else
      error(conn, 401, "Unauthorized")
    end
  end
end
