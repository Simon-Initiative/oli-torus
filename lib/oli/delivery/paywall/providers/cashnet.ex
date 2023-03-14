defmodule Oli.Delivery.Paywall.Providers.Cashnet do
  require Logger

  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Section
  alias OliWeb.Router.Helpers, as: Routes

  @spec create_form(%Section{}, %User{}, String.t()) :: {:ok, any} | {:error, any}
  def create_form(section, user, host) do

    attrs = %{
      type: :direct,
      generation_date: DateTime.utc_now(),
      amount: section.amount,
      provider_type: :cashnet,
      provider_id: UUID.uuid4(),
      section_id: section.id
    }

    with {:ok,
          [
            {:cashnet_store, cashnet_store},
            {:cashnet_checkout_url, cashnet_checkout_url},
            {:cashnet_client, cashnet_client},
            {:cashnet_gl_number, cashnet_gl_number}
          ]} <-
           Application.fetch_env(:oli, :cashnet_provider),
         {:ok, payment} <- Oli.Delivery.Paywall.create_pending_payment(user, section, attrs) do
      {:ok,
       %{
         payment_ref: payment.provider_id,
         cashnet_form:
           ~s|<form action="#{cashnet_checkout_url}" id="cmupayment" name="cashnet" method="post" target="_blank">
           <input type="hidden" name="virtual" value="#{cashnet_client}#{cashnet_store}"/>
           <input type="hidden" name="signouturl" value="https://#{host}#{Routes.page_delivery_path(OliWeb.Endpoint, :index, section.slug)}"/>
           <input type="hidden" name="ref1type1" value="#{cashnet_store}-payment_ref"/>
           <input type="hidden" name="ref1val1" value="#{payment.provider_id}"/>

           <input type="hidden" name="fname" value="#{safe_get(user.given_name, "Unknown")}"/>
           <input type="hidden" name="lname" value="#{safe_get(user.family_name, "Unknown")}"/>
           <input type="hidden" name="email" value="#{user.email}"/>
           <input type="hidden" name="ref2type1" value="#{cashnet_store}-course_slug"/>
           <input type="hidden" name="ref2val1" value="#{section.slug}"/>

           <input type="hidden" name="ref3type1" value="#{cashnet_store}-fname"/>
           <input type="hidden" name="ref3val1" value="#{safe_get(user.given_name, "Unknown")}"/>
           <input type="hidden" name="ref4type1" value="#{cashnet_store}-lname"/>
           <input type="hidden" name="ref4val1" value="#{safe_get(user.family_name, "Unknown")}"/>
           <input type="hidden" name="ref5type1" value="#{cashnet_store}-email"/>
           <input type="hidden" name="ref5val1" value="#{safe_get(user.email, Application.get_env(:oli, :email_reply_to))}"/>
           <input type="hidden" name="ref6type1" value="#{cashnet_store}-title"/>
           <input type="hidden" name="ref6val1" value="#{section.title}"/>

           <input type="hidden" name="itemcode1" value="#{cashnet_store}-COURSE"/>
           <input type="hidden" name="desc1" value="Title: #{section.title} Slug: #{section.slug}"/>
           <input type="hidden" name="qty1" value="1"/>
           <input type="hidden" name="amount1" value="#{section.amount.amount}"/>
           <input type="hidden" name="gl1" value="#{cashnet_gl_number}"/>
        </form>|
       }}
    else
      error ->
        error
    end
  end

  @doc """
  Finalize a pending payment, given the Cashnet payload.

  Finalization first involves ensuring that the payload corresponds to a payment
  in the system that has not yet been applied.  It then applies that
  payment be setting the application date and by linking it to an enrollment.
  """
  def finalize_payment(%{"ref1val1" => provider_id} = payload) do
    case Oli.Delivery.Paywall.get_provider_payment(:cashnet, provider_id) do
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
                   provider_payload: payload
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
