defmodule OliWeb.LiveSessionPlugs.RedirectAdaptiveChromeless do
  use OliWeb, :verified_routes

  import Phoenix.LiveView, only: [redirect: 2]
  import Ecto.Query, only: [from: 2]

  alias Oli.Repo

  def on_mount(
        :default,
        %{"section_slug" => section_slug, "revision_slug" => revision_slug},
        _session,
        socket
      ) do
    if is_adaptive_chromeless_view?(revision_slug) do
      {:halt,
       redirect(socket, to: ~p"/sections/#{section_slug}/adaptive_lesson/#{revision_slug}")}
    else
      {:cont, socket}
    end
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end

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
