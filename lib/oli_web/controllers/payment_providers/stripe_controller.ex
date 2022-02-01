defmodule OliWeb.PaymentProviders.StripeController do
  use OliWeb, :controller

  import Oli.Utils
  import OliWeb.Api.Helpers

  alias Oli.Delivery.{Paywall, Sections}
  alias Oli.Delivery.Paywall.Providers.Stripe
  alias OliWeb.Router.Helpers, as: Routes

  require Logger

  @doc """
  Renders the page to start the direct payment processing flow via stripe.
  """
  def show(conn, section, user, %{amount: decimal} = amount) do
    Logger.debug("StripeController:show", %{
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
    |> Phoenix.Controller.put_view(OliWeb.PaymentProviders.StripeView)
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
  def success(conn, %{"intent" => intent}) do
    # get payment, stamp it as having been finalized
    Logger.debug("StripeController:success started", %{
      intent_id: intent["id"]
    })

    case Stripe.finalize_payment(intent) do
      {:ok, %{slug: slug}} ->
        Logger.debug("StripeController:success ended", %{
          intent_id: intent["id"],
          section_slug: slug
        })

        json(conn, %{
          result: "success",
          url: Routes.page_delivery_path(conn, :index, slug)
        })

      {:error, reason} when is_binary(reason) ->
        Logger.error("StripeController could not finalize payment: #{reason}")

        json(conn, %{
          result: "failure",
          reason: reason
        })

      e ->
        {_, msg} = Oli.Utils.log_error("Could not finalize stripe payment", e)

        json(conn, %{
          result: "failure",
          reason: msg
        })
    end
  end

  @doc """
  JSON endpoint that allows client-side reporting of payment processing success.
  """
  def failure(conn, params) do
    Logger.error("StripeController:failure", %{
      params: params
    })

    json(conn, %{result: "success"})
  end

  @doc """
  Handles client-side request to create a payment intent. Returns the intent `clientSecret`
  to the client as a response.
  """
  def init_intent(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user

    Logger.debug("StripeController:init_intent begin", %{
      section_slug: section_slug,
      user_id: user.id
    })

    if Sections.is_enrolled?(user.id, section_slug) do
      # Lookup the section, determine the product, and determine the cost. For security
      # reasons, we *always* calculate cost on the server instead of allowing the client
      # to pass the cost along to the server.
      with {:ok, section} <- Sections.get_section_by_slug(section_slug) |> trap_nil(),
           {:ok, section} <- Oli.Repo.preload(section, [:institution, :blueprint]) |> trap_nil(),
           {:ok, product} <- determine_product(section),
           {:ok, amount} <- Paywall.calculate_product_cost(product, section.institution) do
        # Now ask Stripe to create a payment intent, which also results in a %Payment record
        # created in the system but in a "pending" state
        case Stripe.create_intent(amount, user, section, product) do
          {:ok, %{"client_secret" => client_secret, "id" => id}} ->
            Logger.debug("StripeController:init_intent ended", %{
              intent_id: id,
              section_slug: section_slug,
              user_id: user.id
            })

            json(conn, %{clientSecret: client_secret})

          e ->
            {_, msg} = Oli.Utils.log_error("StripeController:init_intent failed.", e)
            error(conn, 500, msg)
        end
      else
        e ->
          Logger.error("StripeController could not init intent", e)
          error(conn, 400, "client error")
      end
    else
      Logger.error(
        "StripeController caught attempt to initialize payment for non-enrolled student"
      )

      error(conn, 401, "unauthorized, this user is not enrolled in this section")
    end
  end

  # Determines the product to apply a payment to.  If a section was not created
  # from a product, the product is the section itself.
  defp determine_product(section) do
    if is_nil(section.blueprint_id) do
      {:ok, section}
    else
      {:ok, section.blueprint}
    end
  end
end
