defmodule OliWeb.LiveSessionPlugs.SetRequestPath do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]

  alias OliWeb.Delivery.Student.Utils

  def on_mount(:default, :not_mounted_at_router, _session, socket) do
    {:cont, socket}
  end

  def on_mount(:default, params, _session, socket) do
    section_slug = socket.assigns.section.slug

    selected_view =
      if params["selected_view"] in [nil, ""], do: "gallery", else: params["selected_view"]

    request_path =
      case params["request_path"] do
        request_path when request_path in ["", nil] ->
          Utils.learn_live_path(section_slug, selected_view: selected_view)

        request_path ->
          request_path
      end

    {:cont, assign(socket, request_path: request_path, selected_view: selected_view)}
  end
end
