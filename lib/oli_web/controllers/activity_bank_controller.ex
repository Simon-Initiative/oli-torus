defmodule OliWeb.ActivityBankController do
  use OliWeb, :controller

  alias Oli.Accounts
  alias OliWeb.Common.Breadcrumb

  alias Oli.Activities.Realizer.Logic
  alias Oli.Activities.Realizer.Query
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Activities.Realizer.Query.Result
  alias OliWeb.Common.PagingParams

  @doc false
  def index(conn, %{
        "project_id" => project_slug
      }) do
    author = conn.assigns[:current_author]
    is_admin? = Accounts.is_admin?(author)

    case Oli.Authoring.Editing.BankEditor.create_context(project_slug, author) do
      {:ok, context} ->
        render(conn, "index.html",
          active: :bank,
          context: context,
          breadcrumbs: [Breadcrumb.new(%{full_title: "Activity Bank"})],
          project_slug: project_slug,
          is_admin?: is_admin?,
          scripts: Oli.Activities.get_activity_scripts(),
          title: "Activity Bank | " <> conn.assigns.project.title
        )

      _ ->
        OliWeb.ResourceController.render_not_found(conn, project_slug)
    end
  end

  def preview(conn, %{
        "section_slug" => section_slug,
        "revision_slug" => revision_slug,
        "selection_id" => selection_id
      }) do
    user = conn.assigns.current_user
    author = conn.assigns.current_author
    is_admin? = Accounts.is_admin?(author)

    offset =
      Map.get(conn.query_params, "offset", "0")
      |> String.to_integer()

    if Oli.Delivery.Sections.is_instructor?(user, section_slug) or is_admin? do
      case retrieve(section_slug, revision_slug, selection_id, offset) do
        {:ok, {revision, selection, activities, total_count}} ->
          activities =
            Enum.map(activities, fn a ->
              encoded = Jason.encode!(a.content)

              Map.put(a, :encoded_model, encoded)
            end)

          activity_types = Oli.Activities.list_activity_registrations()

          activity_types_map =
            Enum.reduce(activity_types, %{}, fn e, m -> Map.put(m, e.id, e) end)

          paging_params = PagingParams.calculate(total_count, offset, 5, 5)

          render_context = %Oli.Rendering.Context{
            activity_map: activity_types_map,
            revision_slug: revision.slug,
            section_slug: section_slug
          }

          rendered_selection =
            Oli.Rendering.Content.Selection.render(render_context, selection, false)
            |> IO.iodata_to_binary()

          conn = put_root_layout(conn, {OliWeb.LayoutView, "delivery.html"})

          render(conn, "preview.html",
            title: "Activity Bank Selection Preview",
            rendered_selection: rendered_selection,
            paging: paging_params,
            limit: 5,
            section_slug: section_slug,
            activities: activities,
            activity_types: activity_types_map,
            revision: revision,
            revision_slug: revision.slug,
            selection_id: selection_id,
            selection: selection,
            total_count: total_count,
            offset: offset,
            scripts: Enum.map(activity_types, fn a -> a.authoring_script end)
          )

        _ ->
          render(conn, OliWeb.PageDeliveryView, "error.html")
      end
    else
      render(conn, OliWeb.PageDeliveryView, "not_authorized.html")
    end
  end

  defp retrieve(section_slug, revision_slug, selection_id, offset) do
    case Oli.Publishing.DeliveryResolver.from_revision_slug(section_slug, revision_slug) do
      nil ->
        {:error, {:not_found}}

      revision ->
        case Oli.Resources.PageContent.flat_filter(revision.content, fn c ->
               c["type"] == "selection" and c["id"] == selection_id
             end) do
          [] ->
            {:error, {:not_found}}

          [selection] ->
            publication_id =
              Oli.Publishing.get_publication_id_for_resource(
                section_slug,
                revision.resource_id
              )

            parse_and_query(section_slug, selection, revision, publication_id, offset)
        end
    end
  end

  defp parse_and_query(
         section_slug,
         %{"logic" => logic} = selection,
         revision,
         publication_id,
         offset
       ) do
    case Logic.parse(logic) do
      {:ok, %Logic{} = logic} ->
        case Query.execute(
               logic,
               %Source{
                 publication_id: publication_id,
                 blacklisted_activity_ids: [],
                 section_slug: section_slug
               },
               %Oli.Activities.Realizer.Query.Paging{offset: offset, limit: 5}
             ) do
          {:ok, %Result{rows: rows, totalCount: total}} ->
            {:ok, {revision, selection, rows, total}}

          e ->
            e
        end
    end
  end
end
