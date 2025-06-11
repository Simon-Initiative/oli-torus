defmodule OliWeb.Grades.FailedGradeSyncLive do
  use OliWeb.Common.SortableTable.TableHandlers
  use OliWeb, :live_view

  import Oli.Utils, only: [trap_nil: 2]

  alias Oli.Delivery.Attempts.{Core, PageLifecycle.GradeUpdateWorker}
  alias OliWeb.Common.{Breadcrumb, Filter, Listing}
  alias OliWeb.Grades.FailedGradeSyncTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount

  require Logger

  @title "View Failed LMS Grade Sync"
  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2

  def filter_rows(socket, query, _filter) do
    query_str = String.downcase(query)

    Enum.filter(socket.assigns.failed_resource_accesses, fn ra ->
      String.contains?(String.downcase(ra.user_name), query_str) or
        String.contains?(String.downcase(ra.page_title), query_str)
    end)
  end

  def live_path(socket, params),
    do: Routes.live_path(socket, __MODULE__, socket.assigns.section.slug, params)

  def set_breadcrumbs(type, section) do
    type
    |> OliWeb.Sections.OverviewView.set_breadcrumbs(section)
    |> breadcrumb(section)
  end

  defp breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: @title,
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, _session, socket) do
    case Mount.for(section_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, user, section} ->
        failed_resource_accesses =
          Core.get_failed_grade_sync_resource_accesses_for_section(section.slug)

        {:ok, table_model} = FailedGradeSyncTableModel.new(failed_resource_accesses)

        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(type, section),
           is_lms_or_system_admin: Mount.is_lms_or_system_admin?(user, section),
           failed_resource_accesses: failed_resource_accesses,
           table_model: table_model,
           total_count: length(failed_resource_accesses),
           section: section,
           query: "",
           offset: 0,
           limit: 20
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto">
      <div class="d-flex p-3 justify-content-between">
        <Filter.render
          change="change_search"
          reset="reset_search"
          apply="apply_search"
          query={@query}
        />

        <button class="btn btn-primary mr-5" phx-click="bulk-retry">Retry all</button>
      </div>

      <div id="failed-sync-grades-table" class="p-4">
        <Listing.render
          filter={@query}
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
          sort="sort"
          page_change="page_change"
          show_bottom_paging={false}
        />
      </div>
    </div>
    """
  end

  def handle_event("retry", %{"resource-id" => resource_id, "user-id" => user_id}, socket) do
    socket = clear_flash(socket)
    section = socket.assigns.section

    with {:ok, resource_access} <-
           resource_id
           |> Core.get_resource_access(section.slug, user_id)
           |> trap_nil("The resource access was not found."),
         {:ok, %Oban.Job{}} <- GradeUpdateWorker.create(section.id, resource_access.id, :manual) do
      handle_success(socket, section.slug)
    else
      error ->
        log_error(resource_id, user_id, error)
        {:noreply, put_flash(socket, :error, "Couldn't retry grade sync.")}
    end
  end

  def handle_event("bulk-retry", _, socket) do
    socket = clear_flash(socket)
    %{section: section, failed_resource_accesses: failed_resource_accesses} = socket.assigns

    Enum.reduce_while(failed_resource_accesses, true, fn resource_access, acc ->
      case GradeUpdateWorker.create(section.id, resource_access.id, :manual_batch) do
        {:ok, %Oban.Job{}} ->
          {:cont, acc}

        error ->
          log_error(resource_access.resource_id, resource_access.user_id, error)
          {:halt, acc}
      end
    end)

    handle_success(socket, section.slug)
  end

  defp log_error(resource_id, user_id, error),
    do:
      Logger.error(
        "Couldn't retry grade sync for resource_id: #{resource_id}, user_id: #{user_id}. Reason: #{inspect(error)}"
      )

  defp handle_success(socket, section_slug) do
    if socket.assigns.is_lms_or_system_admin do
      {:noreply,
       socket
       |> put_flash(:info, "Retrying grade sync. See processing in real time below.")
       |> push_navigate(
         to:
           Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.ObserveGradeUpdatesView, section_slug)
       )}
    else
      {:noreply,
       socket
       |> put_flash(:info, "Retrying grade sync. Please check the status again in a few minutes.")
       |> push_navigate(
         to: Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section_slug)
       )}
    end
  end
end
