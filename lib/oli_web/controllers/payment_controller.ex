defmodule OliWeb.PaymentController do
  use OliWeb, :controller

  @doc """
  Render the page to show a student that they do not have access because
  of the paywall state.  This is the route that the enforce paywall plug
  redirects to.
  """
  def guard(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user

    if user.guest do
      render(conn, "require_account.html", section_slug: section_slug)
    else
      render(conn, "guard.html", section_slug: section_slug)
    end
  end

  @doc """
  Renders the page to start the direct payment processing flow.
  """
  def make_payment(conn, %{"section_slug" => section_slug}) do
    # Dynamically dispatch to the "index" method of the registered
    # payment provider implementation
    section = conn.assigns.section
    user = conn.assigns.current_user

    if user.guest do
      render(conn, "require_account.html", section_slug: section_slug)
    else
      if Oli.Delivery.Paywall.can_access?(user, section) do
        conn
        |> redirect(to: Routes.page_delivery_path(conn, :index, section.slug))
      else
        case determine_cost(section) do
          {:ok, amount} ->
            Application.fetch_env!(:oli, :payment_provider)
            |> apply(:index, [conn, section, user, amount])

          _ ->
            conn
            |> redirect(to: Routes.page_delivery_path(conn, :index, section.slug))
        end
      end
    end

    # perform this check in the case that a user refreshes the payment page
    # after already paying.  This will simply redirect them to their course.
  end

  defp determine_product(section) do
    if is_nil(section.blueprint_id) do
      section
    else
      section.blueprint
    end
  end

  defp determine_cost(section) do
    section = Oli.Repo.preload(section, [:institution, :blueprint])
    product = determine_product(section)
    Oli.Delivery.Paywall.calculate_product_cost(product, section.institution)
  end

  @doc """
  Renders the page to allow payment code redemption.
  """
  def use_code(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user

    if user.guest do
      render(conn, "require_account.html", section_slug: section_slug)
    else
      render(conn, "code.html", section_slug: section_slug)
    end
  end

  @doc """
  Endpoint that triggers creation and download of a batch of payemnt codes.
  """
  def download_codes(conn, %{"count" => count, "product_id" => product_slug}) do
    case Oli.Delivery.Paywall.create_payment_codes(product_slug, String.to_integer(count)) do
      {:ok, payments} ->
        contents =
          Enum.map(payments, fn p ->
            Oli.Delivery.Paywall.Payment.to_human_readable(p.code)
          end)
          |> Enum.join("\n")

        conn
        |> send_download({:binary, contents},
          filename: "codes_#{product_slug}.txt"
        )

      _ ->
        conn
        |> send_download({:binary, "Error in generating codes"},
          filename: "ERROR_codes_#{product_slug}.txt"
        )
    end
  end

  @doc """
  Handles applying a user supplied code as a payment code.
  """
  def apply_code(conn, %{
        "g-recaptcha-response" => g_recaptcha_response,
        "section_slug" => section_slug,
        "code" => %{"value" => code}
      }) do
    if recaptcha_verified?(g_recaptcha_response) do
      user = conn.assigns.current_user

      case Oli.Delivery.Paywall.redeem_code(code, user, section_slug) do
        {:ok, _} ->
          render(conn, "code_success.html", section_slug: section_slug)

        {:error, _} ->
          render(conn, "code.html", error: "This is an invalid code", section_slug: section_slug)
      end
    else
      render(conn, "code.html",
        recaptcha_error: "ReCaptcha failed, please try again",
        section_slug: section_slug
      )
    end
  end

  defp recaptcha_verified?(g_recaptcha_response) do
    g_recaptcha_response != "" and
      Oli.Utils.Recaptcha.verify(g_recaptcha_response) == {:success, true}
  end
end
