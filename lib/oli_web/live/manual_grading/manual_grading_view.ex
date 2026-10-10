defmodule OliWeb.ManualGrading.ManualGradingView do
  @moduledoc """
  The manual scoring table: every activity attempt of the section that awaits manual scoring,
  with search, filters, sorting and paging carried in the URL. Opening a row leads to the
  dedicated scoring page (`OliWeb.ManualGrading.ScoringLive`), which inherits those URL params as
  its queue.
  """

  use OliWeb, :live_view

  alias Oli.Delivery.Attempts.ManualGrading
  alias Oli.Delivery.Attempts.ManualGrading.BrowseOptions
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{Breadcrumb, StripedPagedTable, TextSearch}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Icons
  alias OliWeb.ManualGrading.BrowseParams
  alias OliWeb.ManualGrading.Group
  alias OliWeb.ManualGrading.TableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount

  import OliWeb.DelegatedEvents

  @limit 10
  @default_options %BrowseOptions{
    user_ids: [],
    activity_ids: [],
    page_ids: [],
    graded: nil,
    text_search: ""
  }

  def set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Manual Scoring",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, _session, socket) do
    case Mount.for(section_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _, section} ->
        activity_types_map = Map.new(Oli.Activities.list_activity_registrations(), &{&1.id, &1})

        {:ok, table_model} =
          TableModel.new([], activity_types_map, socket.assigns.ctx, section.slug, %{})

        table_model =
          table_model
          |> Map.put(:sort_order, :desc)
          |> Map.put(:sort_by_spec, TableModel.date_submitted_spec())

        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(type, section),
           section: section,
           title: "Manual Scoring",
           total_count: 0,
           unfiltered_count: 0,
           table_model: table_model,
           options: @default_options,
           offset: 0,
           limit: @limit
         )}
    end
  end

  def handle_params(params, _, socket) do
    table_params = BrowseParams.table_params(params)

    case {legacy_selection(params), out_of_play_filter_values(params, socket)} do
      {{:ok, attempt_id}, _} ->
        {:noreply,
         redirect(socket,
           to: scoring_path(socket.assigns.section, attempt_id, table_params)
         )}

      {:none, {:none, _options}} ->
        case load_table(socket, params, table_params) do
          {:ok, socket} ->
            {:noreply, socket}

          {:past_the_end, last_offset} ->
            table_model =
              table_model_from(socket, params)

            url_params = url_params(table_model, last_offset, BrowseParams.browse_options(params))

            {:noreply,
             push_patch(socket,
               to: Routes.live_path(socket, __MODULE__, socket.assigns.section.slug, url_params),
               replace: true
             )}
        end

      {:none, {:removed, kept_options, removed}} ->
        table_model = table_model_from(socket, params)
        url_params = url_params(table_model, BrowseParams.offset(params), kept_options)

        {:noreply,
         socket
         |> put_flash(
           :info,
           after_notice(socket, removed_values_notice(socket.assigns.section, removed))
         )
         |> push_patch(
           to: Routes.live_path(socket, __MODULE__, socket.assigns.section.slug, url_params),
           replace: true
         )}
    end
  end

  # A notice that arrived with the redirect into the table (e.g. "no longer awaiting scoring")
  # stays in front of the filter-removal notice instead of being replaced by it.
  defp after_notice(socket, notice) do
    case Phoenix.Flash.get(socket.assigns.flash, :info) do
      nil -> notice
      earlier when is_binary(earlier) -> earlier <> " " <> notice
      _other -> notice
    end
  end

  # URLs from before the dedicated scoring page selected a row with `?selected=<id>`.
  defp legacy_selection(%{"selected" => selected}) when is_binary(selected) do
    case BrowseParams.attempt_id(selected) do
      {:ok, id} -> {:ok, id}
      :error -> :none
    end
  end

  defp legacy_selection(_params), do: :none

  # A selected filter value with no pending submission in the section leaves the filter.
  # The dropdown options are exactly the ids with pending submissions, so no extra query is needed.
  defp out_of_play_filter_values(params, socket) do
    options = BrowseParams.browse_options(params)
    in_play = ManualGrading.filter_options(socket.assigns.section)

    removed = %{
      user_ids: options.user_ids -- Enum.map(in_play.users, & &1.id),
      activity_ids: options.activity_ids -- Enum.map(in_play.activities, & &1.id),
      page_ids: options.page_ids -- Enum.map(in_play.pages, & &1.id)
    }

    if removed == %{user_ids: [], activity_ids: [], page_ids: []} do
      {:none, options}
    else
      kept = %{
        options
        | user_ids: options.user_ids -- removed.user_ids,
          activity_ids: options.activity_ids -- removed.activity_ids,
          page_ids: options.page_ids -- removed.page_ids
      }

      {:removed, kept, removed}
    end
  end

  defp removed_values_notice(section, removed) do
    labels = ManualGrading.filter_value_labels(section, removed)

    names =
      Enum.map(removed.user_ids, fn id ->
        case labels.users[id] do
          nil -> "a selected student"
          user -> OliWeb.Common.Utils.name(user)
        end
      end) ++
        Enum.map(removed.activity_ids, &Map.get(labels.activities, &1, "a selected activity")) ++
        Enum.map(removed.page_ids, &Map.get(labels.pages, &1, "a selected page"))

    {subject, verb, participle} =
      case names do
        [only] ->
          {only, "has", "was"}

        many ->
          {Enum.join(Enum.drop(many, -1), ", ") <> " and " <> List.last(many), "have", "were"}
      end

    subject = String.replace_prefix(subject, "a selected", "A selected")

    "#{subject} #{verb} no more submissions awaiting scoring and #{participle} removed from the filter."
  end

  defp load_table(socket, params, table_params) do
    table_model = table_model_from(socket, params)
    offset = BrowseParams.offset(params)
    options = BrowseParams.browse_options(params)

    attempts =
      ManualGrading.browse_submitted_attempts(
        socket.assigns.section,
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    total_count = determine_total(attempts)

    # Coming back to a page that no longer exists lands on the last page that does.
    if attempts == [] and offset > 0 do
      {:past_the_end, last_page_offset(socket.assigns.section, table_model, options)}
    else
      table_model =
        table_model
        |> Map.put(:rows, attempts)
        |> Map.put(:data, Map.put(table_model.data, :table_params, table_params))

      {:ok,
       assign(socket,
         offset: offset,
         table_model: table_model,
         total_count: total_count,
         unfiltered_count: unfiltered_count(socket.assigns.section, options, total_count),
         options: options
       )}
    end
  end

  # The URL alone decides the order, read the way the scoring queue reads it: a URL
  # without sort params shows the default order, not the one the table had before.
  defp table_model_from(socket, params) do
    sorting = BrowseParams.sorting(params)

    SortableTableModel.update_from_params(socket.assigns.table_model, %{
      "sort_by" => Atom.to_string(sorting.field),
      "sort_order" => Atom.to_string(sorting.direction)
    })
  end

  defp last_page_offset(section, table_model, options) do
    total =
      section
      |> ManualGrading.browse_submitted_attempts(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )
      |> determine_total()

    div(max(total - 1, 0), @limit) * @limit
  end

  defp determine_total([]), do: 0
  defp determine_total([first | _]), do: first.total_count

  # Without filters the table's own count already is the section total: no extra query.
  defp unfiltered_count(section, options, total_count) do
    case filtered?(options) do
      true -> ManualGrading.count_submitted_attempts(section)
      false -> total_count
    end
  end

  defp filtered?(%BrowseOptions{} = options) do
    options.user_ids != [] or options.activity_ids != [] or options.page_ids != [] or
      not is_nil(options.graded) or options.text_search not in [nil, ""]
  end

  defp scoring_path(section, attempt_id, table_params) when table_params == %{},
    do: ~p"/sections/#{section.slug}/scoring/#{attempt_id}"

  defp scoring_path(section, attempt_id, table_params),
    do: ~p"/sections/#{section.slug}/scoring/#{attempt_id}?#{table_params}"

  def render(assigns) do
    ~H"""
    <div class="container mx-auto">
      <Group.render>
        <div class="d-flex justify-content-between">
          <TextSearch.render id="text-search" text={@options.text_search} />
          <button
            class="ml-2 mr-6 text-center text-Text-text-high text-sm font-normal leading-none flex items-center gap-x-2 hover:text-Text-text-button"
            phx-click="clear_all_filters"
          >
            <Icons.trash /> Clear All Filters
          </button>
        </div>

        <div class="mb-3" />

        <div :if={filtered?(@options)} class="px-5 py-2" role="status">
          Showing {@total_count} of {@unfiltered_count} submissions
        </div>

        <StripedPagedTable.render
          allow_selection={true}
          filter={@options.text_search}
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
          show_limit_change={false}
          sort_button={true}
          table_id="manual-scoring-table"
          render_top_info={not filtered?(@options)}
          no_records_message={
            if filtered?(@options),
              do: "No submissions match your filters.",
              else: "No submissions awaiting scoring."
          }
        />
      </Group.render>
    </div>
    """
  end

  @spec patch_with(Phoenix.LiveView.Socket.t(), map) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def patch_with(socket, changes) do
    url_params =
      socket.assigns.table_model
      |> url_params(socket.assigns.offset, socket.assigns.options)
      |> Map.merge(changes)

    {:noreply,
     push_patch(socket,
       to: Routes.live_path(socket, __MODULE__, socket.assigns.section.slug, url_params),
       replace: true
     )}
  end

  defp url_params(table_model, offset, %BrowseOptions{} = options) do
    %{
      sort_by: table_model.sort_by_spec.name,
      sort_order: table_model.sort_order,
      offset: offset,
      text_search: options.text_search,
      selected_user_ids: Jason.encode!(options.user_ids),
      selected_activity_ids: Jason.encode!(options.activity_ids),
      selected_page_ids: Jason.encode!(options.page_ids),
      graded: options.graded
    }
  end

  def handle_event("clear_all_filters", _params, socket) do
    patch_with(socket, %{
      text_search: "",
      selected_user_ids: Jason.encode!([]),
      selected_activity_ids: Jason.encode!([]),
      selected_page_ids: Jason.encode!([]),
      graded: nil,
      offset: 0
    })
  end

  # A row click opens its scoring page with a full navigation, so the activity scripts load and
  # the browser's Back returns here. The student link in the row does the same by `href`.
  def handle_event("paged_table_selection_change", %{"id" => id}, socket) do
    case BrowseParams.attempt_id(id) do
      {:ok, attempt_id} ->
        {:noreply,
         redirect(socket,
           to:
             scoring_path(
               socket.assigns.section,
               attempt_id,
               socket.assigns.table_model.data.table_params
             )
         )}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &StripedPagedTable.handle_delegated/4
    ])
  end
end
