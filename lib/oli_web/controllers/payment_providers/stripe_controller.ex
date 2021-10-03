defmodule OliWeb.PaymentProviders.StripeController do
  use OliWeb, :controller
  import OliWeb.Api.Helpers
  alias Oli.Delivery.Paywall.Providers.Stripe
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Paywall
  import Oli.Utils

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
  def success(conn, %{"intent" => intent}) do
    # get payment, stamp it as having been finalized

    case Stripe.finalize_payment(intent) do
      {:ok, %{slug: slug}} ->
        json(conn, %{
          result: "success",
          url: Routes.page_delivery_path(conn, :index, slug)
        })

      {:error, reason} ->
        json(conn, %{
          result: "failure",
          reason: reason
        })
    end
  end

  @doc """
  Handles client-side request to create a payment intent. Returns the intent `clientSecret`
  to the client as a response.
  """
  def init_intent(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user

    with {:ok, section} <- Sections.get_section_by_slug(section_slug) |> trap_nil(),
         {:ok, section} <- Oli.Repo.preload(section, [:institution, :blueprint]) |> trap_nil(),
         {:ok, product} <- determine_product(section),
         {:ok, amount} <- Paywall.calculate_product_cost(product, section.institution) do
      case Stripe.create_intent(amount, user, section, product) do
        {:ok, %{"client_secret" => client_secret}} -> json(conn, %{clientSecret: client_secret})
        {:error, reason} -> error(conn, 500, reason)
      end
    else
      _ ->
        error(conn, 400, "client error")
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
