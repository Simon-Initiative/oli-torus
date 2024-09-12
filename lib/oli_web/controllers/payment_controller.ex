defmodule OliWeb.PaymentController do
  use OliWeb, :controller
  require Logger
  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Paywall.AccessSummary
  alias Oli.Delivery.Sections
  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.FormatDateTime

  @doc """
  Render the page to show a student that they do not have access because
  of the paywall state.  This is the route that the enforce paywall plug
  redirects to.
  """
  def guard(conn, %{"section_slug" => section_slug}) do
    user = conn.assigns.current_user
    section = conn.assigns.section

    if Sections.is_enrolled?(user.id, section_slug) do
      if user.guest do
        render(conn, "require_account.html", section_slug: section_slug)
      else
        context = SessionContext.init(conn)

        section =
          section
          |> Sections.localize_section_start_end_datetimes(context)

        summary = Paywall.summarize_access(user, section)

        grace_period_seconds =
          if summary.grace_period_remaining == nil, do: 0, else: summary.grace_period_remaining

        now_date = FormatDateTime.convert_datetime(DateTime.utc_now(), context)
        payment_due_date = DateTime.add(now_date, grace_period_seconds, :second)

        {:ok, amount} = Money.to_string(section.amount)

        instructors =
          Sections.fetch_instructors(section.slug)
          |> Enum.reduce([], fn a, m ->
            m ++ [a.name]
          end)

        render(conn, "guard.html",
          context: context,
          pay_by_card?:
            direct_payments_enabled?() and
              (section.payment_options == :direct or
                 section.payment_options == :direct_and_deferred),
          pay_by_code?:
            section.payment_options == :deferred or
              section.payment_options == :direct_and_deferred,
          section_slug: section_slug,
          section_title: section.title,
          section: section,
          instructors: Enum.join(instructors, ", "),
          amount: amount,
          payment_due_date: %{payment_due_date: payment_due_date},
          grace_period_days: not is_nil(summary.grace_period_remaining)
        )
      end
    else
      render(conn, "not_enrolled.html", section_slug: section_slug)
    end
  end

  # Returns the module for the configured payment provider
  defp get_provider_module() do
    validate = fn a ->
      case a do
        :stripe ->
          OliWeb.PaymentProviders.StripeController

        :cashnet ->
          OliWeb.PaymentProviders.CashnetController

        :none ->
          OliWeb.PaymentProviders.NoProviderController

        e ->
          Logger.warning("Payment provider is not valid. ", e)
          OliWeb.PaymentProviders.NoProviderController
      end
    end

    case Application.fetch_env!(:oli, :payment_provider) do
      a when is_atom(a) -> validate.(a)
      s when is_binary(s) -> String.to_existing_atom(s) |> validate.()
    end
  end

  defp direct_payments_enabled?() do
    get_provider_module() != OliWeb.PaymentProviders.NoProviderController
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
      # Check the paywall access summary, as this route isn't protected by the
      # plug that inserts the access summary into the assigns.  We allow users
      # view the "make a payment" page only if they are within the grace period
      # or if the course material is now unavailable because they haven't paid
      allow_payment =
        case Oli.Delivery.Paywall.summarize_access(user, section) do
          %AccessSummary{available: false, reason: :not_paid} -> true
          %AccessSummary{available: true, reason: :within_grace_period} -> true
          _ -> false
        end

      if allow_payment do
        case section.amount do
          nil ->
            conn
            |> redirect(to: ~p"/sections/#{section.slug}")

          amount ->
            get_provider_module()
            |> apply(:show, [conn, section, user, amount])
        end
      else
        conn
        |> redirect(to: ~p"/sections/#{section.slug}")
      end
    end

    # perform this check in the case that a user refreshes the payment page
    # after already paying.  This will simply redirect them to their course.
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

  defp create_payment_codes_file(conn, data, product_slug) do
    contents =
      Enum.map(data, fn p ->
        Oli.Delivery.Paywall.Payment.to_human_readable(p.code)
      end)
      |> Enum.join("\n")

    conn
    |> send_download({:binary, contents},
      filename: "codes_#{product_slug}.txt"
    )
  end

  @doc """
  Endpoint that triggers download of a batch of payemnt codes.
  """
  def download_payment_codes(conn, %{"product_id" => product_slug}) do
    codes = Oli.Delivery.Paywall.list_payments_by_count(product_slug, conn.params["count"] || 50)
    create_payment_codes_file(conn, codes, product_slug)
  end

  @doc """
  Endpoint that triggers creation and download of a batch of payemnt codes.
  """
  def download_codes(conn, %{"count" => count, "product_id" => product_slug}) do
    case Oli.Delivery.Paywall.create_payment_codes(product_slug, String.to_integer(count)) do
      {:ok, payments} ->
        create_payment_codes_file(conn, payments, product_slug)

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
  def apply_code(
        conn,
        %{
          "section_slug" => section_slug,
          "code" => %{"value" => code}
        } = params
      ) do
    if Map.get(params, "g-recaptcha-response", "") |> recaptcha_verified?() do
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
    Oli.Utils.Recaptcha.verify(g_recaptcha_response) == {:success, true}
  end
end
