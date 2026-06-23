defmodule OliWeb.LiveSessionPlugs.SetInstructorPreviewReturn do
  import Phoenix.Component, only: [assign: 2]

  alias OliWeb.Delivery.Instructor.PreviewReturn

  def on_mount(:default, :not_mounted_at_router, _session, socket) do
    {:cont, socket}
  end

  def on_mount(:default, params, _session, %{assigns: %{section: %{slug: section_slug}}} = socket) do
    {:cont,
     assign(socket,
       instructor_preview_return: PreviewReturn.resolve(section_slug, params["return_to"])
     )}
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end
end
