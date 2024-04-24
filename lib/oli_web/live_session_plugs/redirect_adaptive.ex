defmodule OliWeb.LiveSessionPlugs.RedirectAdaptiveChromeless do
  use OliWeb, :verified_routes

  import Phoenix.LiveView, only: [redirect: 2]
  import Ecto.Query, only: [from: 2]

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
             params["request_path"]
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
    if is_adaptive_chromeless_view?(revision_slug) do
      {:halt,
       redirect(socket,
         to: adaptive_chromeless_url(section_slug, revision_slug, params["request_path"])
       )}
    else
      {:cont, socket}
    end
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end

  def adaptive_chromeless_revision_url(section_slug, revision_slug, attempt_guid, nil),
    do: ~p"/sections/#{section_slug}/page/#{revision_slug}/attempt/#{attempt_guid}/review"

  def adaptive_chromeless_revision_url(section_slug, revision_slug, attempt_guid, request_path),
    do:
      ~p"/sections/#{section_slug}/page/#{revision_slug}/attempt/#{attempt_guid}/review?#{%{request_path: request_path}}"

  def adaptive_chromeless_url(section_slug, revision_slug, nil),
    do: ~p"/sections/#{section_slug}/adaptive_lesson/#{revision_slug}"

  def adaptive_chromeless_url(section_slug, revision_slug, request_path),
    do:
      ~p"/sections/#{section_slug}/adaptive_lesson/#{revision_slug}?#{%{request_path: request_path}}"

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
