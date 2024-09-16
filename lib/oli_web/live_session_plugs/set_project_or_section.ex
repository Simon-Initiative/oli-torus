defmodule OliWeb.LiveSessionPlugs.SetProjectOrSection do
  use OliWeb, :verified_routes

  alias OliWeb.LiveSessionPlugs.SetProject
  alias OliWeb.LiveSessionPlugs.SetSection

  def on_mount(:default, %{"project_id" => _project_id} = params, session, socket) do
    SetProject.on_mount(:default, params, session, socket)
  end

  def on_mount(:default, %{"section_slug" => _section_slug} = params, session, socket) do
    SetSection.on_mount(:default, params, session, socket)
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end
end
