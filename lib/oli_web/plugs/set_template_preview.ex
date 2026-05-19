defmodule OliWeb.Plugs.SetTemplatePreview do
  use OliWeb, :verified_routes

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    template_preview_mode =
      get_session(conn, :template_preview_mode) == true and
        get_session(conn, :template_preview_section_slug) == section_slug(conn)

    conn
    |> assign(:template_preview_mode, template_preview_mode)
    |> assign(
      :template_preview_exit_path,
      if(template_preview_mode, do: ~p"/authoring/template_preview/exit", else: nil)
    )
  end

  defp section_slug(%Plug.Conn{assigns: %{section: %{slug: slug}}}), do: slug
  defp section_slug(_conn), do: nil
end
