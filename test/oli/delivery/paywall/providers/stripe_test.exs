defmodule Oli.Delivery.Paywall.Providers.StripeTest do
  use Oli.DataCase

  import Ecto.Query, warn: false
  import Mox

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Publishing
  alias Oli.Delivery.{Paywall, Sections}
  alias Oli.Delivery.Paywall.Providers.Stripe
  alias Oli.Delivery.Sections.{EnrollmentBrowseOptions}
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Test.MockHTTP

  @stripe_payments_intents_url "https://api.stripe.com/v1/payment_intents"
  @expected_headers [
    Authorization: "Bearer ",
    "Content-Type": "application/x-www-form-urlencoded"
  ]

  describe "convert_amount/1" do
    test "it handles value portions correctly" do
      # Test variations of a regular (decimal having) currency
      assert {10000, _} = Stripe.convert_amount(Money.new(100, "USD"))
      assert {10050, _} = Stripe.convert_amount(Money.from_float("USD", 100.50))
      assert {10055, _} = Stripe.convert_amount(Money.from_float("USD", 100.55))
      assert {10056, _} = Stripe.convert_amount(Money.from_float("USD", 100.555))

      # Test a zero-decimal currency
      assert {100, _} = Stripe.convert_amount(Money.new(100, "BIF"))
      assert {101, _} = Stripe.convert_amount(Money.from_float("BIF", 100.555))
    end

    test "it handles code portions correctly" do
      assert {_, "usd"} = Stripe.convert_amount(Money.new(100, "USD"))
      assert {_, "usd"} = Stripe.convert_amount(Money.new(100, "USD"))
      assert {_, "bif"} = Stripe.convert_amount(Money.new(100, "BIF"))
      assert {_, "bif"} = Stripe.convert_amount(Money.new(100, "BIF"))
      assert {_, "clp"} = Stripe.convert_amount(Money.new(100, "CLP"))
      assert {_, "clp"} = Stripe.convert_amount(Money.new(100, "CLP"))
    end
  end

  @moduletag :capture_log
  describe "create_intent/4" do
    setup [:setup_conn]

    test "intent creation succeeds",
         %{section: section, user1: user} do
      expected_body =
        %{
          amount: 10000,
          currency: "usd",
          "payment_method_types[]": "card",
          receipt_email: user.email
        }
        |> URI.encode_query()

      MockHTTP
      |> expect(:post, fn @stripe_payments_intents_url, ^expected_body, @expected_headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: "{ \"client_secret\": \"secret\", \"id\": \"test_id\" }"
         }}
      end)

      {:ok, _intent1} = Stripe.create_intent(section, user)

      pending_payment = Paywall.get_provider_payment(:stripe, "test_id")
      assert pending_payment
      refute pending_payment.application_date
      assert pending_payment.pending_section_id == section.id
      assert pending_payment.pending_user_id == user.id
      assert pending_payment.section_id == section.id
      assert pending_payment.provider_type == :stripe
      assert pending_payment.provider_id == "test_id"
    end

    test "intent creation fails when stripe fails",
         %{section: section, user1: user} do
      MockHTTP
      |> expect(:post, fn @stripe_payments_intents_url, _body, @expected_headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 500
         }}
      end)

      assert {:error, "Could not create stripe intent"} ==
               Stripe.create_intent(section, user)
    end

    test "multiple intent creation succeeds when first is not finalized",
         %{section: section, user1: user} do
      MockHTTP
      |> expect(:post, fn @stripe_payments_intents_url, _body, @expected_headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: "{ \"client_secret\": \"secret\", \"id\": \"test_id\" }"
         }}
      end)

      {:ok, _intent1} = Stripe.create_intent(section, user)

      MockHTTP
      |> expect(:post, fn @stripe_payments_intents_url, _body, @expected_headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: "{ \"client_secret\": \"secret\", \"id\": \"second_id\" }"
         }}
      end)

      {:ok, _intent2} = Stripe.create_intent(section, user)

      assert is_nil(Paywall.get_provider_payment(:stripe, "test_id"))

      pending_payment = Paywall.get_provider_payment(:stripe, "second_id")
      assert pending_payment
      refute pending_payment.application_date
      assert pending_payment.pending_section_id == section.id
      assert pending_payment.pending_user_id == user.id
      assert pending_payment.section_id == section.id
      assert pending_payment.provider_type == :stripe
      assert pending_payment.provider_id == "second_id"
    end

    test "multiple intent creation fails when first is finalized",
         %{section: section, user1: user} do
      MockHTTP
      |> expect(:post, fn @stripe_payments_intents_url, _body, @expected_headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: "{ \"client_secret\": \"secret\", \"id\": \"test_id\" }"
         }}
      end)

      {:ok, intent1} = Stripe.create_intent(section, user)
      pending_payment = Paywall.get_provider_payment(:stripe, "test_id")
      assert {:ok, _} = Stripe.finalize_payment(intent1)

      MockHTTP
      |> expect(:post, fn @stripe_payments_intents_url, _body, @expected_headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: "{ \"client_secret\": \"secret\", \"id\": \"second_id\" }"
         }}
      end)

      assert {:error, {:payment_already_exists}} = Stripe.create_intent(section, user)

      finalized = Paywall.get_provider_payment(:stripe, "test_id")
      assert finalized
      assert finalized.id == pending_payment.id
      assert finalized.application_date
    end
  end

  describe "finalize_payment/1" do
    setup [:setup_conn]

    test "finalization succeeds", %{
      section: section,
      user1: user,
      enrollment: enrollment
    } do
      MockHTTP
      |> expect(:post, fn @stripe_payments_intents_url, _body, @expected_headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: "{ \"client_secret\": \"secret\", \"id\": \"test_id\" }"
         }}
      end)

      {:ok, intent} = Stripe.create_intent(section, user)

      pending_payment = Paywall.get_provider_payment(:stripe, "test_id")
      assert pending_payment
      refute pending_payment.application_date
      assert is_nil(pending_payment.enrollment_id)
      assert pending_payment.pending_section_id == section.id
      assert pending_payment.pending_user_id == user.id
      assert pending_payment.section_id == section.id
      assert pending_payment.provider_type == :stripe
      assert pending_payment.provider_id == "test_id"

      assert {:ok, _} = Stripe.finalize_payment(intent)

      finalized = Paywall.get_provider_payment(:stripe, "test_id")
      assert finalized
      assert finalized.id == pending_payment.id
      assert finalized.enrollment_id == enrollment.id
      assert finalized.application_date
      assert finalized.pending_section_id == section.id
      assert finalized.pending_user_id == user.id
      assert finalized.section_id == section.id
      assert finalized.provider_type == :stripe
      assert finalized.provider_id == "test_id"

      e = Oli.Repo.get!(Oli.Delivery.Sections.Enrollment, finalized.enrollment_id)
      assert e.user_id == user.id
      assert e.section_id == section.id

      results =
        Sections.browse_enrollments(
          section,
          %Paging{offset: 0, limit: 3},
          %Sorting{field: :email, direction: :asc},
          %EnrollmentBrowseOptions{
            is_student: false,
            is_instructor: false,
            text_search: nil
          }
        )

      assert Enum.count(results) == 1
      refute is_nil(hd(results).payment_date)
    end

    test "finalization fails when no pending payment found", %{} do
      assert {:error, "Payment does not exist"} ==
               Stripe.finalize_payment(%{"id" => "a_made_up_intent_id"})
    end

    test "double finalization fails", %{section: section, user1: user} do
      MockHTTP
      |> expect(:post, fn @stripe_payments_intents_url, _body, @expected_headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: "{ \"client_secret\": \"secret\", \"id\": \"test_id\" }"
         }}
      end)

      {:ok, intent} = Stripe.create_intent(section, user)
      assert {:ok, _} = Stripe.finalize_payment(intent)

      assert {:error, "Payment already finalized"} = Stripe.finalize_payment(intent)
    end
  end

  defp setup_conn(_conn) do
    map = Seeder.base_project_with_resource2()

    {:ok, _} = Publishing.publish_project(map.project, "some changes", map.author.id)

    # Create a product using the initial publication
    {:ok, product} =
      Sections.create_section(%{
        type: :blueprint,
        requires_payment: true,
        amount: Money.new(100, "USD"),
        title: "1",
        registration_open: true,
        grace_period_days: 1,
        context_id: UUID.uuid4(),
        institution_id: map.institution.id,
        base_project_id: map.project.id,
        publisher_id: map.project.publisher_id
      })

    user1 = user_fixture(%{email_confirmed_at: Timex.now()}) |> Repo.preload(:platform_roles)

    {:ok, section} =
      Sections.create_section(%{
        type: :enrollable,
        requires_payment: true,
        amount: Money.new(100, "USD"),
        title: "1",
        registration_open: true,
        has_grace_period: false,
        grace_period_days: 1,
        context_id: UUID.uuid4(),
        start_date: DateTime.add(DateTime.utc_now(), -5),
        end_date: DateTime.add(DateTime.utc_now(), 5),
        institution_id: map.institution.id,
        base_project_id: map.project.id,
        blueprint_id: product.id
      })

    {:ok, enrollment} =
      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_learner)])

    %{
      section: section,
      map: map,
      user1: user1,
      enrollment: enrollment
    }
  end
end
