defmodule OliWeb.PaymentProviders.CashnetController do
  use OliWeb, :controller

  import Oli.Utils
  import OliWeb.Api.Helpers

  alias Oli.Delivery.Sections
  # alias Oli.Delivery.Paywall.Providers.Stripe
  alias OliWeb.Router.Helpers, as: Routes

  require Logger

  @doc """
  Renders the page to start the direct payment processing flow via stripe.
  """
  def show(conn, section, user, %{amount: decimal} = amount) do
    Logger.debug("CashnetController:show", %{
      section_slug: section.slug,
      user_id: user.id,
      amount: amount
    })

    cost =
      case Money.to_string(amount) do
        {:ok, v} -> v
        _ -> Decimal.to_string(decimal)
      end

    conn
    # This is necessary since this controller has been delegated by PaymentController
    |> Phoenix.Controller.put_view(OliWeb.PaymentProviders.CashnetView)
    |> render("index.html",
      api_key: Application.fetch_env!(:oli, :stripe_provider)[:public_secret],
      purchase: Jason.encode!(%{user_id: user.id, section_slug: section.slug}),
      section: section,
      cost: cost,
      user_name:
        safe_get(user.family_name, "Unknown") <> ", " <> safe_get(user.given_name, "Unknown")
    )
  end

  defp safe_get(item, default_value) do
    case item do
      nil -> default_value
      item -> item
    end
  end

  @doc """
  JSON endpoint that allows client-side reporting of payment processing success.
  """
  def callback(conn, payload) do
    # get payment, stamp it as having been finalized
    Logger.debug("CashnetController:success started", payload)

    Logger.error("CashnetController could not finalize payment")

    json(conn, %{
      result: "failure",
      reason: "testing"
    })

    # case Stripe.finalize_payment(intent) do
    #   {:ok, %{slug: slug}} ->
    #     Logger.debug("StripeController:success ended", %{
    #       intent_id: intent["id"],
    #       section_slug: slug
    #     })

    #     json(conn, %{
    #       result: "success",
    #       url: Routes.page_delivery_path(conn, :index, slug)
    #     })

    #   {:error, reason} when is_binary(reason) ->
    #     Logger.error("StripeController could not finalize payment: #{reason}")

    #     json(conn, %{
    #       result: "failure",
    #       reason: reason
    #     })

    #   e ->
    #     {_, msg} = Oli.Utils.log_error("Could not finalize stripe payment", e)

    #     json(conn, %{
    #       result: "failure",
    #       reason: msg
    #     })
    # end
  end

  @doc """
  Handles client-side request to create a payment intent. Returns the intent `clientSecret`
  to the client as a response.
  """
  def init_form(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user

    Logger.debug("CashnetController:init_intent begin", %{
      section_slug: section_slug,
      user_id: user.id
    })

    if Sections.is_enrolled?(user.id, section_slug) do
      # Lookup the section, determine the product, and determine the cost. For security
      # reasons, we *always* calculate cost on the server instead of allowing the client
      # to pass the cost along to the server.
      case Sections.get_section_by_slug(section_slug) |> trap_nil() do
        {:ok, section} ->
          json(conn, %{cashnetForm: "form data", section: section.id})
          # Now ask Stripe to create a payment intent, which also results in a %Payment record
          # created in the system but in a "pending" state
          # case Stripe.create_intent(section, user) do
          #   {:ok, %{"client_secret" => client_secret, "id" => id}} ->
          #     Logger.debug("StripeController:init_intent ended", %{
          #       intent_id: id,
          #       section_slug: section_slug,
          #       user_id: user.id
          #     })

          #     json(conn, %{clientSecret: client_secret})

          #   e ->
          #     {_, msg} = Oli.Utils.log_error("StripeController:init_intent failed.", e)
          #     error(conn, 500, msg)
          # end

        _ ->
          Logger.error("CashnetController could not init intent")
          error(conn, 400, "client error")
      end
    else
      Logger.error(
        "CashnetController caught attempt to initialize payment for non-enrolled student"
      )

      error(conn, 401, "unauthorized, this user is not enrolled in this section")
    end
  end
end
