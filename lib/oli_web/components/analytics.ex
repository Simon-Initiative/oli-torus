defmodule OliWeb.Components.Analytics do
  @moduledoc "Shared head installation for opted-in, covered root layouts."
  use Phoenix.Component

  alias Oli.Consent
  alias OliWeb.Analytics

  attr :conn, Plug.Conn, required: true

  @doc "Bootstraps resolved cookie preferences and consent before loading the analytics writer."
  def gtm_head(assigns) do
    preferences = Consent.preferences(assigns.conn)
    privacy_url = Application.get_env(:oli, :privacy_policies, [])[:url]

    assigns =
      assign(assigns,
        config: head_config(assigns.conn, preferences, privacy_url),
        consent_config:
          Jason.encode!(%{
            preferences: preferences,
            signedIn: not is_nil(assigns.conn.assigns[:current_user]),
            privacyPoliciesUrl: privacy_url,
            isMobileOrTablet: OliWeb.Common.DeviceDetection.is_mobile_or_tablet?(assigns.conn)
          })
      )

    ~H"""
    <script id="torus-cookie-consent" type="application/json" data-config={@consent_config}>
    </script>
    <script
      :if={@config}
      id="torus-analytics"
      src={OliWeb.Router.Helpers.static_path(@conn, "/js/analytics.js")}
      data-config={@config}
    >
    </script>
    """
  end

  defp head_config(conn, preferences, privacy_url) do
    with true <- Analytics.enabled?(),
         %{} = context <- Analytics.context_for_conn(conn) do
      config = Application.get_env(:oli, :analytics, [])

      Jason.encode!(%{
        container_id: config[:gtm_container_id],
        auth: config[:gtm_auth],
        preview: config[:gtm_preview],
        measurement_ids: config[:measurement_ids] || [],
        consent: preferences,
        signed_in: not is_nil(conn.assigns[:current_user]),
        consent_available: is_binary(privacy_url) and String.trim(privacy_url) != "",
        context: context
      })
    else
      _ -> nil
    end
  end
end
