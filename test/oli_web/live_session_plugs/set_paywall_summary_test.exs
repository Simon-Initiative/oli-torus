defmodule OliWeb.LiveSessionPlugs.SetPaywallSummaryTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias OliWeb.LiveSessionPlugs.SetPaywallSummary
  alias Phoenix.LiveView

  describe "on_mount/4" do
    setup do
      stub_real_current_time()
      :ok
    end

    test "uses instructor summary for active template preview even when user is in grace period" do
      section =
        insert(:section, %{
          type: :blueprint,
          requires_payment: true,
          amount: Money.new(:USD, 100),
          has_grace_period: true,
          grace_period_days: 14,
          grace_period_strategy: :relative_to_student
        })

      user = preview_user()
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      socket = socket(user, section)

      assert {:cont, socket} = SetPaywallSummary.on_mount(:default, %{}, %{}, socket)
      assert socket.assigns.paywall_summary.reason == :within_grace_period

      session = %{
        "template_preview_mode" => true,
        "template_preview_section_slug" => section.slug
      }

      assert {:cont, socket} =
               SetPaywallSummary.on_mount(:default, %{}, session, socket(user, section))

      assert socket.assigns.paywall_summary.available
      assert socket.assigns.paywall_summary.reason == :instructor
    end

    test "does not use preview summary when section slug does not match" do
      section =
        insert(:section, %{
          type: :blueprint,
          requires_payment: true,
          amount: Money.new(:USD, 100)
        })

      user = preview_user()

      session = %{
        "template_preview_mode" => true,
        "template_preview_section_slug" => "other-section"
      }

      assert {:cont, socket} =
               SetPaywallSummary.on_mount(:default, %{}, session, socket(user, section))

      refute socket.assigns.paywall_summary.available
      assert socket.assigns.paywall_summary.reason == :not_paid
    end
  end

  defp socket(user, section) do
    %LiveView.Socket{
      endpoint: OliWeb.Endpoint,
      assigns: %{__changed__: %{}, current_user: user, section: section}
    }
  end

  defp preview_user do
    insert(:user)
    |> Map.put(:platform_roles, [])
  end
end
