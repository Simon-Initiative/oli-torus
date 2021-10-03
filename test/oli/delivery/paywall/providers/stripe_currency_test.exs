defmodule Oli.Delivery.Paywall.Providers.StripeCurrencyTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Paywall.Providers.Stripe

  describe "converts amounts" do
    test "it handles value portions correctly" do
      # Test variations of a regular (decimal having) currency
      assert {10000, _} = Stripe.convert_amount(Money.new(:USD, 100))
      assert {10050, _} = Stripe.convert_amount(Money.new(:USD, "100.50"))
      assert {10055, _} = Stripe.convert_amount(Money.new(:USD, "100.55"))
      assert {10056, _} = Stripe.convert_amount(Money.new(:USD, "100.555"))

      # Test a zero-decimal currency
      assert {100, _} = Stripe.convert_amount(Money.new(:BIF, 100))
    end

    test "it handles code portions correctly" do
      assert {_, "usd"} = Stripe.convert_amount(Money.new(:USD, 100))
      assert {_, "bif"} = Stripe.convert_amount(Money.new(:BIF, 100))
    end
  end
end
