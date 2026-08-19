defmodule Oli.Scenarios.StudentPayment.HooksTest do
  use Oli.DataCase

  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Sections
  alias Oli.Scenarios.DirectiveParser
  alias Oli.Scenarios.Engine

  test "create_enrolled_guest hook creates and enrolls a guest learner" do
    yaml = """
    - project:
        name: "guest_project"
        title: "Guest Project"
        root:
          children:
            - page: "Page 1"

    - product:
        name: "guest_product"
        title: "Guest Product"
        from: "guest_project"
        requires_payment: true
        payment_options: "direct"
        amount:
          amount: 25
          currency: "USD"

    - section:
        name: "guest_section"
        title: "Guest Section"
        from: "guest_product"

    - hook:
        function: "Oli.Scenarios.StudentPayment.Hooks.create_enrolled_guest/1"
    """

    directives = DirectiveParser.parse_yaml!(yaml)

    result =
      Engine.execute(directives,
        params: %{
          "RUN_ID" => "hooks-test",
          "guest_user_name" => "guest_user",
          "guest_section_name" => "guest_section"
        }
      )

    assert result.errors == []

    guest = Engine.get_user(result.state, "guest_user")
    section = Engine.get_section(result.state, "guest_section")

    assert guest.guest == true
    assert result.state.params["guest_user_email"] == guest.email
    assert Sections.is_enrolled?(guest.id, section.slug)
  end

  test "create_payment_code hook creates a redeemable payment code" do
    yaml = """
    - project:
        name: "code_project"
        title: "Code Project"
        root:
          children:
            - page: "Page 1"

    - product:
        name: "code_product"
        title: "Code Product"
        from: "code_project"
        requires_payment: true
        payment_options: "deferred"
        amount:
          amount: 25
          currency: "USD"

    - hook:
        function: "Oli.Scenarios.StudentPayment.Hooks.create_payment_code/1"
    """

    directives = DirectiveParser.parse_yaml!(yaml)

    result =
      Engine.execute(directives,
        params: %{
          "payment_code_product_name" => "code_product"
        }
      )

    assert result.errors == []
    assert is_binary(result.state.params["payment_code"])
  end

  test "create_pending_stripe_payment hook creates a pending direct payment" do
    yaml = """
    - project:
        name: "stripe_project"
        title: "Stripe Project"
        root:
          children:
            - page: "Page 1"

    - product:
        name: "stripe_product"
        title: "Stripe Product"
        from: "stripe_project"
        requires_payment: true
        payment_options: "direct"
        amount:
          amount: 25
          currency: "USD"

    - section:
        name: "stripe_section"
        title: "Stripe Section"
        from: "stripe_product"

    - user:
        name: "stripe_student"
        type: "student"
        email: "stripe-student@example.com"
        given_name: "Stripe"
        family_name: "Student"
        password: "changeme123456"

    - enroll:
        user: "stripe_student"
        section: "stripe_section"
        role: "student"

    - hook:
        function: "Oli.Scenarios.StudentPayment.Hooks.create_pending_stripe_payment/1"
    """

    directives = DirectiveParser.parse_yaml!(yaml)

    result =
      Engine.execute(directives,
        params: %{
          "stripe_section_name" => "stripe_section",
          "stripe_user_name" => "stripe_student"
        }
      )

    assert result.errors == []

    intent_id = result.state.params["stripe_intent_id"]
    assert intent_id
    assert Paywall.get_provider_payment(:stripe, intent_id)
  end

  test "create_pending_cashnet_payment hook creates a pending direct payment" do
    yaml = """
    - project:
        name: "cashnet_project"
        title: "Cashnet Project"
        root:
          children:
            - page: "Page 1"

    - product:
        name: "cashnet_product"
        title: "Cashnet Product"
        from: "cashnet_project"
        requires_payment: true
        payment_options: "direct"
        amount:
          amount: 25
          currency: "USD"

    - section:
        name: "cashnet_section"
        title: "Cashnet Section"
        from: "cashnet_product"

    - user:
        name: "cashnet_student"
        type: "student"
        email: "cashnet-student@example.com"
        given_name: "Cashnet"
        family_name: "Student"
        password: "changeme123456"

    - enroll:
        user: "cashnet_student"
        section: "cashnet_section"
        role: "student"

    - hook:
        function: "Oli.Scenarios.StudentPayment.Hooks.create_pending_cashnet_payment/1"
    """

    directives = DirectiveParser.parse_yaml!(yaml)

    result =
      Engine.execute(directives,
        params: %{
          "cashnet_section_name" => "cashnet_section",
          "cashnet_user_name" => "cashnet_student"
        }
      )

    assert result.errors == []

    payment_ref = result.state.params["cashnet_payment_ref"]
    assert payment_ref
    assert Paywall.get_provider_payment(:cashnet, payment_ref)
  end
end
