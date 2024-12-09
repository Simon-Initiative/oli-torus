defmodule Oli.Plugs.MaybeGatedResource do
  import Plug.Conn
  import Phoenix.Controller
  import OliWeb.Common.FormatDateTime

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Sections
  alias Oli.Resources.Revision
  alias Oli.Delivery.Gating
  alias Oli.Delivery.Attempts.Core

  def init(opts), do: opts

  def call(conn, _opts) do
    with %{"section_slug" => section_slug, "revision_slug" => revision_slug} <- conn.path_params,
         revision <- DeliveryResolver.from_revision_slug(section_slug, revision_slug) do
      case revision do
        %Revision{resource_id: resource_id} ->
          enforce_gating(conn, resource_id, revision)

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

  defp enforce_gating(conn, resource_id, revision) do
    %{section: section, current_user: user, is_admin: is_admin} = conn.assigns

    if is_admin do
      conn
    else
      case Gating.blocked_by(section, user, resource_id) do
        [] ->
          conn

        blocking_gates ->
          # Graded resources are governed by the graded_resource_policy of gates. At this level
          # if there is at least one gate that has the `allows_nothing` policy we block access
          # to this graded resource
          if revision.graded do
            if Enum.any?(blocking_gates, fn gc -> gc.graded_resource_policy == :allows_nothing end) or
                 !Core.has_any_attempts?(user, section, resource_id) do
              gated_resource_unavailable(conn, section, revision, blocking_gates)
            else
              # These are the gates that apply at a more granular level that "allows_nothing"
              blocking_gates =
                Enum.filter(blocking_gates, fn gc ->
                  gc.graded_resource_policy == :allows_review
                end)

              conn
              |> Plug.Conn.assign(:blocking_gates, blocking_gates)
            end
          else
            gated_resource_unavailable(conn, section, revision, blocking_gates)
          end
      end
    end
  end

  defp gated_resource_unavailable(conn, section, revision, blocking_gates) do
    {:ok, {previous, next, current}, _} =
      Oli.Delivery.PreviousNextIndex.retrieve(section, revision.resource_id)

    details = Gating.details(blocking_gates, format_datetime: format_datetime_fn(conn))

    section_resource = Sections.get_section_resource(section.id, revision.resource_id)

    numbered_revisions = Sections.get_revision_indexes(section.slug)

    conn
    |> put_view(OliWeb.DeliveryView)
    |> put_root_layout(html: {OliWeb.Layouts, :delivery})
    |> put_layout(html: {OliWeb.Layouts, :page})
    |> put_status(403)
    |> render("gated_resource_unavailable.html",
      section_slug: section.slug,
      scripts: [],
      previous_page: previous,
      next_page: next,
      numbered_revisions: numbered_revisions,
      current_page: current,
      page_number: section_resource.numbering_level,
      preview_mode: false,
      revision: revision,
      title: revision.title,
      resource_slug: revision.slug,
      details: details,
      page_link_url: &Routes.page_delivery_path(conn, :page, section.slug, &1),
      container_link_url: &Routes.page_delivery_path(conn, :container, section.slug, &1),
      bib_app_params: %{
        bibReferences: []
      }
    )
    |> halt()
  end

  defp format_datetime_fn(conn) do
    fn datetime ->
      date(datetime, conn: conn, precision: :minutes)
    end
  end
end
