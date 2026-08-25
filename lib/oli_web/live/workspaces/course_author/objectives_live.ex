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

  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2

  def live_path(socket, params) do
    params =
      expanded_params(params, Map.get(socket.assigns, :expanded_objective_slugs, MapSet.new()))

    ~p"/workspaces/course_author/#{socket.assigns.project.slug}/objectives?#{params}"
  end

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    project = socket.assigns.project
    author = socket.assigns.current_author

    {all_objectives, all_children, objectives, table_model} = build_objectives(project)
    load_ref = make_ref()
    start_coverage_load(project, load_ref)

    {:ok,
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
       coverage_load_ref: load_ref,
       assessment_buckets: %{},
       pending_sub_objective_delete_slugs: MapSet.new(),
       query: "",
       expanded_objective_slugs: initial_expanded_objective_slugs(params),
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
     end)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    {render_modal(assigns)}

    <div class="mb-6 w-full">
      <h2 id="header_id" class="pb-2 text-[28px] font-normal leading-[42px] text-Text-text-high">
        Learning Objectives
      </h2>
      <p class="mb-6 mt-1 text-[16px] leading-6 text-Text-text-high">
        Learning objectives help you to organize course content and determine appropriate assessments and instructional strategies. Refer to the
        <a
          class="text-Text-text-button hover:underline"
          href="https://www.cmu.edu/teaching/designteach/design/learningobjectives.html"
          rel="noopener"
          target="_blank"
        >
          CMU Eberly Center guide on learning objectives
          <span class="sr-only"> (opens in a new tab)</span>
        </a>
        to learn more about the importance of attaching learning objectives to pages and activities.
      </p>

      <div class="flex flex-wrap items-center gap-3">
        <div class="relative flex h-9 w-full items-center gap-3 rounded-md border border-Border-border-default bg-Specially-Tokens-Fill-fill-input px-2 sm:w-56">
          <Icons.search class="shrink-0 text-Icon-icon-default" />
          <input
            type="text"
            class="min-w-0 flex-1 border-0 bg-transparent p-0 text-sm text-Text-text-high outline-none placeholder:text-Text-text-low-alpha"
            placeholder="Search..."
            phx-change="change_search"
            phx-blur="apply_search"
            value={@query}
          />
          <button
            :if={@query != ""}
            id="reset_search"
            type="button"
            phx-click="reset_search"
            class="inline-flex size-6 shrink-0 items-center justify-center rounded-full text-Text-text-low-alpha hover:bg-Surface-surface-secondary-hover hover:text-Text-text-high focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
            aria-label="Clear search"
          >
            ×
          </button>
        </div>

        <form id="sort" phx-change="sort" class="flex h-9 items-center gap-2">
          <label for="select_sort" class="sr-only">Sort objectives</label>
          <select
            name="sort_by"
            id="select_sort"
            class="h-9 rounded-[3px] border border-Border-border-default bg-Background-bg-primary px-2 text-sm font-semibold text-Text-text-high focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
          >
            <%= for column_spec <- @table_model.column_specs do %>
              <%= if column_spec.name != :action do %>
                <option
                  value={column_spec.name}
                  selected={@table_model.sort_by_spec == column_spec}
                >
                  {column_spec.label}
                </option>
              <% end %>
            <% end %>
          </select>
          <label class="inline-flex size-9 cursor-pointer items-center justify-center rounded text-Text-text-high hover:bg-Surface-surface-secondary-hover focus-within:outline focus-within:outline-2 focus-within:outline-offset-2 focus-within:outline-Fill-Buttons-fill-primary">
            <span class="sr-only">Toggle sort direction</span>
            <.input
              type="checkbox"
              name="sort_order"
              class="hidden"
              value={if @table_model.sort_order == :desc, do: "asc", else: "desc"}
            />
            <i class={"fa fa-sort-amount-#{if @table_model.sort_order == :desc, do: "up", else: "down"}"} />
          </label>
        </form>

        <button
          type="button"
          class="ml-auto inline-flex min-h-9 items-center justify-center gap-2 rounded-md bg-Fill-Buttons-fill-primary px-4 py-2 text-sm font-semibold leading-4 text-Text-text-white shadow-[0px_2px_4px_rgba(0,52,99,0.10)] transition hover:bg-Fill-Buttons-fill-primary-hover focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
          phx-click="display_new_modal"
        >
          <Icons.plus class="h-4 w-4 text-Icon-icon-white" path_class="stroke-current stroke-[3]" />
          New Objective
        </button>
      </div>
    </div>

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
          </div>
        <% :ready -> %>
          <span class="sr-only" id="objective-coverage-ready">Objective coverage loaded</span>
      <% end %>

      <Table.render
        :if={@coverage_status == :ready}
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
                Enum.find(all_objectives, fn rev -> rev.resource_id == resource_id end)
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

  defp start_coverage_load(project, load_ref) do
    pid = self()

    Task.start(fn ->
      result =
        try do
          ObjectiveCoverage.load(project)
        rescue
          _exception -> {:error, :coverage_load_failed}
        catch
          _kind, _reason -> {:error, :coverage_load_failed}
        end

      send(pid, {:objective_coverage_loaded, load_ref, result})
    end)
  end

  def filter_rows(socket, query, _filter) do
    query_str = String.downcase(query)

    Enum.filter(socket.assigns.objectives, fn obj ->
      String.contains?(String.downcase(obj.title), query_str)
    end)
  end

  defp return_updated_data(project, flash_fn, socket) do
    {all_objectives, all_children, objectives, table_model} =
      build_objectives(project)

    load_ref = make_ref()
    start_coverage_load(project, load_ref)

    objective_slugs =
      objectives
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
        coverage_load_ref: load_ref,
        assessment_buckets: socket.assigns.assessment_buckets,
        expanded_objective_slugs: expanded_objective_slugs
      )
      |> flash_fn.()
      |> hide_modal(modal_assigns: nil)

    {:noreply, push_patch(socket, to: live_path(socket, socket.assigns.params))}
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

  def handle_event("hide_modal", _, socket),
    do: {:noreply, hide_modal(socket, modal_assigns: nil)}

  def handle_event("display_new_modal", _, socket),
    do: new_modal(Resources.change_revision(%Revision{}) |> to_form(), socket)

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
      objectives = apply_coverage(socket.assigns.objectives, model, assessment_buckets)
      {:ok, table_model} = TableModel.new(objectives)

      {:noreply, assign(socket, objectives: objectives, table_model: table_model)}
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

  defp parent_objective(_project, ""), do: nil

  defp parent_objective(project, slug),
    do: AuthoringResolver.from_revision_slug(project.slug, slug)

  @impl Phoenix.LiveView
  def handle_info({:objective_coverage_loaded, load_ref, result}, socket) do
    case load_ref == socket.assigns.coverage_load_ref do
      false ->
        {:noreply, socket}

      true ->
        apply_coverage_result(result, socket)
    end
  end

  # needed to ignore results of Task invocation
  def handle_info(_, socket), do: {:noreply, socket}

  defp apply_coverage_result({:ok, model}, socket) do
    assessment_buckets =
      selected_assessment_buckets(
        socket.assigns.assessment_buckets,
        model,
        socket.assigns.objectives
      )

    objectives = apply_coverage(socket.assigns.objectives, model, assessment_buckets)
    {:ok, table_model} = TableModel.new(objectives)

    {:noreply,
     assign(socket,
       objectives: objectives,
       table_model: table_model,
       total_count: length(objectives),
       coverage_model: model,
       coverage_status: :ready,
       assessment_buckets: assessment_buckets
     )}
  end

  defp apply_coverage_result({:error, reason}, socket) do
    {:noreply, assign(socket, coverage_model: nil, coverage_status: {:error, reason})}
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
