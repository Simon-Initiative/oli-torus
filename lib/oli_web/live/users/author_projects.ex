defmodule OliWeb.Users.AuthorProjects do
  use Phoenix.LiveComponent
  import Ecto.Query

  alias Oli.Repo
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Authors.AuthorProject
  alias Oli.Accounts.Author
  alias Oli.Authoring.Authors.ProjectRole
  alias OliWeb.Users.AuthorProjectsTableModel
  alias OliWeb.Common.SearchInput
  alias OliWeb.Common.SortableTable.StripedTable
  alias OliWeb.Common.Table.SortableTableModel
  alias Phoenix.LiveView.JS

  alias Oli.Publishing.Publications.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Resources.Revision

  @default_params %{
    offset: 0,
    limit: 10,
    sort_order: :asc,
    sort_by: :title,
    text_search: nil
  }

  def mount(socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    %{user: %{id: user_id}} = assigns

    projects = get_projects(user_id)

    {total_count, table_model} = build_table(projects, @default_params, assigns.ctx)

    socket =
      socket
      |> assign(assigns)
      |> assign(projects: projects)
      |> assign(table_model: table_model)
      |> assign(total_count: total_count)
      |> assign(params: @default_params)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div id={@id} class="flex flex-col gap-2">
      <%= if @projects != [] do %>
        <form
          for="search"
          phx-target={@myself}
          phx-change="search_project"
          class="w-56"
        >
          <SearchInput.render
            id="projects_search_input"
            name="project_title"
            text={@params.text_search}
          />
        </form>
      <% end %>
      <div class={[
        "w-full overflow-x-auto",
        if(@total_count > 10, do: "max-h-[570px] overflow-y-auto", else: "")
      ]}>
        <StripedTable.render
          model={@table_model}
          sort={JS.push("paged_table_sort", target: @myself)}
          additional_table_class="instructor_dashboard_table table_header_separated w-full"
          sticky_header_offset={0}
        />
      </div>
    </div>
    """
  end

  def handle_event(
        "search_project",
        %{"project_title" => project_title},
        socket
      ) do
    params =
      update_params(socket.assigns.params, %{
        text_search: project_title,
        offset: 0
      })

    do_table_update(socket, params)
  end

  def handle_event("paged_table_sort", %{"sort_by" => sort_by}, socket) do
    params =
      update_params(socket.assigns.params, %{
        sort_by: String.to_existing_atom(sort_by)
      })

    do_table_update(socket, params)
  end

  def handle_event(
        "paged_table_page_change",
        %{"limit" => limit, "offset" => offset},
        socket
      ) do
    params =
      update_params(socket.assigns.params, %{
        limit: String.to_integer(limit),
        offset: String.to_integer(offset)
      })

    do_table_update(socket, params)
  end

  defp get_projects(author_id) do
    most_recent_edit_per_project =
      from(p in Project,
        join: pub in Publication,
        on: p.id == pub.project_id,
        join: pub_res in PublishedResource,
        on: pub.id == pub_res.publication_id,
        join: rev in Revision,
        on: pub_res.revision_id == rev.id,
        where: rev.author_id == ^author_id,
        group_by: p.id,
        select: {p.id, fragment("MAX(?)", rev.updated_at)}
      )
      |> Repo.all()
      |> Enum.into(%{})

    from(p in Project,
      join: ap in AuthorProject,
      on: p.id == ap.project_id,
      join: pr in ProjectRole,
      on: ap.project_role_id == pr.id,
      join: a in Author,
      on: ap.author_id == a.id,
      where: a.id == ^author_id,
      select: %{
        id: p.id,
        title: p.title,
        role: pr.type,
        created_at: p.inserted_at,
        slug: p.slug
      }
    )
    |> Repo.all()
    |> Enum.map(fn project ->
      Map.put(project, :most_recent_edit, Map.get(most_recent_edit_per_project, project.id))
    end)
  end

  defp do_table_update(socket, params) do
    {total_count, table_model} = build_table(socket.assigns.projects, params, socket.assigns.ctx)

    {:noreply,
     assign(socket, %{
       table_model: table_model,
       params: params,
       total_count: total_count
     })}
  end

  defp build_table(projects, params, ctx) do
    {total_count, projects} = apply_filters(projects, params)
    {:ok, table_model} = AuthorProjectsTableModel.new(projects, ctx)

    table_model =
      Map.merge(table_model, %{
        rows: projects,
        sort_order: params.sort_order
      })
      |> SortableTableModel.update_sort_params(params.sort_by)

    {total_count, table_model}
  end

  defp apply_filters(projects, params) do
    projects =
      projects
      |> maybe_filter_by_text(params.text_search)
      |> sort_by(params.sort_by, params.sort_order)

    {length(projects), projects}
  end

  defp sort_by(projects, sort_by, sort_order) do
    case sort_by do
      sb when sb == :created_at ->
        projects
        |> Enum.sort_by(
          fn project -> Map.get(project, sort_by) end,
          {sort_order, DateTime}
        )

      sb when sb == :most_recent_edit ->
        {nulls, with_recent_edit} =
          Enum.split_with(projects, fn project -> Map.get(project, sort_by) == nil end)

        case sort_order do
          :asc ->
            Enum.sort_by(
              with_recent_edit,
              fn project -> Map.get(project, sort_by) end,
              {sort_order, DateTime}
            ) ++ nulls

          :desc ->
            nulls ++
              Enum.sort_by(
                with_recent_edit,
                fn project -> Map.get(project, sort_by) end,
                {sort_order, DateTime}
              )
        end

      _ ->
        Enum.sort_by(
          projects,
          fn project -> Map.get(project, sort_by) end,
          sort_order
        )
    end
  end

  defp maybe_filter_by_text(projects, nil), do: projects
  defp maybe_filter_by_text(projects, ""), do: projects

  defp maybe_filter_by_text(projects, text_search) do
    projects
    |> Enum.filter(fn project ->
      String.contains?(
        String.downcase(project.title),
        String.downcase(text_search)
      )
    end)
  end

  defp update_params(
         %{sort_by: current_sort_by, sort_order: current_sort_order} = params,
         %{
           sort_by: new_sort_by
         }
       )
       when current_sort_by == new_sort_by do
    toggled_sort_order = if current_sort_order == :asc, do: :desc, else: :asc
    update_params(params, %{sort_order: toggled_sort_order})
  end

  defp update_params(params, new_param) do
    Map.merge(params, new_param)
  end
end
