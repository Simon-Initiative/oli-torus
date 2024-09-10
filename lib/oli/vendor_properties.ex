defmodule Oli.VendorProperties do
  @moduledoc """
  A collection of properties that vary depending on the vendor hosting the instance.
  """

  def workspace_logo(), do: Application.fetch_env!(:oli, :vendor_property)[:workspace_logo]

  def product_full_name(),
    do: Application.fetch_env!(:oli, :vendor_property)[:product_full_name]

  def product_short_name(),
    do: Application.fetch_env!(:oli, :vendor_property)[:product_short_name]

  def product_description(),
    do: Application.fetch_env!(:oli, :vendor_property)[:product_description]

  def product_learn_more_link(),
    do: Application.fetch_env!(:oli, :vendor_property)[:product_learn_more_link]

  def company_name(), do: Application.fetch_env!(:oli, :vendor_property)[:company_name]
  def company_address(), do: Application.fetch_env!(:oli, :vendor_property)[:company_address]

  def company_faq_url(), do: Application.fetch_env!(:oli, :vendor_property)[:faq_url]

  def normalized_workspace_logo(host) do
    case workspace_logo() do
      "https://" <> rest -> "https://#{rest}"
      local_file -> "https://#{host}#{local_file}"
    end
  end
end
