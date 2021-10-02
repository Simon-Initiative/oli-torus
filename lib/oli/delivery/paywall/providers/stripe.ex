defmodule Oli.Delivery.Paywall.Providers.Stripe do
  @zero_decimal_currencies ~w"bif clp djf gnf jpy kmf krw mga pyg rwf ugx vnd vuv xaf xof xpf"
  @zero_decimal_currencies_set MapSet.new(@zero_decimal_currencies)

  @doc """
  Converts an ex_money amount to a valid Stripe value and
  currency code. Returns a two element tuple {value, currency code}.

  Stripe reference on currencies: https://stripe.com/docs/currencies

  This impl supports zero-decimal currencies.
  """
  def convert_amount(%Money{amount: amount, currency: currency}) do
    code =
      case currency do
        c when is_atom(c) -> Atom.to_string(c) |> String.downcase()
        s when is_binary(s) -> String.downcase(s)
      end

    factor =
      case MapSet.member?(@zero_decimal_currencies_set, code) do
        true -> 1
        false -> 100
      end

    int_value =
      Decimal.mult(amount, factor)
      |> Decimal.round()
      |> Decimal.to_integer()

    {int_value, code}
  end
end
