defmodule Oli.Scenarios.Directives.InstitutionDiscountHandler do
  @moduledoc """
  Handles institution discount directives for products.
  """

  alias Oli.Delivery.Paywall
  alias Oli.Scenarios.DirectiveTypes.InstitutionDiscountDirective
  alias Oli.Scenarios.Engine

  def handle(
        %InstitutionDiscountDirective{
          institution: institution_name,
          product: product_name,
          type: type,
          percentage: percentage,
          amount: amount,
          bypass_paywall: bypass_paywall
        },
        state
      ) do
    case {Engine.get_institution(state, institution_name),
          Engine.get_product(state, product_name)} do
      {nil, _} ->
        {:error, "Institution '#{institution_name}' not found"}

      {_, nil} ->
        {:error, "Product '#{product_name}' not found"}

      {institution, product} ->
        case Paywall.create_or_update_discount(%{
               institution_id: institution.id,
               section_id: product.id,
               type: type,
               percentage: percentage,
               amount: build_money(amount),
               bypass_paywall: bypass_paywall
             }) do
          {:ok, _discount} ->
            {:ok, state}

          {:error, reason} ->
            {:error, "Failed to create institution discount: #{inspect(reason)}"}
        end
    end
  end

  defp build_money(nil), do: nil
  defp build_money(%{"amount" => amount, "currency" => currency}), do: Money.new(amount, currency)
end
