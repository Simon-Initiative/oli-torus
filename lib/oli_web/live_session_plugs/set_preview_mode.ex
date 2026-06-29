defmodule OliWeb.LiveSessionPlugs.SetPreviewMode do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]

  def on_mount(:default, :not_mounted_at_router, session, socket),
    do: on_mount(:default, %{}, session, socket)

  def on_mount(:default, _params, session, socket) do
    preview_mode = socket.assigns[:live_action] == :preview
    section_slug = section_slug(socket)

    template_preview_mode =
      session["template_preview_mode"] == true and
        session["template_preview_section_slug"] == section_slug

    {:cont,
     assign(socket,
       preview_mode: preview_mode,
       template_preview_mode: template_preview_mode,
       template_preview_exit_path:
         if(template_preview_mode, do: ~p"/authoring/template_preview/exit", else: nil)
     )}
  end

  defp section_slug(%{assigns: %{section: %{slug: slug}}}), do: slug
  defp section_slug(_socket), do: nil
end
