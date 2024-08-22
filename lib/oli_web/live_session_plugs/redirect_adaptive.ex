defmodule OliWeb.LiveSessionPlugs.RedirectAdaptiveChromeless do
  @moduledoc """
  Redirects the student to the adaptive chromeless url when the required adaptive chromeless page has :in_progress state.
  Other casees are handled by the default live view (the prologue view where student can review previous attempts)
  """

  use OliWeb, :verified_routes

  import Phoenix.LiveView, only: [redirect: 2]
  import Ecto.Query, only: [from: 2]

  alias Oli.Delivery.Page.PageContext
  alias Oli.Repo

  def on_mount(
        :default,
        %{
          "section_slug" => section_slug,
          "revision_slug" => revision_slug,
          "attempt_guid" => attempt_guid
        } = params,
        _session,
        socket
      ) do
    if is_adaptive_chromeless_view?(revision_slug) do
      {:halt,
       redirect(socket,
         to:
           adaptive_chromeless_revision_url(
             section_slug,
             revision_slug,
             attempt_guid,
             request_path: params["request_path"],
             selected_view: params["selected_view"]
           )
       )}
    else
      {:cont, socket}
    end
  end

  def on_mount(
        :default,
        %{"section_slug" => section_slug, "revision_slug" => revision_slug} = params,
        _session,
        socket
      ) do
    case socket.assigns.page_context do
      %PageContext{
        page: %{
          content: %{
            "advancedDelivery" => true,
            "displayApplicationChrome" => false
          }
        },
        progress_state: progress_state
      }
      when progress_state in [:revised, :in_progress] ->
        {:halt,
         redirect(socket,
           to:
             adaptive_chromeless_url(section_slug, revision_slug,
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

  def adaptive_chromeless_revision_url(section_slug, revision_slug, attempt_guid, params),
    do:
      ~p"/sections/#{section_slug}/page/#{revision_slug}/attempt/#{attempt_guid}/review?#{params}"

  def adaptive_chromeless_url(section_slug, revision_slug, params),
    do: ~p"/sections/#{section_slug}/adaptive_lesson/#{revision_slug}?#{params}"

  defp is_adaptive_chromeless_view?(revision_slug) do
    Repo.exists?(
      from(r in Oli.Resources.Revision,
        where:
          r.slug == ^revision_slug and
            fragment(
              "COALESCE((? ->> 'advancedDelivery')::boolean, false) AND COALESCE(NOT (? ->> 'displayApplicationChrome')::boolean, false)",
              r.content,
              r.content
            )
      )
    )
  end
end
