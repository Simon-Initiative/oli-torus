defmodule OliWeb.PaymentProviders.CashnetController do
  use OliWeb, :controller
  use OliWeb, :verified_routes

  import Oli.Utils
  import OliWeb.Api.Helpers

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Paywall.Providers.Cashnet
  alias Phoenix.PubSub

  require Logger

  @doc """
  Renders the page to start the direct payment processing flow via cashnet.
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

    if Sections.is_enrolled?(user.id, section.slug) do
      # Now ask Cashnet to create a payment form, which also results in a %Payment record
      # created in the system but in a "pending" state
      case Cashnet.create_form(section, user, conn.host) do
        {:ok, %{payment_ref: _payment_ref, cashnet_form: cashnet_form}} ->
          # This is necessary since this controller has been delegated by PaymentController
          Phoenix.Controller.put_view(conn, OliWeb.PaymentProviders.CashnetView)
          |> render("index.html",
            api_key: Application.fetch_env!(:oli, :stripe_provider)[:public_secret],
            purchase: Jason.encode!(%{user_id: user.id, section_slug: section.slug}),
            section: section,
            cost: cost,
            cashnet_form: cashnet_form,
            user: user,
            user_name:
              safe_get(user.family_name, "Unknown") <>
                ", " <> safe_get(user.given_name, "Unknown")
          )

        e ->
          {_, msg} = Oli.Utils.log_error("CashnetController:show failed.", e)
          error(conn, 500, msg)
      end
    else
      Logger.error(
        "CashnetController caught attempt to initialize payment for non-enrolled student"
      )

      render(conn, "not_enrolled.html", section_slug: section.slug)
    end
  end

  defp safe_get(item, default_value) do
    case item do
      nil -> default_value
      item -> item
    end
  end

  @doc """
  An endpoint that allows the cashnet system reporting of payment processing success.
  """
  def success(conn, %{"lname" => lname, "result" => result, "ref1val1" => payment_id} = payload) do
    # get payment, stamp it as having been finalized
    Logger.debug("CashnetController:success started", payload)

    if lname == System.get_env("CASHNET_NAME", "none") && result == "0" do
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
          Logger.error(
            "CashnetController could not finalize Cashnet payment: #{reason}: Payment Id: #{payment_id}"
          )

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
      Logger.error("CashnetController caught attempt to initialize payment from untrusted source")

      error(conn, 401, "unauthorized, payment origin is from untrusted source")
    end
  end

  @doc """
  An endpoint that allows the cashnet system reporting of payment processing failure.
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
  An endpoint where cashnet can redirect users if they sign off or cancel the payment process.
  """
  def signoff(conn, %{"ref1val1" => provider_id} = payload) do
    Logger.debug("CashnetController:signoff ", payload)

    user = conn.assigns.current_user

    if user == nil do
      payment = Oli.Delivery.Paywall.get_provider_payment(:cashnet, provider_id)

      if payment != nil do
        PubSub.broadcast(
          Oli.PubSub,
          "section:payment:" <> Integer.to_string(payment.pending_user_id),
          {:payment, "logged off"}
        )
      end

      render_back_to_lms(conn)
    else
      PubSub.broadcast(
        Oli.PubSub,
        "section:payment:" <> Integer.to_string(user.id),
        {:payment, "logged off without paying"}
      )

      if user.independent_learner do
        redirect(conn, to: ~p"/workspaces/student")
      else
        redirect(conn, to: Routes.delivery_path(conn, :index))
      end
    end
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
      # Lookup the section, determine the product, and determine the cost.
      case Sections.get_section_by_slug(section_slug) |> trap_nil() do
        {:ok, section} ->
          # Now ask Cashnet to create a payment form, which also results in a %Payment record
          # created in the system but in a "pending" state
          case Cashnet.create_form(section, user, conn.host) do
            {:ok, %{payment_ref: payment_ref, cashnet_form: cashnet_form}} ->
              json(conn, %{paymentRef: payment_ref, cashnetForm: cashnet_form})

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

  defp render_back_to_lms(conn) do
    conn
    |> put_view(OliWeb.PaymentProviders.CashnetView)
    |> put_root_layout({OliWeb.LayoutView, "delivery_from_payment.html"})
    |> put_status(200)
    |> render("lms_from_payment_site.html")
    |> halt()
  end
end
