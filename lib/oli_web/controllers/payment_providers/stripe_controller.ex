defmodule OliWeb.PaymentProviders.StripeController do
  use OliWeb, :controller
  import OliWeb.Api.Helpers
  alias OliWeb.Router.Helpers, as: Routes

  @doc """
  Render the page to show a student that they do not have access because
  of the paywall state.  This is the route that the enforce paywall plug
  redirects to.
  """
  def index(conn, section, user) do
    conn
    |> Phoenix.Controller.put_view(OliWeb.PaymentProviders.StripeView)
    |> render("index.html",
      api_key: Application.fetch_env!(:oli, :stripe_provider)[:public_secret],
      purchase: Jason.encode!(%{user_id: user.id, section_slug: section.slug}),
      section: section
    )
  end

  @doc """
  Renders the page to start the direct payment processing flow.
  """
  def success(conn, %{"intent" => %{"id" => id} = intent}) do
    # get payment, stamp it as having been finalized

    case Oli.Delivery.Paywall.get_provider_payment(:stripe, id) do
      nil ->
        json(conn, %{
          result: "failure",
          reason: "No payment exists"
        })

      payment ->
        section = Oli.Delivery.Sections.get_section!(payment.pending_section_id)
        enrollment = Oli.Delivery.Sections.get_enrollment(section.slug, payment.pending_user_id)

        case Oli.Delivery.Paywall.update_payment(payment, %{
               enrollment_id: enrollment.id,
               application_date: DateTime.utc_now(),
               provider_payload: intent
             }) do
          {:ok, _} ->
            json(conn, %{
              result: "success",
              url: Routes.page_delivery_path(conn, :index, section.slug)
            })

          _ ->
            json(conn, %{
              result: "failure",
              reason: "Could not persist payment"
            })
        end
    end
  end

  def init_intent(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user

    with {:ok, section} <-
           Oli.Delivery.Sections.get_section_by_slug(section_slug) |> Oli.Utils.trap_nil(),
         {:ok, section} <-
           Oli.Repo.preload(section, [:institution, :blueprint]) |> Oli.Utils.trap_nil(),
         {:ok, product} <-
           (if is_nil(section.blueprint_id) do
              section
            else
              section.blueprint
            end)
           |> Oli.Utils.trap_nil(),
         {:ok, amount} <-
           Oli.Delivery.Paywall.calculate_product_cost(product, section.institution) do
      {stripe_value, stripe_currency} =
        Oli.Delivery.Paywall.Providers.Stripe.convert_amount(amount)

      body =
        %{
          amount: stripe_value,
          currency: stripe_currency,
          "payment_method_types[]": "card"
        }
        |> URI.encode_query()

      private_secret = Application.fetch_env!(:oli, :stripe_provider)[:private_secret]

      headers = [
        Authorization: "Bearer #{private_secret}",
        "Content-Type": "application/x-www-form-urlencoded"
      ]

      case HTTPoison.post(
             "https://api.stripe.com/v1/payment_intents",
             body,
             headers
           ) do
        {:ok, %{status_code: 200, body: body}} ->
          intent = Poison.decode!(body)

          %{"client_secret" => client_secret, "id" => id} = intent

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
            {:ok, _} ->
              json(conn, %{
                clientSecret: client_secret
              })

            _ ->
              error(conn, 500, "server error")
          end

        {:ok, %{status_code: 404}} ->
          error(conn, 404, "client error")

        {:error, _} ->
          error(conn, 500, "server error")
      end
    else
      _ ->
        error(conn, 400, "client error")
    end
  end
end
