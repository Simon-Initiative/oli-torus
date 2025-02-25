defmodule OliWeb.LiveSessionPlugs.SetRequireCertificationCheck do
  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [connected?: 1]

  alias Oli.Delivery.GrantedCertificates

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      %{current_user: current_user, section: section} = socket.assigns
      certificate_enabled = section.certificate_enabled
      user_id = current_user.id
      section_id = section.id

      socket =
        with true <- certificate_enabled,
             false <- GrantedCertificates.with_distinction_exists?(user_id, section_id) do
          assign(socket, require_certification_check: true)
        else
          _ -> assign(socket, require_certification_check: false)
        end

      {:cont, socket}
    else
      {:cont, socket}
    end
  end
end
