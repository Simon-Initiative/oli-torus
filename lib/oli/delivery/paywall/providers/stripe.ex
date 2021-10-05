defmodule Oli.Delivery.Paywall.Providers.Stripe do
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Section
  import Oli.HTTP

  @zero_decimal_currencies ~w"bif clp djf gnf jpy kmf krw mga pyg rwf ugx vnd vuv xaf xof xpf"
  @zero_decimal_currencies_set MapSet.new(@zero_decimal_currencies)

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
  in a section for a particular product.

  After successful intent creation, this function creates a "pending" payment within Torus.
  This is done primarily as a safeguard measure, since it allows verfication later
  during `finalize_payment` to ensure a finalize request pertains actually to an intent
  launched by the system. If we did not do this, the only alternative to ensure that a finalization
  attempt is real is to call out to the Stripe API to verify the intent. This approach avoids
  that network call.
  """
  def create_intent(%Money{} = amount, %User{} = user, %Section{} = section, %Section{} = product) do
    {stripe_value, stripe_currency} = convert_amount(amount)

    # if the user has a verified email address, we include it to send
    # a receipt
    with_verified_email =
      if user.email_confirmed_at do
        %{receipt_email: user.email}
      else
        %{}
      end

    body =
      Map.merge(
        %{
          amount: stripe_value,
          currency: stripe_currency,
          "payment_method_types[]": "card"
        },
        with_verified_email
      )
      |> URI.encode_query()

    private_secret = Application.fetch_env!(:oli, :stripe_provider)[:private_secret]

    headers = [
      Authorization: "Bearer #{private_secret}",
      "Content-Type": "application/x-www-form-urlencoded"
    ]

    case http().post(
           "https://api.stripe.com/v1/payment_intents",
           body,
           headers
         ) do
      {:ok, %{status_code: 200, body: body}} ->
        intent = Poison.decode!(body)

        %{"id" => id} = intent

        case Oli.Delivery.Paywall.create_payment(%{
               type: :direct,
               generation_date: DateTime.utc_now(),
               amount: amount,
               pending_user_id: user.id,
               pending_section_id: section.id,
               provider_payload: intent,
               provider_id: id,
               provider_type: :stripe,
               section_id: product.id
             }) do
          {:ok, _} -> {:ok, intent}
          e -> e
        end

      _ ->
        {:error, "Could not create stripe intent"}
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
        enrollment = Oli.Delivery.Sections.get_enrollment(section.slug, payment.pending_user_id)

        case Oli.Delivery.Paywall.update_payment(payment, %{
               enrollment_id: enrollment.id,
               application_date: DateTime.utc_now(),
               provider_payload: intent
             }) do
          {:ok, _} -> {:ok, section}
          _ -> {:error, "Could not finalize payment"}
        end

      _ ->
        {:error, "Payment already finalized"}
    end
  end
end
