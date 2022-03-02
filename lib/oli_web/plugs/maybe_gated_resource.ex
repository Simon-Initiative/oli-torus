defmodule Oli.Plugs.MaybeGatedResource do
  import Plug.Conn
  import Phoenix.Controller
  import OliWeb.Common.FormatDateTime

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Revision
  alias Oli.Delivery.Gating

  def init(opts), do: opts

  def call(conn, _opts) do
    with %{"section_slug" => section_slug, "revision_slug" => revision_slug} <- conn.path_params,
         revision <- DeliveryResolver.from_revision_slug(section_slug, revision_slug) do
      case revision do
        %Revision{resource_id: resource_id} ->
          %{section: section, current_user: user} = conn.assigns

          case Gating.blocked_by(section, user, resource_id) do
            [] -> conn
            blocking_gates -> gated_resource_unavailable(conn, section, revision, blocking_gates)
          end

        _ ->
          conn
          |> redirect(to: Routes.static_page_path(conn, :not_found))
          |> halt()
      end
    else
      _ ->
        conn
    end
  end

  defp gated_resource_unavailable(conn, section, revision, blocking_gates) do
    {:ok, {previous, next}} =
      Oli.Delivery.PreviousNextIndex.retrieve(section, revision.resource_id)

    details = Gating.details(blocking_gates, format_datetime: format_datetime_fn(conn))

    conn
    |> put_view(OliWeb.DeliveryView)
    |> put_root_layout({OliWeb.LayoutView, "page.html"})
    |> put_status(403)
    |> render("gated_resource_unavailable.html",
      section_slug: section.slug,
      scripts: [],
      previous_page: previous,
      next_page: next,
      details: details
    )
    |> halt()
  end

  defp format_datetime_fn(conn) do
    fn datetime ->
      date(datetime, conn: conn, precision: :minutes)
    end
  end
end
