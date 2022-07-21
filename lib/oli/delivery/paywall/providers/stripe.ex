defmodule Oli.Delivery.Paywall.Providers.Stripe do
  import Oli.HTTP

  require Logger

  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Section

  @zero_decimal_currencies ~w"bif clp djf gnf jpy kmf krw mga pyg rwf ugx vnd vuv xaf xof xpf"
  @zero_decimal_currencies_set MapSet.new(@zero_decimal_currencies)
  @payment_intents_url "https://api.stripe.com/v1/payment_intents"

  @doc """
  Converts an ex_money amount to a valid Stripe value and
  currency code. Returns a two element tuple {value, currency code}.

  "Valid" Stripe values do not contain decimal points. They are integer based
  representations of the amount. As an example, consider the US dollar
  amount of $79.99. Stripe expects that value to be expressed as the integer
  7999

  This impl supports zero-decimal currencies as well. Consult the Stripe reference
  on currencies for more information: https://stripe.com/docs/currencies
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

  @doc """
  Creates a Stripe payment intent for an amount to pay by a user for enrollment
  in a section for a particular section.

  After successful intent creation, this function creates a "pending" payment within Torus.
  This is done primarily as a safeguard measure, since it allows verfication later
  during `finalize_payment` to ensure a finalize request pertains actually to an intent
  launched by the system. If we did not do this, the only alternative to ensure that a finalization
  attempt is real is to call out to the Stripe API to verify the intent. This approach avoids
  that network call.
  """
  @spec create_intent(%Section{}, %User{}) :: {:ok, any} | {:error, any}
  def create_intent(section, user) do
    {stripe_value, stripe_currency} = convert_amount(section.amount)

    # if the user has an email address, we include it so Stipe will send receipt
    receipt_email = if user.email, do: %{receipt_email: user.email}, else: %{}

    body =
      Map.merge(
        %{
          amount: stripe_value,
          currency: stripe_currency,
          "payment_method_types[]": "card"
        },
        receipt_email
      )
      |> URI.encode_query()

    headers = fn private_secret ->
      [
        Authorization: "Bearer #{private_secret}",
        "Content-Type": "application/x-www-form-urlencoded"
      ]
    end

    attrs = fn intent ->
      %{
        type: :direct,
        generation_date: DateTime.utc_now(),
        amount: section.amount,
        provider_payload: intent,
        provider_id: intent["id"],
        provider_type: :stripe,
        section_id: section.id
      }
    end

    with {:ok, [_, {:private_secret, private_secret}]} <-
           Application.fetch_env(:oli, :stripe_provider),
         {:ok, %{status_code: 200, body: body}} <-
           http().post(
             @payment_intents_url,
             body,
             headers.(private_secret)
           ),
         {:ok, intent} <- Poison.decode(body),
         {:ok, _} <- Oli.Delivery.Paywall.create_pending_payment(user, section, attrs.(intent)) do
      {:ok, intent}
    else
      {:ok, %HTTPoison.Response{} = response} ->
        Logger.error("Failed request to Stripe payment intents, response: #{inspect(response)}")
        {:error, "Could not create stripe intent"}

      error ->
        error
    end
  end

  @doc """
  Finalize a pending payment, given the Stripe intent.

  Finalization first involves ensuring that the intent corresponds to a payment
  in the system that has not yet been applied.  It then applies that
  payment be setting the application date and by linking it to an enrollment.
  """
  def finalize_payment(%{"id" => id} = intent) do
    case Oli.Delivery.Paywall.get_provider_payment(:stripe, id) do
      nil ->
        {:error, "Payment does not exist"}

      %{application_date: nil} = payment ->
        section = Oli.Delivery.Sections.get_section!(payment.pending_section_id)

        case Oli.Delivery.Sections.get_enrollment(section.slug, payment.pending_user_id) do
          nil ->
            {:error, "Count not find enrollment to finalize payment"}

          enrollment ->
            case Oli.Delivery.Paywall.update_payment(payment, %{
                   enrollment_id: enrollment.id,
                   application_date: DateTime.utc_now(),
                   provider_payload: intent
                 }) do
              {:ok, _} -> {:ok, section}
              _ -> {:error, "Could not finalize payment"}
            end
        end

      _ ->
        {:error, "Payment already finalized"}
    end
  end
end
