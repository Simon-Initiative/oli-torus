defmodule OliWeb.Api.ProductController do
  @moduledoc """
  Endpoint for payment code bulk request.
  """

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  import OliWeb.Api.Helpers

  use OliWeb, :controller

  def index(conn, _) do
    if is_valid_api_key?(conn, &Oli.Interop.validate_for_products/1) do
      case Sections.list_blueprint_sections() do
        nil ->
          error(conn, 500, "server error")

        products ->
          case serialize_products(products) do
            {:ok, serialized} -> json(conn, %{"result" => "success", "products" => serialized})
            _ -> error(conn, 500, "Server error serializing products")
          end
      end
    else
      error(conn, 401, "Unauthorized")
    end
  end

  defp serialize_products(blueprints) when is_list(blueprints) do
    Enum.reverse(blueprints)
    |> Enum.reduce_while({:ok, []}, fn p, {:ok, all} ->
      case serialize_product(p) do
        {:ok, serialized} -> {:cont, {:ok, [serialized | all]}}
        e -> {:halt, e}
      end
    end)
  end

  defp serialize_product(%Section{} = blueprint) do
    case blueprint.amount |> Money.to_string() do
      {:ok, a} ->
        {:ok,
         %{
           slug: blueprint.slug,
           title: blueprint.title,
           status: blueprint.status,
           requires_payment: blueprint.requires_payment,
           amount: a,
           has_grace_period: blueprint.has_grace_period,
           grace_period_days: blueprint.grace_period_days,
           grace_period_strategy: blueprint.grace_period_strategy
         }}

      e ->
        e
    end
  end
end
