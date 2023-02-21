defmodule Oli.Delivery.Paywall.Providers.Cashnet do
  require Logger

  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Section
  alias OliWeb.Router.Helpers, as: Routes

  @spec create_form(%Section{}, %User{}, String.t()) :: {:ok, any} | {:error, any}
  def create_form(section, user, host) do
    # if the user has an email address, we include it so Stipe will send receipt
    receipt_email = if user.email, do: %{receipt_email: user.email}, else: %{}

    attrs = %{
      type: :direct,
      generation_date: DateTime.utc_now(),
      amount: section.amount,
      provider_type: :cashnet,
      section_id: section.id
    }

    with {:ok,
          [
            {:cashnet_store, cashnet_store},
            {:cashnet_checkout_url, cashnet_checkout_url},
            {:cmu_gl_number, cmu_gl_number}
          ]} <-
           Application.fetch_env(:oli, :cashnet_provider),
         {:ok, payment} <- Oli.Delivery.Paywall.create_pending_payment(user, section, attrs) do
      IO.inspect("cashnet provider staff #{inspect(cashnet_store)} some more text #{inspect(Routes.cashnet_path(OliWeb.Endpoint, :success))}")
      IO.inspect(payment)
      IO.inspect(user)
      IO.inspect(section.title)
      IO.inspect(section.amount)
      {:ok,
       %{
         cashnet_form:
           ~s|<form action="#{cashnet_checkout_url}" id="cmupayment" name="cashnet" method="post" target="_blank">
           <input type="hidden" name="virtual" value="CMU#{cashnet_store}"/>

           <input type="hidden" name="fname" value="#{safe_get(user.given_name, "Unknown")}"/>
           <input type="hidden" name="lname" value="#{safe_get(user.family_name, "Unknown")}"/>

           <input type="hidden" name="itemcode1" value="#{cashnet_store}-COURSE"/>
           <input type="hidden" name="desc1" value="Title: #{section.title} Slug: #{section.slug}"/>
           <input type="hidden" name="qty1" value="1"/>
           <input type="hidden" name="amount1" value="#{section.amount.amount}"/>
           <input type="hidden" name="gl1" value="#{cmu_gl_number}"/>
        </form>|
       }}
    else
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
    case Oli.Delivery.Paywall.get_provider_payment(:cashnet, id) do
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

  defp safe_get(item, default_value) do
    case item do
      nil -> default_value
      item -> item
    end
  end
end
