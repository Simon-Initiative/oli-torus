defmodule OliWeb.LiveSessionPlugs.RedirectToLesson do
  @moduledoc """
  Redirects the student to the lesson liveview if the state of the page is :in_progress.
  It does not redirect when trying to access a review page.
  """

  use OliWeb, :verified_routes

  import Phoenix.LiveView, only: [redirect: 2]

  alias Oli.Delivery.Page.PageContext
  alias OliWeb.Delivery.Student.Utils

  # reviews should not be redirected
  def on_mount(:default, %{"attempt_guid" => _attempt_guid}, _session, socket),
    do: {:cont, socket}

  def on_mount(
        :default,
        %{"section_slug" => section_slug, "revision_slug" => revision_slug} = params,
        _session,
        socket
      ) do
    case socket.assigns.page_context do
      %PageContext{progress_state: progress_state}
      when progress_state in [:revised, :in_progress] ->
        {:halt,
         redirect(socket,
           to:
             Utils.lesson_live_path(section_slug, revision_slug,
               request_path: params["request_path"],
               selected_view: params["selected_view"]
             )
         )}

      _ ->
        {:cont, socket}
    end
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end
end
