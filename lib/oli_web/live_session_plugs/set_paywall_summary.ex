defmodule OliWeb.LiveSessionPlugs.SetPaywallSummary do
  import Phoenix.Component, only: [assign: 2]
  use Appsignal.Instrumentation.Decorators
  alias Oli.Delivery.Paywall

  @decorate transaction_event("SetPaywallSummary")
  def on_mount(
        :default,
        _params,
        _session,
        %{assigns: %{current_user: current_user, section: section}} = socket
      )
      when not is_nil(section) and not is_nil(current_user) do
    {:cont,
     assign(socket,
       paywall_summary: Paywall.summarize_access(current_user, section)
     )}
  end

  def on_mount(:default, _params, _session, socket), do: {:cont, socket}
end
