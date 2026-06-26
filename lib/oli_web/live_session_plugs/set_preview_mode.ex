defmodule OliWeb.LiveSessionPlugs.SetPreviewMode do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]

  alias OliWeb.Delivery.Student.Utils, as: StudentUtils

  def on_mount(:default, params, session, socket) do
    preview_mode = socket.assigns[:live_action] == :preview

    template_preview_mode =
      session["template_preview_mode"] == true and
        session["template_preview_section_slug"] == section_slug(socket)

    {:cont,
     assign(socket,
       preview_mode: preview_mode,
       section_preview_kind: StudentUtils.section_preview_kind(preview_mode, params),
       template_preview_mode: template_preview_mode,
       template_preview_exit_path:
         if(template_preview_mode, do: ~p"/authoring/template_preview/exit", else: nil)
     )}
  end

  defp section_slug(%{assigns: %{section: %{slug: slug}}}), do: slug
  defp section_slug(_socket), do: nil
end
