defmodule OliWeb.PaymentProviders.CashnetController do
  use OliWeb, :controller

  import Oli.Utils
  import OliWeb.Api.Helpers

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Paywall.Providers.Cashnet

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
  def success(conn, %{"lname" => lname, "result" => result, "ref1val1" => payment_id} = payload) do
    # get payment, stamp it as having been finalized
    Logger.debug("CashnetController:success started", payload)

    Logger.error("CashnetController could not finalize payment")

    if lname == System.get_env("CASHNET_NAME", "none") && result == "0" do
      IO.inspect("the issue is the found here")
      case Cashnet.finalize_payment(payload) do
        {:ok, %{slug: slug}} ->
          Logger.debug("CashnetController:success ended", %{
            payment_id: payload["ref1val1"],
            section_slug: slug
          })

          json(conn, %{
            result: "success"
          })

        {:error, reason} when is_binary(reason) ->
          Logger.error("CashnetController could not finalize Cashnet payment: #{reason}: Payment Id: #{payment_id}")

          json(conn, %{
            result: "failure"
          })

        e ->
          {_, _msg} = Oli.Utils.log_error("Could not finalize Cashnet payment", e)

          json(conn, %{
            result: "failure"
          })
      end
    else
      Logger.error(
        "CashnetController caught attempt to initialize payment from untrusted source"
      )

      error(conn, 401, "unauthorized, payment origin is from untrusted source")
    end
  end

   @doc """
  JSON endpoint that allows client-side reporting of payment processing success.
  """
  def failure(conn, payload) do
    # get payment, stamp it as having been finalized
    Logger.debug("CashnetController:failure ", payload)

    Oli.Utils.log_error("Could not finalize Cashnet payment", payload)

    json(conn, %{
      result: "failure"
    })

  end

  @doc """
  Handles client-side request to create a cashnet payment form.
  """
  def init_form(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user

    Logger.debug("CashnetController:init_form begin", %{
      section_slug: section_slug,
      user_id: user.id
    })

    if Sections.is_enrolled?(user.id, section_slug) do
      # Lookup the section, determine the product, and determine the cost. For security
      # reasons, we *always* calculate cost on the server instead of allowing the client
      # to pass the cost along to the server.
      case Sections.get_section_by_slug(section_slug) |> trap_nil() do
        {:ok, section} ->
          # Now ask Cashnet to create a payment form, which also results in a %Payment record
          # created in the system but in a "pending" state
          case Cashnet.create_form(section, user, conn.host) do
            {:ok, %{cashnet_form: cashnet_form}} ->

              json(conn, %{cashnetForm: cashnet_form})

            e ->
              {_, msg} = Oli.Utils.log_error("CashnetController:init_form failed.", e)
              error(conn, 500, msg)
          end

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
