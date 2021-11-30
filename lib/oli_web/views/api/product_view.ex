defmodule OliWeb.Api.ProductView do
  use OliWeb, :view
  alias OliWeb.Api.ProductView

  def render("index.json", %{products: products}) do
    %{
      result: "success",
      products: render_many(products, ProductView, "product.json")
    }
  end

  def render("show.json", %{product: product}) do
    %{product: render_one(product, ProductView, "product.json")}
  end

  def render("product.json", %{product: product}) do
    %{
      slug: product.slug,
      description: product.description,
      title: product.title,
      status: product.status,
      requires_payment: product.requires_payment,
      amount: amount(product.requires_payment, product.amount),
      has_grace_period: product.has_grace_period,
      grace_period_days: product.grace_period_days,
      grace_period_strategy: product.grace_period_strategy
    }
  end

  defp amount(false, _amount), do: nil
  defp amount(true, amount), do: Money.to_string!(amount)
end
