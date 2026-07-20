defmodule Oli.Scenarios.StudentPayment.Hooks do
  @moduledoc false

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Accounts
  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Paywall.Payment
  alias Oli.Delivery.Sections
  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  alias Oli.Scenarios.Engine

  @default_guest_name "student_payment_guest_user"
  @default_section_name "student_payment_guest_paid_section"
  @default_payment_code_product_name "student_payment_code_unlock_product"
  @default_payment_code_param_key "payment_code"
  @default_stripe_section_name "student_payment_stripe_unlock_section"
  @default_stripe_user_name "student_payment_stripe_unlock_student"
  @default_stripe_param_key "stripe_intent_id"
  @default_cashnet_section_name "student_payment_cashnet_unlock_section"
  @default_cashnet_user_name "student_payment_cashnet_unlock_student"
  @default_cashnet_param_key "cashnet_payment_ref"
  @default_cashnet_lname_param_key "cashnet_lname"

  def create_enrolled_guest(%ExecutionState{} = state) do
    guest_name = Map.get(state.params || %{}, "guest_user_name", @default_guest_name)
    section_name = Map.get(state.params || %{}, "guest_section_name", @default_section_name)
    run_id = Map.get(state.params || %{}, "RUN_ID", "")

    section =
      Engine.get_section(state, section_name) ||
        raise "Section '#{section_name}' not found for guest enrollment hook"

    suffix =
      [run_id, Integer.to_string(System.unique_integer([:positive]))]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join("-")

    {:ok, guest} =
      Accounts.create_guest_user(%{
        email: "student-payment-guest-#{suffix}@example.com",
        given_name: "Guest",
        family_name: "Student"
      })

    context_role = ContextRoles.get_role(:context_learner)

    case Sections.enroll([guest.id], section.id, [context_role]) do
      {:ok, _} ->
        put_guest_in_state(state, guest_name, guest)

      {:error, reason} ->
        raise "Failed to enroll guest user in section '#{section_name}': #{inspect(reason)}"
    end
  end

  def create_payment_code(%ExecutionState{} = state) do
    product_name =
      Map.get(
        state.params || %{},
        "payment_code_product_name",
        @default_payment_code_product_name
      )

    param_key =
      Map.get(state.params || %{}, "payment_code_param_key", @default_payment_code_param_key)

    product =
      Engine.get_product(state, product_name) ||
        raise "Product '#{product_name}' not found for payment code hook"

    {:ok, [payment | _]} = Paywall.create_payment_codes(product.slug, 1)
    human_code = Payment.to_human_readable(payment.code)

    put_param(state, param_key, human_code)
  end

  def create_pending_stripe_payment(%ExecutionState{} = state) do
    section_name =
      Map.get(state.params || %{}, "stripe_section_name", @default_stripe_section_name)

    user_name = Map.get(state.params || %{}, "stripe_user_name", @default_stripe_user_name)
    param_key = Map.get(state.params || %{}, "stripe_param_key", @default_stripe_param_key)

    section =
      Engine.get_section(state, section_name) ||
        raise "Section '#{section_name}' not found for stripe hook"

    user =
      Engine.get_user(state, user_name) ||
        raise "User '#{user_name}' not found for stripe hook"

    intent_id = unique_provider_id("pi")

    {:ok, _payment} =
      Paywall.create_pending_payment(user, section, %{
        type: :direct,
        generation_date: DateTime.utc_now(),
        amount: section.amount,
        provider_payload: %{"id" => intent_id, "status" => "requires_payment_method"},
        provider_id: intent_id,
        provider_type: :stripe,
        section_id: section.id
      })

    put_param(state, param_key, intent_id)
  end

  def create_pending_cashnet_payment(%ExecutionState{} = state) do
    section_name =
      Map.get(state.params || %{}, "cashnet_section_name", @default_cashnet_section_name)

    user_name = Map.get(state.params || %{}, "cashnet_user_name", @default_cashnet_user_name)
    param_key = Map.get(state.params || %{}, "cashnet_param_key", @default_cashnet_param_key)

    lname_param_key =
      Map.get(state.params || %{}, "cashnet_lname_param_key", @default_cashnet_lname_param_key)

    section =
      Engine.get_section(state, section_name) ||
        raise "Section '#{section_name}' not found for cashnet hook"

    user =
      Engine.get_user(state, user_name) ||
        raise "User '#{user_name}' not found for cashnet hook"

    payment_ref = unique_provider_id("cashnet")

    {:ok, _payment} =
      Paywall.create_pending_payment(user, section, %{
        type: :direct,
        generation_date: DateTime.utc_now(),
        amount: section.amount,
        provider_payload: %{"ref1val1" => payment_ref},
        provider_id: payment_ref,
        provider_type: :cashnet,
        section_id: section.id
      })

    state
    |> put_param(param_key, payment_ref)
    |> put_param(lname_param_key, System.get_env("CASHNET_NAME", "none"))
  end

  defp put_guest_in_state(%ExecutionState{} = state, guest_name, guest) do
    updated_params =
      state.params
      |> Kernel.||(%{})
      |> Map.put("guest_user_email", guest.email)
      |> Map.put("guest_user_name", guest_name)

    %{state | users: Map.put(state.users, guest_name, guest), params: updated_params}
  end

  defp put_param(%ExecutionState{} = state, key, value) do
    updated_params =
      state.params
      |> Kernel.||(%{})
      |> Map.put(key, value)

    %{state | params: updated_params}
  end

  defp unique_provider_id(prefix) do
    "#{prefix}_#{System.unique_integer([:positive])}"
  end
end
