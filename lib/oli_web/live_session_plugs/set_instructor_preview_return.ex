defmodule OliWeb.LiveSessionPlugs.SetInstructorPreviewReturn do
  import Phoenix.Component, only: [assign: 2]

  alias OliWeb.Delivery.Instructor.PreviewReturn

  def on_mount(:default, :not_mounted_at_router, _session, socket) do
    {:cont, socket}
  end

  def on_mount(:default, params, _session, socket) do
    case {params, socket.assigns[:section]} do
      {%{"return_to" => return_to}, %{slug: section_slug}}
      when is_binary(return_to) and return_to != "" ->
        {:cont,
         assign(socket,
           instructor_preview_return: PreviewReturn.resolve(section_slug, return_to)
         )}

      _ ->
        {:cont, socket}
    end
  end
end
