defmodule OliWeb.Sections.AssessmentSettings.StudentExceptionsTable do
  use Surface.LiveComponent

  alias OliWeb.Common.{PagedTable, SearchInput}
  alias OliWeb.Sections.AssessmentSettings.StudentExceptionsTableModel
  alias OliWeb.Common.Params
  alias Phoenix.LiveView.JS
  alias OliWeb.Router.Helpers, as: Routes
  alias Surface.Components.Form
  alias Surface.Components.Form.{Field, Label, Select}

  prop(student_exceptions, :list, required: true)
  prop(assessments, :list, required: true)
  prop(params, :map, required: true)
  prop(section_slug, :string, required: true)

  @default_params %{
    offset: 0,
    limit: 25,
    sort_order: :asc,
    sort_by: :student
  }

  def mount(socket) do
    # TODO fix selected exceptions bug
    {:ok, assign(socket, selected_student_exceptions: [])}
  end

  def update(assigns, socket) do
    params = decode_params(assigns.params)

    selected_assessment =
      Enum.find(assigns.assessments, fn a -> a.resource_id == params.selected_assessment_id end)

    {total_count, rows} = apply_filters(assigns.student_exceptions, params)

    {:ok, table_model} =
      StudentExceptionsTableModel.new(
        rows,
        assigns.section_slug,
        selected_assessment,
        socket.assigns.myself
      )

    table_model =
      Map.merge(table_model, %{
        rows: rows,
        sort_order: params.sort_order,
        sort_by_spec:
          Enum.find(table_model.column_specs, fn col_spec -> col_spec.name == params.sort_by end)
      })

    {:ok,
     assign(socket,
       table_model: table_model,
       total_count: total_count,
       total_exceptions:
         get_total_exceptions_count(selected_assessment, assigns.student_exceptions),
       params: params,
       section_slug: assigns.section_slug,
       assessments: assigns.assessments,
       options_for_select: Enum.map(assigns.assessments, fn a -> {a.name, a.resource_id} end)
     )}
  end

  def render(assigns) do
    ~F"""
    <div class="mx-10 mb-10 bg-white shadow-sm">
      <div class="flex flex-col sm:flex-row sm:items-center pr-6 bg-white">
        <div class="flex flex-col pl-9 mr-auto">
          <h4 class="torus-h4">Student Exceptions</h4>
          <Form for={:assessments} id="assessment_select" change="change_assessment">
            <Field name={:assessment_id} class="form-group">
              <Label>Select an assessment to manage student specific exceptions</Label>
              <Select class="ml-4" options={@options_for_select} selected={@params.selected_assessment_id} />
            </Field>
          </Form>
          {#if @total_count > 0}
            <p>Current exceptions: {exceptions_text(@total_count, @total_exceptions)}</p>
          {/if}
        </div>
        <div class="flex space-x-4">
          <button
            class="torus-button flex justify-center primary h-9 w-48"
            disabled={@selected_student_exceptions == []}
          >Remove Selected</button>
          <button class="torus-button flex justify-center primary h-9 w-48">Add New</button>
        </div>
      </div>
      <PagedTable
        table_model={@table_model}
        total_count={@total_count}
        offset={@params.offset}
        limit={@params.limit}
        page_change={JS.push("paged_table_page_change", target: @myself)}
        sort={JS.push("paged_table_sort", target: @myself)}
        additional_table_class="instructor_dashboard_table"
        show_bottom_paging={false}
        render_top_info={false}
        allow_selection
        selection_change={JS.push("row_selected", target: @myself)}
      />
    </div>
    """
  end

  def handle_event("search_assessment", %{"assessment_name" => assessment_name}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Sections.AssessmentSettings.SettingsLive,
           socket.assigns.section_slug,
           :student_exceptions,
           socket.assigns.assessment_id,
           update_params(socket.assigns.params, %{text_search: assessment_name})
         )
     )}
  end

  def handle_event("row_selected", %{"user_id" => user_id, "value" => "on"}, socket) do
    selected_student_exceptions = [
      String.to_integer(user_id) | socket.assigns.selected_student_exceptions
    ]

    {:noreply, assign(socket, selected_student_exceptions: selected_student_exceptions)}
  end

  def handle_event("row_selected", %{"user_id" => user_id}, socket) do
    selected_student_exceptions =
      List.delete(socket.assigns.selected_student_exceptions, String.to_integer(user_id))

    {:noreply, assign(socket, selected_student_exceptions: selected_student_exceptions)}
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Sections.AssessmentSettings.SettingsLive,
           socket.assigns.section_slug,
           :student_exceptions,
           socket.assigns.assessment_id,
           update_params(socket.assigns.params, %{limit: limit, offset: offset})
         )
     )}
  end

  def handle_event("paged_table_sort", %{"sort_by" => sort_by} = _params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Sections.AssessmentSettings.SettingsLive,
           socket.assigns.section_slug,
           :student_exceptions,
           socket.assigns.assessment_id,
           update_params(socket.assigns.params, %{sort_by: String.to_existing_atom(sort_by)})
         )
     )}
  end

  def handle_event(
        "change_assessment",
        %{"assessments" => %{"assessment_id" => assessment_id}},
        socket
      ) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Sections.AssessmentSettings.SettingsLive,
           socket.assigns.section_slug,
           :student_exceptions,
           assessment_id
         )
     )}
  end

  def decode_params(params) do
    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      sort_order:
        Params.get_atom_param(params, "sort_order", [:asc, :desc], @default_params.sort_order),
      sort_by:
        Params.get_atom_param(
          params,
          "sort_by",
          [:assessment],
          @default_params.sort_by
        ),
      selected_assessment_id: Params.get_int_param(params, "assessment_id", 0)
    }
  end

  defp apply_filters(student_exceptions, params) do
    student_exceptions =
      student_exceptions
      |> filter_by_selected_assessment(params.selected_assessment_id)
      |> sort_by(params.sort_by, params.sort_order)

    {length(student_exceptions),
     student_exceptions |> Enum.drop(params.offset) |> Enum.take(params.limit)}
  end

  defp filter_by_selected_assessment(student_exceptions, assessment_id) do
    Enum.filter(student_exceptions, fn se -> se.resource_id == assessment_id end)
  end

  defp sort_by(student_exceptions, sort_by, sort_order) do
    case sort_by do
      :student ->
        Enum.sort_by(
          student_exceptions,
          fn student_exception ->
            student_exception.user.name
          end,
          sort_order
        )

      _ ->
        Enum.sort_by(
          student_exceptions,
          fn student_exception ->
            student_exception.user.name
          end,
          sort_order
        )
    end
  end

  defp update_params(%{sort_by: current_sort_by, sort_order: current_sort_order} = params, %{
         sort_by: new_sort_by
       })
       when current_sort_by == new_sort_by do
    toggled_sort_order = if current_sort_order == :asc, do: :desc, else: :asc
    update_params(params, %{sort_order: toggled_sort_order})
  end

  defp update_params(params, new_param) do
    Map.merge(params, new_param)
    |> purge_default_params()
  end

  defp purge_default_params(params) do
    # there is no need to add a param to the url if its value is equal to the default one
    Map.filter(params, fn {key, value} ->
      @default_params[key] != value
    end)
  end

  defp get_total_exceptions_count(_selected_assessment, []), do: 0
  defp get_total_exceptions_count(nil, _), do: 0

  defp get_total_exceptions_count(selected_assessment, student_exceptions) do
    keys =
      Map.keys(selected_assessment)
      |> Enum.filter(fn key ->
        key not in [:__struct__, :collab_space_config, :explanation_strategy]
      end)

    assessment_student_exceptions =
      filter_by_selected_assessment(student_exceptions, selected_assessment.resource_id)

    Enum.reduce(assessment_student_exceptions, 0, fn se, acc ->
      acc +
        Enum.reduce(keys, 0, fn key, acc2 ->
          acc2 +
            if Map.get(se, key) != nil and Map.get(se, key) != Map.get(selected_assessment, key),
              do: 1,
              else: 0
        end)
    end)
  end

  defp exceptions_text(total_count, total_exceptions) do
    ~s[#{total_count} #{Gettext.ngettext(OliWeb.Gettext, "student", "students", total_count)}, #{total_exceptions} #{Gettext.ngettext(OliWeb.Gettext, "exception", "exceptions", total_exceptions)}]
  end
end
