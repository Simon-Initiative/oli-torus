defmodule OliWeb.Api.PaymentController do
  @moduledoc """
  Endpoint for payment code bulk request.
  """

  alias OpenApiSpex.Schema

  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Paywall.Payment
  import OliWeb.Api.Helpers

  use OliWeb, :controller
  use OpenApiSpex.Controller

  @moduledoc tags: ["Paywall Interop"]

  defmodule BatchPaymentCodeRequest do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Payment code batch request",
      description: "The request body to create a batch of payment codes",
      type: :object,
      properties: %{
        product_slug: %Schema{
          type: :string,
          description: "Product identifier to create codes against"
        },
        batch_size: %Schema{
          type: :integer,
          description: "The number of codes to create, from 1 to 500"
        }
      },
      required: [:product_slug, :batch_size],
      example: %{
        "product_slug" => "intro_biology_cmu",
        "batch_size" => 50
      }
    })
  end

  defmodule PaymentCodeBatch do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Batch Payment Code Creation Response",
      description: "A collection of payment codes",
      type: :object,
      properties: %{
        codes: %Schema{
          type: :list,
          description: "List of the generated payment codes, as strings"
        },
        result: %Schema{type: :string, description: "success"}
      },
      required: [:codes, :result],
      example: %{
        "result" => "success",
        "codes" => [
          "XKT-3RTH",
          "4DM-99NM",
          "1S3-WKRP",
          "59V-WRTP",
          "HM7-N34P"
        ]
      }
    })
  end

  @doc """
  Create a batch of payment codes for a specific product.
  """
  @doc parameters: [],
       security: [%{"bearer-authorization" => []}],
       request_body:
         {"Request body for making a payment code batch request", "application/json",
          OliWeb.Api.PaymentController.BatchPaymentCodeRequest, required: true},
       responses: %{
         200 =>
           {"Payment code batch", "application/json",
            OliWeb.Api.PaymentController.PaymentCodeBatch}
       }
  def new(conn, %{"product_slug" => product_slug, "batch_size" => batch_size}) do
    if is_valid_api_key?(conn, &Oli.Interop.validate_for_payments/1) do
      case Paywall.create_payment_codes(product_slug, batch_size) do
        {:ok, payments} ->
          json(conn, %{"result" => "success", "codes" => serialize_payment(payments)})

        {:error, {:invalid_product}} ->
          error(conn, 404, "product not found")

        {:error, {:invalid_batch_size}} ->
          error(conn, 400, "invalid batch size")

        e ->
          {_, msg} = Oli.Utils.log_error("Could not create payment code batch", e)
          error(conn, 500, msg)
      end
    else
      error(conn, 401, "Unauthorized")
    end
  end

  defp serialize_payment(payments) when is_list(payments) do
    Enum.map(payments, fn p -> serialize_payment(p) end)
  end

  defp serialize_payment(%Payment{} = payment) do
    Payment.to_human_readable(payment.code)
  end
end
