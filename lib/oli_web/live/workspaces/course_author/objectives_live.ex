defmodule OliWeb.Workspaces.CourseAuthor.ObjectivesLive do
  @moduledoc """
    LiveView implementation of an objective editor.
  """
  use OliWeb, :live_view
  use OliWeb.Common.SortableTable.TableHandlers
  use OliWeb.Common.Modal

  require Logger

  alias Oli.Accounts
  alias Oli.Authoring.Course
  alias Oli.Authoring.ObjectiveCoverage
  alias Oli.Authoring.Editing.ObjectiveEditor
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources
  alias Oli.Resources.Revision
  alias OliWeb.Icons
  alias OliWeb.Common.{Filter, FilterBox}
  alias OliWeb.Common.Listing, as: Table

  alias OliWeb.Workspaces.CourseAuthor.Objectives.{
    DeleteModal,
    FormModal,
    Listing,
    SelectExistingSubModal,
    SelectionsModal,
    SubObjectiveDeleteModal,
    TableModel
  }

  alias OliWeb.Workspaces.CourseAuthor.Objectives.ContentFilter

  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2
  @max_search_length 100
  @max_search_terms 10

  def live_path(socket, params) do
    params =
      params
      |> preserve_course_content_param(socket)
      |> expanded_params(Map.get(socket.assigns, :expanded_objective_slugs, MapSet.new()))

    ~p"/workspaces/course_author/#{socket.assigns.project.slug}/objectives?#{params}"
  end

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    project = socket.assigns.project
    author = socket.assigns.current_author

    {all_objectives, all_children, objectives, table_model} = build_objectives(project)

    socket =
      assign(socket,
        project: project,
        author: author,
        objectives: objectives,
        table_model: table_model,
        total_count: length(objectives),
        all_objectives: all_objectives,
        all_children: all_children,
        coverage_model: nil,
        coverage_status: :loading,
        coverage_load_ref: make_ref(),
        assessment_buckets: %{},
        course_content_open: false,
        course_content_selection: nil,
        course_content_scope_ids: nil,
        course_content_nodes: [],
        pending_sub_objective_delete_slugs: MapSet.new(),
        query: "",
        search_matching_ids: nil,
        expanded_objective_slugs: initial_expanded_objective_slugs(params),
        search_expanded_objective_slugs: MapSet.new(),
        offset: 0,
        limit: 20,
        resource_slug: project.slug,
        resource_title: project.title,
        params: params
      )
      |> attach_hook(:has_show_links_uri_hash, :handle_params, fn _params, uri, socket ->
        {:cont,
         assign_new(socket, :has_show_links_uri_hash, fn ->
           String.contains?(uri, "#show_links")
         end)}
      end)
      |> attach_hook(:objective_search_expansion, :handle_event, fn
        "change_search", %{"value" => value}, socket ->
          {:halt,
           assign(socket,
             query: normalize_search_query(value),
             search_matching_ids: nil
           )}

        "apply_search", _params, socket ->
          matching_ids =
            case socket.assigns.coverage_model do
              nil -> nil
              model -> matching_objective_ids(model, socket.assigns.query)
            end

          socket = assign(socket, search_matching_ids: matching_ids)
          {:cont, expand_search_results(socket, socket.assigns.query, matching_ids)}

        "reset_search", _params, socket ->
          {:cont,
           assign(socket,
             expanded_objective_slugs:
               MapSet.difference(
                 socket.assigns.expanded_objective_slugs,
                 Map.get(socket.assigns, :search_expanded_objective_slugs, MapSet.new())
               ),
             search_expanded_objective_slugs: MapSet.new(),
             search_matching_ids: MapSet.new()
           )}

        _event, _params, socket ->
          {:cont, socket}
      end)

    {:ok,
     start_async(socket, :objective_coverage, fn ->
       ObjectiveCoverage.load(project)
     end)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    {render_modal(assigns)}

    <FilterBox.render
      table_model={@table_model}
      show_sort={false}
      show_more_opts={false}
      class="mb-6 w-full"
      card_header_text="Learning Objectives"
      card_body_text={card_body_text(assigns)}
      card_body_text_class="mt-1 mb-4 text-Text-text-high"
      filter_opts_class="w-full"
    >
      <div class="flex w-full flex-wrap items-center gap-2 pt-6">
        <div class="w-full shrink-0 sm:w-56">
          <Filter.render
            change="change_search"
            reset="reset_search"
            apply="apply_search"
            query={@query}
            apply_icon={true}
          />
        </div>

        <form id="sort" phx-change="sort" class="flex h-9 shrink-0 items-center gap-2">
          <label for="select_sort" class="sr-only">Sort objectives</label>
          <div class="relative h-9 w-[86px] shrink-0">
            <select
              name="sort_by"
              id="select_sort"
              class="h-9 w-full appearance-none rounded-md border border-Border-border-default bg-Background-bg-primary px-[11px] pr-7 text-[13px] font-semibold leading-[19.5px] text-Text-text-high focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
            >
              <%= for column_spec <- @table_model.column_specs do %>
                <%= if column_spec.name != :action do %>
                  <option value={column_spec.name} selected={@table_model.sort_by_spec == column_spec}>
                    {column_spec.label}
                  </option>
                <% end %>
              <% end %>
            </select>
            <Icons.chevron_down
              width="9.5"
              height="5.5"
              variant="stroke"
              class="pointer-events-none absolute right-[10px] top-1/2 -translate-y-1/2 text-Icon-icon-default"
            />
          </div>
          <label class="inline-flex size-[30px] cursor-pointer items-center justify-center rounded-md border border-Border-border-default text-Text-text-high hover:bg-Surface-surface-secondary-hover focus-within:outline focus-within:outline-2 focus-within:outline-offset-2 focus-within:outline-Fill-Buttons-fill-primary">
            <span class="sr-only">Toggle sort direction</span>
            <.input
              type="checkbox"
              name="sort_order"
              class="sr-only"
              value={if @table_model.sort_order == :desc, do: "asc", else: "desc"}
            />
            <i class={"fa fa-sort-amount-#{if @table_model.sort_order == :desc, do: "up", else: "down"}"} />
          </label>
        </form>
        <div class="hidden h-6 w-px shrink-0 bg-Border-border-default xl:block" aria-hidden="true" />
        <ContentFilter.render
          nodes={@course_content_nodes}
          selected_ids={MapSet.new(get_in(@course_content_selection || %{}, [:selected_ids]) || [])}
          active_count={get_in(@course_content_selection || %{}, [:active_count]) || 0}
          open={@course_content_open}
          disabled={@coverage_status != :ready}
        />

        <div class="flex-1" />

        <.link
          id="download-objectives-csv"
          href={
            ~p"/workspaces/course_author/#{@project.slug}/objectives.csv?#{csv_export_params(@params)}"
          }
          download={"#{@project.slug}_learning_objectives.csv"}
          class="inline-flex h-9 shrink-0 items-center justify-center gap-2 rounded-md border border-Border-border-default bg-Background-bg-primary px-[13px] text-[13px] font-semibold leading-[19.5px] text-Text-text-high transition hover:bg-Surface-surface-secondary-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
        >
          <span class="inline-flex size-4 items-center justify-center text-current [&_svg]:size-4">
            <Icons.download stroke_class="stroke-current" />
          </span>
          Download CSV
        </.link>

        <button
          type="button"
          class="inline-flex h-[34px] shrink-0 items-center justify-center gap-2 rounded-md bg-Fill-Buttons-fill-primary px-4 text-[13px] font-semibold leading-[19.5px] text-Text-text-white shadow-[0px_2px_2px_rgba(0,52,99,0.10)] transition hover:bg-Fill-Buttons-fill-primary-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
          phx-click="display_new_modal"
        >
          <Icons.plus class="h-4 w-4 text-Icon-icon-white" path_class="stroke-current stroke-[3]" />
          New Objective
        </button>
      </div>
    </FilterBox.render>

    <div id="objectives-table" class="my-4">
      <%= case @coverage_status do %>
        <% :loading -> %>
          <div
            id="objective-coverage-loading"
            class="mb-3 flex items-center gap-2 text-sm text-Text-text-medium"
            role="status"
          >
            <.loader icon_class="text-Icon-icon-default" /> Loading objective coverage...
          </div>
        <% {:error, reason} -> %>
          <div
            id="objective-coverage-error"
            class="mb-3 rounded-md border border-Border-border-default bg-Background-bg-secondary px-3 py-2 text-sm text-Text-text-high"
            role="alert"
          >
            {coverage_error_message(reason)}
            <button
              type="button"
              phx-click="retry_coverage"
              class="ml-3 rounded text-Text-text-button underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
            >
              Retry
            </button>
          </div>
        <% :ready -> %>
          <span
            class="sr-only"
            id="objective-coverage-ready"
            role="status"
            aria-live="polite"
          >
            Objective coverage loaded
          </span>
      <% end %>

      <Table.render
        filter={@query}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}
        sort="sort"
        page_change="page_change"
        show_bottom_paging={false}
        additional_table_class="table-sm text-center"
        with_body={true}
        empty_state_text={empty_state_text(assigns)}
      >
        <div class="rounded-lg bg-Background-bg-secondary p-6 shadow-[0px_2px_5px_rgba(0,50,99,0.10)]">
          <Listing.render
            revision_history_link={
              (assigns[:has_show_links_uri_hash] || false) and
                Accounts.at_least_content_admin?(@author)
            }
            rows={@table_model.rows}
            expanded_slugs={@expanded_objective_slugs}
            pending_delete_slugs={@pending_sub_objective_delete_slugs}
            project_slug={@project.slug}
            offset={@offset}
            query={@query}
          />
        </div>
      </Table.render>
    </div>
    """
  end

  defp build_objectives(project) do
    all_objectives =
      project
      |> ObjectiveEditor.fetch_objective_mappings()
      |> Enum.map(& &1.revision)

    all_children =
      all_objectives
      |> Enum.reduce([], fn rev, acc -> rev.children ++ acc end)
      |> Enum.uniq()

    objectives =
      Enum.reduce(all_objectives, [], fn rev, acc ->
        case Enum.find(all_children, fn child_id -> child_id == rev.resource_id end) do
          nil ->
            mapped_children =
              Enum.map(rev.children, fn resource_id ->
                case Enum.find(all_objectives, fn rev -> rev.resource_id == resource_id end) do
                  nil ->
                    nil

                  child ->
                    Map.merge(child, base_coverage_fields())
                end
              end)

            [
              Map.merge(
                rev,
                %{
                  children: mapped_children,
                  sub_objectives_count: length(mapped_children),
                  page_attachments_count: 0,
                  page_attachments: [],
                  activity_attachments_count: 0,
                  formative_activity_attachments_count: 0,
                  summative_activity_attachments_count: 0,
                  assessment_bucket: :formative,
                  has_coverage: false,
                  coverage_details: []
                }
              )
            ] ++ acc

          _ ->
            acc
        end
      end)

    {:ok, table_model} = TableModel.new(objectives)

    {all_objectives, all_children, objectives, table_model}
  end

  defp base_coverage_fields do
    %{
      page_attachments_count: 0,
      page_attachments: [],
      activity_attachments_count: 0,
      formative_activity_attachments_count: 0,
      summative_activity_attachments_count: 0,
      assessment_bucket: :formative,
      has_coverage: false,
      coverage_details: []
    }
  end

  def filter_rows(socket, query, filter),
    do: filter_rows(socket, query, filter, socket.assigns.params)

  def filter_rows(socket, query, _filter, params) do
    query = normalize_search_query(query)

    case socket.assigns.coverage_model do
      nil ->
        if String.trim(query) == "", do: socket.assigns.objectives, else: []

      model ->
        matching_ids =
          if String.trim(query) == "" do
            nil
          else
            socket.assigns.search_matching_ids || matching_objective_ids(model, query)
          end

        content_selection =
          ObjectiveCoverage.normalize_curriculum_selection(model, params["course_content"])

        socket.assigns.objectives
        |> filter_objective_rows(matching_ids)
        |> filter_content_rows(model, content_selection)
    end
  end

  def after_table_params(params, socket) do
    params =
      if Map.has_key?(params, "course_content") do
        Map.put(socket.assigns.params, "course_content", params["course_content"])
      else
        Map.delete(socket.assigns.params, "course_content")
      end

    selection =
      case socket.assigns.coverage_model do
        nil -> nil
        model -> ObjectiveCoverage.normalize_curriculum_selection(model, params["course_content"])
      end

    params =
      case selection do
        nil -> params
        selection -> put_course_content_param(params, selection.selected_ids)
      end

    scope_ids =
      case {socket.assigns.coverage_model, selection} do
        {model, %{page_ids: page_ids}} when not is_nil(model) ->
          ObjectiveCoverage.objective_scope_for_pages(model, page_ids)

        _ ->
          []
      end

    assign(socket,
      course_content_selection: selection,
      course_content_scope_ids: scope_ids,
      params: params
    )
  end

  defp empty_state_text(%{course_content_selection: %{selected_ids: selected_ids}})
       when selected_ids != [],
       do: "No learning objectives match the selected course content."

  defp empty_state_text(assigns) do
    if assigns.query == "", do: "None exist", else: "No learning objectives match your search."
  end

  def handle_event("toggle_course_content_filter", _params, socket) do
    {:noreply, assign(socket, course_content_open: !socket.assigns.course_content_open)}
  end

  def handle_event("close_course_content_filter", _params, socket) do
    {:noreply, assign(socket, course_content_open: false)}
  end

  def handle_event(
        "toggle_course_content_item",
        %{"resource_id" => resource_id},
        socket
      ) do
    with model when not is_nil(model) <- socket.assigns.coverage_model,
         {:ok, resource_id} <- parse_objective_id(resource_id),
         true <- Map.has_key?(model.curriculum_by_id, resource_id) do
      current_ids =
        MapSet.new(get_in(socket.assigns, [:course_content_selection, :selected_ids]) || [])

      selected_ids =
        if MapSet.member?(current_ids, resource_id) do
          MapSet.delete(current_ids, resource_id)
        else
          MapSet.put(current_ids, resource_id)
        end

      params =
        socket.assigns.params
        |> put_course_content_param(MapSet.to_list(selected_ids))
        |> Map.put("offset", 0)

      params =
        if MapSet.size(selected_ids) == 0 do
          Map.put(params, "clear_course_content", true)
        else
          params
        end

      {:noreply, push_patch(socket, to: live_path(socket, params), replace: true)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("clear_course_content_filter", _params, socket) do
    params =
      socket.assigns.params
      |> Map.put("clear_course_content", true)
      |> Map.put("offset", 0)

    {:noreply, push_patch(socket, to: live_path(socket, params), replace: true)}
  end

  def handle_event("hide_modal", _, socket),
    do: {:noreply, hide_modal(socket, modal_assigns: nil)}

  def handle_event("display_new_modal", _, socket),
    do: new_modal(Resources.change_revision(%Revision{}) |> to_form(), socket)

  def handle_event("retry_coverage", _, socket) do
    socket = cancel_async(socket, :objective_coverage)
    project = socket.assigns.project

    {:noreply,
     assign(socket,
       coverage_model: nil,
       coverage_status: :loading,
       search_matching_ids: nil
     )
     |> start_async(:objective_coverage, fn ->
       ObjectiveCoverage.load(project)
     end)}
  end

  def handle_event("display_new_sub_modal", %{"slug" => slug}, socket),
    do: new_modal(Resources.change_revision(%Revision{parent_slug: slug}) |> to_form(), socket)

  def handle_event("toggle_objective", %{"slug" => slug}, socket) do
    expanded_objective_slugs =
      toggle_expanded_objective_slug(socket.assigns.expanded_objective_slugs, slug)

    socket = assign(socket, expanded_objective_slugs: expanded_objective_slugs)

    {:noreply,
     socket
     |> push_patch(
       to: live_path(socket, socket.assigns.params),
       replace: true
     )}
  end

  def handle_event(
        "set_assessment_bucket",
        %{"objective_id" => objective_id, "bucket" => bucket},
        socket
      ) do
    with {:ok, objective_id} <- parse_objective_id(objective_id),
         {:ok, bucket} <- normalize_assessment_bucket(bucket),
         model when not is_nil(model) <- socket.assigns.coverage_model,
         coverage when not is_nil(coverage) <- ObjectiveCoverage.coverage(model, objective_id),
         true <- tagged_content?(coverage) do
      assessment_buckets = Map.put(socket.assigns.assessment_buckets, objective_id, bucket)

      objectives =
        update_objective_coverage(
          socket.assigns.objectives,
          model,
          assessment_buckets,
          objective_id
        )

      {:ok, table_model} = TableModel.new(objectives)

      socket = assign(socket, objectives: objectives, table_model: table_model)
      refresh_table_state(socket)
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event(
        "new",
        %{"revision" => %{"title" => title, "parent_slug" => parent_slug}},
        socket
      ) do
    socket = clear_flash(socket)

    project = socket.assigns.project

    flash_fn =
      case ObjectiveEditor.add_new(
             %{title: title},
             socket.assigns.author,
             project,
             parent_slug
           ) do
        {:ok, _} ->
          fn socket -> put_flash(socket, :info, "Objective successfully created") end

        {:error, _error} ->
          fn socket -> put_flash(socket, :error, "Could not create objective") end
      end

    return_updated_data(project, flash_fn, socket)
  end

  def handle_event("display_edit_modal", %{"slug" => slug}, socket) do
    changeset =
      socket.assigns.project.slug
      |> AuthoringResolver.from_revision_slug(slug)
      |> Resources.change_revision()

    modal_assigns = %{
      id: "edit_objective_modal",
      form: to_form(changeset),
      action: :edit,
      on_click: "edit"
    }

    modal = fn assigns ->
      ~H"""
      <FormModal.render {@modal_assigns} />
      """
    end

    {:noreply,
     show_modal(
       socket,
       modal,
       modal_assigns: modal_assigns
     )}
  end

  def handle_event("edit", %{"revision" => %{"title" => title, "slug" => slug}}, socket) do
    socket = clear_flash(socket)

    project = socket.assigns.project

    flash_fn =
      case ObjectiveEditor.edit(
             slug,
             %{title: title},
             socket.assigns.author,
             project
           ) do
        {:ok, _} ->
          fn socket -> put_flash(socket, :info, "Objective successfully updated") end

        {:error, %Ecto.Changeset{} = _changeset} ->
          fn socket -> put_flash(socket, :error, "Could not update objective") end
      end

    return_updated_data(project, flash_fn, socket)
  end

  def handle_event("display_add_existing_sub_modal", %{"slug" => slug}, socket) do
    %{project: project, all_children: all_children, all_objectives: all_objectives} =
      socket.assigns

    %{children: objective_children} = AuthoringResolver.from_revision_slug(project.slug, slug)

    sub_objectives =
      Enum.map(all_children -- objective_children, fn resource_id ->
        Enum.find(all_objectives, fn obj -> obj.resource_id == resource_id end)
      end)

    modal_assigns = %{
      id: "select_existing_sub_modal",
      parent_slug: slug,
      sub_objectives: sub_objectives,
      add: "add_existing_sub"
    }

    modal = fn assigns ->
      ~H"""
      <.live_component id="select_existing_sub_modal" module={SelectExistingSubModal} {@modal_assigns} />
      """
    end

    {:noreply,
     show_modal(
       socket,
       modal,
       modal_assigns: modal_assigns
     )}
  end

  def handle_event("display_delete_modal", %{"slug" => slug}, socket) do
    socket = clear_flash(socket)

    project = socket.assigns.project

    %{children: children, resource_id: resource_id} =
      AuthoringResolver.from_revision_slug(project.slug, slug)

    if length(children) > 0 do
      {:noreply,
       put_flash(socket, :error, "Could not remove objective if it has sub-objectives associated")}
    else
      publication_id = Oli.Publishing.get_unpublished_publication_id!(project.id)

      case Oli.Publishing.find_objective_in_selections(resource_id, publication_id) do
        [] ->
          modal_assigns = %{
            id: "delete_objective_modal",
            slug: slug,
            project: project,
            attachment_summary:
              ObjectiveEditor.preview_objective_detatchment(resource_id, project)
          }

          modal = fn assigns ->
            ~H"""
            <DeleteModal.render {@modal_assigns} />
            """
          end

          {:noreply,
           show_modal(
             socket,
             modal,
             modal_assigns: modal_assigns
           )}

        selections ->
          modal_assigns = %{
            id: "selections_modal",
            selections: selections,
            project_slug: project.slug
          }

          modal = fn assigns ->
            ~H"""
            <SelectionsModal.render {@modal_assigns} />
            """
          end

          {:noreply,
           assign(
             socket,
             modal,
             modal_assigns: modal_assigns
           )}
      end
    end
  end

  def handle_event(
        "display_sub_objective_delete_modal",
        %{"slug" => slug, "parent_slug" => parent_slug} = params,
        socket
      ) do
    socket = clear_flash(socket)
    title = Map.get(params, "title", "this sub-objective")

    modal_assigns = %{
      id: "delete_sub_objective_modal",
      slug: slug,
      parent_slug: parent_slug,
      title: title
    }

    modal = fn assigns ->
      ~H"""
      <SubObjectiveDeleteModal.render {@modal_assigns} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event("delete", %{"slug" => slug} = params, socket) do
    socket = clear_flash(socket)

    parent_slug = Map.get(params, "parent_slug", "")
    %{project: project, author: author} = socket.assigns

    flash_fn = delete_objective(slug, parent_slug, project, author)

    return_updated_data(project, flash_fn, socket)
  end

  def handle_event(
        "delete_sub_objective",
        %{"slug" => slug, "parent_slug" => parent_slug},
        socket
      ) do
    socket = clear_flash(socket)
    %{project: %{slug: project_slug}, author: %{email: author_email}} = socket.assigns

    if MapSet.member?(socket.assigns.pending_sub_objective_delete_slugs, slug) do
      {:noreply,
       socket
       |> hide_modal(modal_assigns: nil)
       |> put_flash(:error, "That sub-objective is already being deleted")}
    else
      socket =
        socket
        |> assign(
          pending_sub_objective_delete_slugs:
            MapSet.put(socket.assigns.pending_sub_objective_delete_slugs, slug)
        )
        |> hide_modal(modal_assigns: nil)
        |> start_async({:delete_sub_objective, slug}, fn ->
          project = Course.get_project_by_slug(project_slug)
          author = Accounts.get_author_by_email(author_email)

          delete_objective_result(slug, parent_slug, project, author)
        end)

      {:noreply, socket}
    end
  end

  def handle_event(
        "add_existing_sub",
        %{"slug" => slug, "parent_slug" => parent_slug} = _params,
        socket
      ) do
    socket = clear_flash(socket)

    %{project: project, author: author} = socket.assigns

    flash_fn =
      case ObjectiveEditor.add_new_parent_for_sub_objective(
             slug,
             parent_slug,
             project.slug,
             author
           ) do
        {:ok, _revision} ->
          fn socket -> put_flash(socket, :info, "Sub-objective successfully added") end

        {:error, _} ->
          fn socket -> put_flash(socket, :error, "Could not add sub-objective") end
      end

    return_updated_data(project, flash_fn, socket)
  end

  defp filter_objective_rows(rows, nil), do: rows

  defp filter_objective_rows(rows, matching_ids) do
    Enum.filter(rows, fn objective ->
      objective.resource_id in matching_ids or
        Enum.any?(objective.children, fn child ->
          not is_nil(child) and child.resource_id in matching_ids
        end)
    end)
  end

  defp filter_content_rows(rows, _model, %{selected_ids: []}), do: rows

  defp filter_content_rows(rows, model, selection) do
    direct_ids = ObjectiveCoverage.objective_ids_for_pages(model, selection.page_ids)
    visible_ids = ObjectiveCoverage.objective_scope_for_pages(model, selection.page_ids)

    rows
    |> Enum.filter(fn objective ->
      objective.resource_id in visible_ids or
        Enum.any?(objective.children, fn child ->
          not is_nil(child) and child.resource_id in direct_ids
        end)
    end)
    |> Enum.map(fn objective ->
      Map.update!(objective, :children, fn children ->
        Enum.filter(children, fn child ->
          not is_nil(child) and child.resource_id in direct_ids
        end)
      end)
    end)
  end

  defp matching_objective_ids(model, query) do
    model
    |> ObjectiveCoverage.search(normalize_search_query(query))
    |> Enum.map(& &1.objective_id)
    |> MapSet.new()
  end

  defp normalize_search_query(query) when is_binary(query) do
    query
    |> String.slice(0, @max_search_length)
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(@max_search_terms)
    |> Enum.join(" ")
  end

  defp normalize_search_query(_query), do: ""

  defp expand_search_results(socket, query, matching_ids) do
    case socket.assigns.coverage_model do
      nil ->
        socket

      _model when is_binary(query) ->
        if String.trim(query) == "" do
          socket
        else
          auto_expanded =
            socket.assigns.objectives
            |> Enum.flat_map(fn objective ->
              child_ids =
                objective.children
                |> Enum.reject(&is_nil/1)
                |> Enum.map(& &1.resource_id)

              if objective.resource_id in matching_ids or
                   Enum.any?(child_ids, &(&1 in matching_ids)) do
                matching_child_slugs =
                  objective.children
                  |> Enum.filter(fn child ->
                    not is_nil(child) and child.resource_id in matching_ids
                  end)
                  |> Enum.map(& &1.slug)

                [objective.slug | matching_child_slugs]
              else
                []
              end
            end)
            |> Enum.reject(&is_nil/1)
            |> MapSet.new()

          previous_auto_expanded =
            Map.get(socket.assigns, :search_expanded_objective_slugs, MapSet.new())

          manually_expanded =
            MapSet.difference(socket.assigns.expanded_objective_slugs, previous_auto_expanded)

          search_expanded = MapSet.difference(auto_expanded, manually_expanded)

          assign(socket,
            expanded_objective_slugs: MapSet.union(manually_expanded, auto_expanded),
            search_expanded_objective_slugs: search_expanded
          )
        end

      _model ->
        socket
    end
  end

  defp return_updated_data(project, flash_fn, socket) do
    {all_objectives, all_children, objectives, table_model} =
      build_objectives(project)

    socket = cancel_async(socket, :objective_coverage)

    objective_slugs =
      objectives
      |> Enum.flat_map(fn objective ->
        [objective | Enum.reject(objective.children, &is_nil/1)]
      end)
      |> Enum.map(& &1.slug)
      |> MapSet.new()

    expanded_objective_slugs =
      MapSet.intersection(socket.assigns.expanded_objective_slugs, objective_slugs)

    socket =
      socket
      |> assign(
        objectives: objectives,
        table_model: table_model,
        total_count: length(objectives),
        all_objectives: all_objectives,
        all_children: all_children,
        coverage_model: nil,
        coverage_status: :loading,
        assessment_buckets: socket.assigns.assessment_buckets,
        course_content_selection: nil,
        search_matching_ids: nil,
        expanded_objective_slugs: expanded_objective_slugs
      )
      |> flash_fn.()
      |> hide_modal(modal_assigns: nil)
      |> start_async(:objective_coverage, fn -> ObjectiveCoverage.load(project) end)

    {:noreply, push_patch(socket, to: live_path(socket, socket.assigns.params))}
  end

  defp csv_export_params(params) do
    Map.take(params, ["query", "filter", "sort_by", "sort_order"])
  end

  defp card_body_text(assigns) do
    ~H"""
    Learning objectives define the knowledge and skills students should demonstrate throughout your course. Use this page to organize objectives and review coverage of formative (practice) and summative (scored) activities and pages. Refer to the
    <a
      class="external text-Text-text-button hover:text-Text-text-button"
      href="https://www.cmu.edu/teaching/designteach/design/learningobjectives.html"
      rel="noopener"
      target="_blank"
    >
      CMU Eberly Center guide on learning objectives
    </a>
    to learn more about the importance of attaching learning objectives to pages and activities.
    """
  end

  defp new_modal(form, socket) do
    modal_assigns = %{
      id: "new_objective_modal",
      form: form,
      action: :new,
      on_click: "new"
    }

    modal = fn assigns ->
      ~H"""
      <FormModal.render {@modal_assigns} />
      """
    end

    {:noreply,
     show_modal(
       socket,
       modal,
       modal_assigns: modal_assigns
     )}
  end

  defp delete_objective(slug, parent_slug, project, author) do
    case delete_objective_result(slug, parent_slug, project, author) do
      :ok -> fn socket -> put_flash(socket, :info, "Objective successfully removed") end
      :error -> fn socket -> put_flash(socket, :error, "Could not remove objective") end
    end
  end

  defp delete_objective_result(slug, parent_slug, project, author) do
    %{resource_id: resource_id} = AuthoringResolver.from_revision_slug(project.slug, slug)

    ObjectiveEditor.detach_objective(resource_id, project, author)

    objectives =
      project
      |> ObjectiveEditor.fetch_objective_mappings()
      |> Enum.map(& &1.revision)

    {parents, parent_to_detach_slug} =
      Enum.reduce(objectives, {[], ""}, fn objective, {parents, parent_to_detach_slug} ->
        case Enum.member?(objective.children, resource_id) do
          false ->
            {parents, parent_to_detach_slug}

          true ->
            if objective.slug == parent_slug,
              do: {[objective | parents], objective.slug},
              else: {[objective | parents], parent_to_detach_slug}
        end
      end)

    delete_fn =
      if length(parents) <= 1 do
        fn ->
          ObjectiveEditor.delete(
            slug,
            author,
            project,
            parent_objective(project, parent_to_detach_slug)
          )
        end
      else
        fn ->
          case parent_objective(project, parent_to_detach_slug) do
            nil ->
              {:error, :not_found}

            parent_objective ->
              ObjectiveEditor.remove_sub_objective_from_parent(
                slug,
                author,
                project,
                parent_objective
              )
          end
        end
      end

    case delete_fn.() do
      {:ok, _} -> :ok
      {:error, _error} -> :error
    end
  end

  @impl Phoenix.LiveView
  def handle_async(:objective_coverage, {:ok, result}, socket),
    do: apply_coverage_result(result, socket)

  def handle_async(:objective_coverage, {:exit, {exception, stacktrace}}, socket)
      when is_exception(exception) do
    Logger.error(
      "Objective coverage load failed: #{Exception.message(exception)}",
      stacktrace: stacktrace
    )

    apply_coverage_result({:error, :coverage_load_failed}, socket)
  end

  def handle_async(:objective_coverage, {:exit, reason}, socket) do
    Logger.error("Objective coverage load exited: #{inspect(reason)}")
    apply_coverage_result({:error, :coverage_load_failed}, socket)
  end

  def handle_async({:delete_sub_objective, slug}, result, socket) do
    if MapSet.member?(socket.assigns.pending_sub_objective_delete_slugs, slug) do
      flash_type =
        case result do
          {:ok, flash_type} ->
            flash_type

          {:exit, reason} ->
            Logger.error("Sub-objective deletion failed: #{inspect(reason)}")
            :error
        end

      flash_fn =
        case flash_type do
          :ok -> fn socket -> put_flash(socket, :info, "Objective successfully removed") end
          :error -> fn socket -> put_flash(socket, :error, "Could not remove objective") end
        end

      socket =
        assign(socket,
          pending_sub_objective_delete_slugs:
            MapSet.delete(socket.assigns.pending_sub_objective_delete_slugs, slug)
        )

      return_updated_data(socket.assigns.project, flash_fn, socket)
    else
      {:noreply, socket}
    end
  end

  # Kept for compatibility with in-flight messages from older LiveView
  # processes during a rolling deployment. New coverage loads use handle_async/3.
  @impl Phoenix.LiveView
  def handle_info({:objective_coverage_loaded, load_ref, result}, socket) do
    if load_ref == socket.assigns.coverage_load_ref do
      apply_coverage_result(result, socket)
    else
      {:noreply, socket}
    end
  end

  defp parent_objective(_project, ""), do: nil

  defp parent_objective(project, slug),
    do: AuthoringResolver.from_revision_slug(project.slug, slug)

  defp apply_coverage_result({:ok, model}, socket) do
    assessment_buckets =
      selected_assessment_buckets(
        socket.assigns.assessment_buckets,
        model,
        socket.assigns.objectives
      )

    objectives = apply_coverage(socket.assigns.objectives, model, assessment_buckets)
    {:ok, table_model} = TableModel.new(objectives)

    socket =
      assign(socket,
        objectives: objectives,
        table_model: table_model,
        total_count: length(objectives),
        coverage_model: model,
        coverage_status: :ready,
        course_content_nodes: ObjectiveCoverage.curriculum_nodes(model),
        course_content_selection:
          ObjectiveCoverage.normalize_curriculum_selection(
            model,
            socket.assigns.params["course_content"]
          ),
        assessment_buckets: assessment_buckets,
        search_matching_ids:
          if(String.trim(socket.assigns.query) == "",
            do: MapSet.new(),
            else: matching_objective_ids(model, socket.assigns.query)
          )
      )

    refresh_table_state(socket)
  end

  defp apply_coverage_result({:error, reason}, socket) do
    {:noreply,
     assign(socket,
       coverage_model: nil,
       coverage_status: {:error, reason},
       course_content_selection: nil,
       course_content_nodes: []
     )}
  end

  defp update_objective_coverage(objectives, model, assessment_buckets, objective_id) do
    Enum.map(objectives, fn objective ->
      cond do
        objective.resource_id == objective_id ->
          Map.merge(objective, coverage_fields(objective, model, assessment_buckets))

        true ->
          Map.update!(objective, :children, fn children ->
            Enum.map(children, fn
              %{resource_id: ^objective_id} = child ->
                Map.merge(child, coverage_fields(child, model, assessment_buckets))

              child ->
                child
            end)
          end)
      end
    end)
  end

  defp refresh_table_state(socket) do
    params =
      Map.update(socket.assigns.params, "sidebar_expanded", "true", fn
        true -> "true"
        false -> "false"
        value -> value
      end)

    handle_params(params, nil, socket)
  end

  defp apply_coverage(objectives, model, assessment_buckets) do
    Enum.map(objectives, fn objective ->
      objective
      |> Map.merge(coverage_fields(objective, model, assessment_buckets))
      |> Map.update!(:children, fn children ->
        Enum.map(children, fn
          nil -> nil
          child -> Map.merge(child, coverage_fields(child, model, assessment_buckets))
        end)
      end)
    end)
  end

  defp coverage_fields(objective, model, assessment_buckets) do
    coverage = ObjectiveCoverage.coverage(model, objective.resource_id) || %{}
    formative = Map.get(coverage, :formative_activity_count, 0)
    summative = Map.get(coverage, :summative_activity_count, 0)
    bucket = Map.get(assessment_buckets, objective.resource_id, :formative)

    %{
      page_attachments_count: Map.get(coverage, :page_count, 0),
      page_attachments: [],
      activity_attachments_count: formative + summative,
      formative_activity_attachments_count: formative,
      summative_activity_attachments_count: summative,
      sub_objectives_count: Map.get(coverage, :sub_objective_count, 0),
      assessment_bucket: bucket,
      has_coverage: tagged_content?(coverage),
      coverage_details: ObjectiveCoverage.details(model, objective.resource_id, bucket)
    }
  end

  defp selected_assessment_buckets(existing, model, objectives) do
    objectives
    |> Enum.flat_map(fn objective -> [objective | Enum.reject(objective.children, &is_nil/1)] end)
    |> Map.new(fn row -> {row.resource_id, Map.get(existing, row.resource_id, :formative)} end)
    |> Enum.filter(fn {objective_id, _bucket} ->
      model
      |> ObjectiveCoverage.coverage(objective_id)
      |> tagged_content?()
    end)
    |> Map.new()
  end

  defp tagged_content?(nil), do: false

  defp tagged_content?(coverage) do
    Map.get(coverage, :page_count, 0) > 0 or
      Map.get(coverage, :formative_activity_count, 0) > 0 or
      Map.get(coverage, :summative_activity_count, 0) > 0
  end

  defp parse_objective_id(objective_id) when is_integer(objective_id), do: {:ok, objective_id}

  defp parse_objective_id(objective_id) when is_binary(objective_id) do
    case Integer.parse(objective_id) do
      {id, ""} when id > 0 -> {:ok, id}
      _ -> :error
    end
  end

  defp parse_objective_id(_), do: :error

  defp normalize_assessment_bucket("formative"), do: {:ok, :formative}
  defp normalize_assessment_bucket("summative"), do: {:ok, :summative}
  defp normalize_assessment_bucket(_), do: :error

  defp coverage_error_message(:project_not_found), do: "The project could not be found."

  defp coverage_error_message(:working_publication_not_found),
    do: "No working publication is available."

  defp coverage_error_message(:multiple_working_publications),
    do: "The project has multiple working publications."

  defp coverage_error_message(:invalid_project), do: "The project is invalid."
  defp coverage_error_message(_reason), do: "Objective coverage could not be loaded."

  # Keep expanded LO state shareable in the URL while accepting legacy selected links.
  defp initial_expanded_objective_slugs(params) do
    expanded_slugs =
      params
      |> Map.get("expanded", "")
      |> String.split(",", trim: true)
      |> MapSet.new()

    case Map.get(params, "selected", "") do
      "" -> expanded_slugs
      slug -> MapSet.put(expanded_slugs, slug)
    end
  end

  defp preserve_course_content_param(params, socket) do
    case Map.pop(params, "clear_course_content") do
      {true, params} ->
        Map.delete(params, "course_content")

      {_clear, params} ->
        if Map.has_key?(params, "course_content") do
          params
        else
          selected_ids = get_in(socket.assigns, [:course_content_selection, :selected_ids]) || []
          put_course_content_param(params, selected_ids)
        end
    end
  end

  defp put_course_content_param(params, selected_ids) do
    selected_ids = selected_ids |> Enum.map(&to_string/1) |> Enum.sort()

    case Enum.join(selected_ids, ",") do
      "" -> Map.delete(params, "course_content")
      value -> Map.put(params, "course_content", value)
    end
  end

  defp toggle_expanded_objective_slug(expanded_objective_slugs, slug) do
    case MapSet.member?(expanded_objective_slugs, slug) do
      true -> MapSet.delete(expanded_objective_slugs, slug)
      false -> MapSet.put(expanded_objective_slugs, slug)
    end
  end

  # Build route params from the current table state and the expanded LO set.
  defp expanded_params(params, expanded_objective_slugs) do
    expanded_param =
      expanded_objective_slugs
      |> MapSet.to_list()
      |> Enum.sort()
      |> Enum.join(",")

    params = Map.delete(params, "selected")

    case expanded_param do
      "" -> Map.delete(params, "expanded")
      expanded_param -> Map.put(params, "expanded", expanded_param)
    end
  end
end
