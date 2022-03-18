defmodule OliWeb.ManualGrading.ManualGradingView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb}
  alias Oli.Delivery.Attempts.ManualGrading
  alias Oli.Delivery.Attempts.ManualGrading.BrowseOptions
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes
  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params
  alias OliWeb.Sections.Mount
  alias OliWeb.ManualGrading.TableModel
  alias OliWeb.ManualGrading.Filters

  @limit 10
  @default_options %BrowseOptions{
    user_id: nil,
    activity_id: nil,
    graded: nil,
    text_search: nil
  }

  data breadcrumbs, :any
  data title, :string, default: "Manual Scoring"
  data section, :any, default: nil
  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: @limit
  data attempt, :struct, default: nil
  data options, :any

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

  def mount(%{"section_slug" => section_slug}, session, socket) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _, section} ->
        attempts =
          ManualGrading.browse_submitted_attempts(
            section,
            %Paging{offset: 0, limit: @limit},
            %Sorting{direction: :desc, field: :date_submitted},
            @default_options
          )

        total_count = determine_total(attempts)

        {:ok, table_model} = Oli.Activities.list_activity_registrations()
        |> Enum.reduce(%{}, fn a, m -> Map.put(m, a.id, a) end)
        |> then(fn map -> TableModel.new(attempts, map) end)

        table_model = Map.put(table_model, :sort_order, :desc)
        |> Map.put(:sort_by_spec, TableModel.date_submitted_spec())

        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(type, section),
           section: section,
           total_count: total_count,
           table_model: table_model,
           options: @default_options
         )}
    end
  end

  defp determine_total(projects) do
    case(projects) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  def handle_params(params, _, socket) do
    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = get_int_param(params, "offset", 0)
    selected = get_param(params, "selected", nil)

    table_model =  Map.put(table_model, :selected, selected)

    options = %BrowseOptions{
      text_search: get_param(params, "text_search", ""),
      user_id: get_int_param(params, "user_id", nil),
      activity_id: get_int_param(params, "activity_id", nil),
      graded: get_boolean_param(params, "graded", nil)
    }

    if only_selection_changed(socket.assigns, table_model, options, offset) do
      table_model = Map.put(socket.assigns.table_model, :selected, selected)

      {:noreply,
       assign(
         socket,
         table_model: table_model,
         attempt: get_selected_attempt(table_model)
       )}
    else

      attempts =
        ManualGrading.browse_submitted_attempts(
          socket.assigns.section,
          %Paging{offset: offset, limit: @limit},
          %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
          options
        )

      table_model = Map.put(table_model, :rows, attempts)
      |> Map.put(:selected, socket.assigns.table_model.selected)

      total_count = determine_total(attempts)

      {:noreply,
      assign(
        socket,
        offset: offset,
        table_model: table_model,
        total_count: total_count,
        options: options,
        attempt: get_selected_attempt(table_model)
      )}
    end

  end

  def render(assigns) do
    ~F"""
    <div>

      <TextSearch id="text-search"/>
      <Filters options={@options}/>

      <div class="mb-3"/>

      <PagedTable
        allow_selection={true}
        filter={@options.text_search}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}/>
    </div>
    """
  end

  @spec patch_with(Phoenix.LiveView.Socket.t(), map) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def patch_with(socket, changes) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           socket.assigns.section.slug,
           Map.merge(
             %{
               sort_by: socket.assigns.table_model.sort_by_spec.name,
               sort_order: socket.assigns.table_model.sort_order,
               offset: socket.assigns.offset,
               text_search: socket.assigns.options.text_search,
               user_id: socket.assigns.options.user_id,
               activity_id: socket.assigns.options.activity_id,
               graded: socket.assigns.options.graded,
               selected: socket.assigns.table_model.selected
             },
             changes
           )
         ),
       replace: true
     )}
  end

  defp get_selected_attempt(%{selected: nil}), do: nil

  defp get_selected_attempt(table_model) do
    Enum.find(table_model.rows, fn r -> r.id == String.to_integer(table_model.selected) end)
  end

  defp only_selection_changed(assigns, model_after, options_after, offset_after) do
    assigns.table_model.selected != model_after.selected and
    assigns.table_model.sort_by_spec == model_after.sort_by_spec and
    assigns.table_model.sort_order == model_after.sort_order and
    assigns.options.text_search == options_after.text_search and
    assigns.options.user_id == options_after.user_id and
    assigns.options.activity_id == options_after.activity_id and
    assigns.options.graded == options_after.graded and
    assigns.offset == offset_after
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &Filters.handle_delegated/4,
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end
end
