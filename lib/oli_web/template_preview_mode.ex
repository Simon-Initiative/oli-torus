defmodule OliWeb.TemplatePreviewMode do
  @moduledoc """
  Helpers for recognizing an active template preview delivery session.
  """

  import Plug.Conn, only: [get_session: 2]

  alias Oli.Delivery.Sections.Section

  def active?(%Plug.Conn{} = conn, %Section{} = section) do
    section.type == :blueprint and
      get_session(conn, :template_preview_mode) == true and
      get_session(conn, :template_preview_section_slug) == section.slug
  end

  def active?(session, %Section{} = section) when is_map(session) do
    section.type == :blueprint and
      session["template_preview_mode"] == true and
      session["template_preview_section_slug"] == section.slug
  end

  def active?(_session_or_conn, _section), do: false
end
