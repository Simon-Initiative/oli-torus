defmodule OliWeb.Api.PaymentController do
  @moduledoc """
  Endpoint for payment code bulk request.
  """

  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Paywall.Payment
  import OliWeb.Api.Helpers

  use OliWeb, :controller

  def new(conn, %{"product_slug" => product_slug, "batch_size" => batch_size}) do
    if is_valid_api_key?(conn, &Oli.Interop.validate_for_payments/1) do
      case Paywall.create_payment_codes(product_slug, batch_size) do
        {:ok, payments} ->
          json(conn, %{"result" => "success", "codes" => serialize_payment(payments)})

        {:error, {:invalid_product}} ->
          error(conn, 404, "product not found")

        {:error, {:invalid_batch_size}} ->
          error(conn, 400, "invalid batch size")

        _ ->
          error(conn, 500, "server error")
      end
    else
      error(conn, 401, "Unauthorized")
    end
  end

  defp serialize_payment(payments) when is_list(payments) do
    Enum.map(payments, fn p -> serialize_payment(p) end)
  end

  defp serialize_payment(%Payment{} = payment) do
    %{
      code: Payment.to_human_readable(payment.code)
    }
  end
end
