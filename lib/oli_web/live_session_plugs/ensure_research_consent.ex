defmodule OliWeb.LiveSessionPlugs.EnsureResearchConsent do
  @moduledoc "Checks research consent on LiveView mounts, including live navigation and reconnects."
  use OliWeb, :verified_routes

  alias Oli.Delivery

  @doc """
  Halts before mounting section content when the user has a pending consent form.
  Must run after authentication and SetSection, and before page context initialization.
  """
  def on_mount(:default, _params, _session, socket) do
    with false <- socket.assigns[:is_admin] == true,
         true <-
           Delivery.user_research_consent_pending?(
             socket.assigns[:current_user],
             socket.assigns[:section]
           ) do
      # on_mount has no request URI. Return through the section entry point after answering.
      return_to = ~p"/sections/#{socket.assigns.section.slug}"

      {:halt,
       Phoenix.LiveView.redirect(socket,
         to: ~p"/research_consent?user_return_to=#{return_to}"
       )}
    else
      _ -> {:cont, socket}
    end
  end
end
