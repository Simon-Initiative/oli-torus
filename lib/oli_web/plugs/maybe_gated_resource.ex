defmodule Oli.Plugs.MaybeGatedResource do
  import Plug.Conn
  import Phoenix.Controller

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
          %{section: section} = conn.assigns

          if Gating.check_resource(section, resource_id) do
            conn
          else
            gated_resource_unavailable(conn)
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

  defp gated_resource_unavailable(conn) do
    conn
    |> put_view(OliWeb.DeliveryView)
    |> put_status(403)
    |> render("gated_resource_unavailable.html")
    |> halt()
  end
end
