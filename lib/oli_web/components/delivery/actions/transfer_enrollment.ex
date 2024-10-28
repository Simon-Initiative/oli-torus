defmodule OliWeb.Delivery.Actions.TransferEnrollment do
  use Phoenix.LiveComponent

  alias Oli.Accounts
  alias Oli.Delivery.{Sections, Transfer}
  alias OliWeb.Common.{PagedTable, Params, SearchInput}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Delivery.Actions.{SectionsToTransferTableModel, StudentsToTransferTableModel}
  alias Phoenix.LiveView.JS

  @default_params %{
    offset: 0,
    limit: 10,
    sort_order: :asc,
    sort_by: :title,
    text_search: nil
  }

  def update(assigns, socket) do
    params = decode_params(@default_params)

    list_sections = Transfer.get_sections_to_transfer_data(assigns.section)

    {total_count, rows} = apply_filters(list_sections, params, :step_1)

    {:ok, sections_table_model} = SectionsToTransferTableModel.new(rows, socket.assigns.myself)

    sections_table_model =
      sections_table_model
      |> Map.merge(%{
        rows: rows,
        sort_order: params.sort_order
      })
      |> SortableTableModel.update_sort_params(params.sort_by)

    {:ok,
     assign(socket,
       current_section: assigns.section,
       current_student: assigns.user,
       list_sections: list_sections,
       list_students: nil,
       params: params,
       sections_table_model: sections_table_model,
       sections_total_count: total_count,
       selected_section_to_transfer: nil,
       selected_student_to_transfer: nil,
       students_table_model: nil,
       students_total_count: 0,
       transfer_data_step: :step_1
     )}
  end

  def update_table_model(socket) do
    case socket.assigns.transfer_data_step do
      :step_1 ->
        {total_count, rows} =
          apply_filters(
            socket.assigns.list_sections,
            socket.assigns.params,
            :step_1
          )

        sections_table_model =
          socket.assigns.sections_table_model
          |> Map.merge(%{
            rows: rows,
            sort_order: socket.assigns.params.sort_order
          })
          |> SortableTableModel.update_sort_params(socket.assigns.params.sort_by)

        {:noreply,
         assign(socket,
           sections_table_model: sections_table_model,
           sections_total_count: total_count,
           transfer_data_step: :step_1
         )}

      :step_2 ->
        set_students_table_model(socket)

      :step_3 ->
        {:noreply, socket}
    end
  end

  def set_students_table_model(socket) do
    {total_count, rows} =
      apply_filters(
        socket.assigns.list_students,
        socket.assigns.params,
        :step_2
      )

    {:ok, students_table_model} = StudentsToTransferTableModel.new(rows, socket.assigns.myself)

    students_table_model =
      students_table_model
      |> Map.merge(%{
        rows: rows,
        sort_order: socket.assigns.params.sort_order
      })
      |> SortableTableModel.update_sort_params(socket.assigns.params.sort_by)

    {:noreply,
     assign(socket,
       students_table_model: students_table_model,
       students_total_count: total_count,
       transfer_data_step: :step_2
     )}
  end

  def render(assigns) do
    ~H"""
    <div phx-target={@myself} id="transfer_enrollment">
      <.live_component
        module={OliWeb.Components.LiveModal}
        id="transfer_enrollment_modal"
        title="Transfer Enrollment"
        on_confirm={
          if @transfer_data_step == :step_3 and @selected_student_to_transfer != nil and
               @selected_section_to_transfer != nil do
            JS.push("finish_transfer_enrollment", target: @myself)
            |> JS.push("close", target: "#transfer_enrollment_modal")
          end
        }
        on_confirm_label={if @transfer_data_step == :step_3, do: "Confirm"}
        on_cancel={
          case @transfer_data_step do
            :step_1 ->
              JS.push("close", target: "#transfer_enrollment_modal")

            :step_2 ->
              JS.push("transfer_data_go_to_step_1", target: @myself)

            :step_3 ->
              JS.push("transfer_data_go_to_step_2", target: @myself)
          end
        }
        on_cancel_label={if @transfer_data_step == :step_1, do: "Cancel", else: "Back"}
        class="w-2/3 max-w-full"
      >
        <.transfer_enrollment
          current_section={@current_section}
          current_student={@current_student}
          list_sections={@list_sections}
          list_students={@list_students}
          myself={@myself}
          params={@params}
          sections_table_model={@sections_table_model}
          sections_total_count={@sections_total_count}
          students_table_model={@students_table_model}
          students_total_count={@students_total_count}
          target_section={@selected_section_to_transfer}
          target_student={@selected_student_to_transfer}
          transfer_data_step={@transfer_data_step}
        />
      </.live_component>
      <div class="flex justify-between items-center">
        <div class="flex flex-col">
          <span class="dark:text-black">Transfer Enrollment</span>
          <span class="text-xs text-gray-400 dark:text-gray-950">
            Transfer data from this section to another section
          </span>
        </div>
        <button phx-click="open" phx-target="#transfer_enrollment_modal" class="torus-button primary">
          Transfer Enrollment
        </button>
      </div>
    </div>
    """
  end

  #### Transfer enrollment modal related stuff ####
  def transfer_enrollment(%{transfer_data_step: :step_1} = assigns) do
    ~H"""
    <div class="px-4">
      <p class="mb-2">
        This will transfer this student's enrollment, and all their current progress, to the selected course section. If this student is already enrolled in the selected course section, that progress will be lost.
      </p>
      <hr class="my-5" />
      <%= if length(assigns.list_sections) > 0 do %>
        <div class="flex flex-col gap-2">
          <div class="flex justify-between items-center">
            <small class="torus-small uppercase">Select section to transfer enrollment</small>
            <form for="search" phx-target={@myself} phx-change="search_item" class="w-44">
              <SearchInput.render
                id="section_search_input"
                name="item_name"
                text={@params.text_search}
              />
            </form>
          </div>
          <PagedTable.render
            table_model={@sections_table_model}
            total_count={@sections_total_count}
            offset={@params.offset}
            limit={@params.limit}
            page_change={JS.push("paged_table_page_change", target: @myself)}
            selection_change={JS.push("paged_table_selection_section_change", target: @myself)}
            sort={JS.push("paged_table_sort", target: @myself)}
            additional_table_class="instructor_dashboard_table"
            show_bottom_paging={false}
            render_top_info={false}
            allow_selection={true}
          />
        </div>
      <% else %>
        <p class="mt-4">There are no other sections to transfer this student to.</p>
      <% end %>
    </div>
    """
  end

  def transfer_enrollment(%{transfer_data_step: :step_2} = assigns) do
    ~H"""
    <div class="px-4">
      <p class="mb-2">
        This will transfer this student's enrollment, and all their current progress, to the selected course section. If this student is already enrolled in the selected course section, that progress will be lost.
      </p>
      <hr class="my-5" />
      <%= if length(assigns.list_students) > 0 do %>
        <div class="flex flex-col gap-2">
          <div class="flex justify-between items-center">
            <small class="torus-small uppercase">Select student to transfer enrollment</small>
            <form for="search" phx-target={@myself} phx-change="search_item" class="w-44">
              <SearchInput.render
                id="student_search_input"
                name="item_name"
                text={@params.text_search}
              />
            </form>
          </div>
          <PagedTable.render
            table_model={@students_table_model}
            total_count={@students_total_count}
            offset={@params.offset}
            limit={@params.limit}
            page_change={JS.push("paged_table_page_change", target: @myself)}
            selection_change={JS.push("paged_table_selection_student_change", target: @myself)}
            sort={JS.push("paged_table_sort", target: @myself)}
            additional_table_class="instructor_dashboard_table"
            show_bottom_paging={false}
            render_top_info={false}
            allow_selection={true}
          />
        </div>
      <% else %>
        <p class="mt-4">There are no other students to transfer this student to.</p>
      <% end %>
    </div>
    """
  end

  def transfer_enrollment(%{transfer_data_step: :step_3} = assigns) do
    ~H"""
    <div class="px-4">
      <p class="mb-2">
        This will transfer this student's enrollment, and all their current progress, to the selected course section. If this student is already enrolled in the selected course section, that progress will be lost.
      </p>
      <hr class="my-5" />
      <p class="my-4">
        Are you sure you want to transfer the <strong><%= @current_student.name %></strong>
        enrollment's in <strong><%= @current_section.title %></strong>
        to <strong><%= @target_student.name %></strong>
        in <strong><%= @target_section.title %></strong>?
      </p>
    </div>
    """
  end

  def handle_event("transfer_data_go_to_step_1", _, socket) do
    update_table_model(
      assign(
        socket,
        params: @default_params,
        transfer_data_step: :step_1,
        selected_section_to_transfer: nil,
        selected_student_to_transfer: nil
      )
    )
  end

  def handle_event("transfer_data_go_to_step_2", _, socket) do
    update_table_model(
      assign(
        socket,
        transfer_data_step: :step_2
      )
    )
  end

  def handle_event("finish_transfer_enrollment", _params, socket) do
    %{
      current_section: current_section,
      current_student: current_student,
      selected_section_to_transfer: target_section,
      selected_student_to_transfer: target_student
    } = socket.assigns

    case Transfer.transfer_enrollment(
           current_section,
           current_student.id,
           target_section,
           target_student.id
         ) do
      {:ok, _} ->
        send(self(), {:put_flash, :info, "Enrollment successfully transfered"})
        {:noreply, socket}

      {:error, _} ->
        send(self(), {:put_flash, :error, "Couldn't transfer enrollment data. Please try again"})
        {:noreply, socket}
    end
  end

  def handle_event(
        "paged_table_selection_section_change",
        %{"id" => selected_section_id},
        socket
      ) do
    selected_target_section = Sections.get_section!(String.to_integer(selected_section_id))

    set_students_table_model(
      assign(
        socket,
        list_students:
          Sections.get_students_for_section_with_enrollment_date(selected_target_section.id),
        params: update_params(socket.assigns.params, %{sort_by: :name}),
        selected_section_to_transfer: selected_target_section,
        selected_student_to_transfer: nil
      )
    )
  end

  def handle_event(
        "paged_table_selection_student_change",
        %{"id" => selected_student_id},
        socket
      ) do
    target_student = Accounts.get_user!(String.to_integer(selected_student_id))

    update_table_model(
      assign(
        socket,
        selected_student_to_transfer: target_student,
        transfer_data_step: :step_3
      )
    )
  end

  def handle_event(
        "search_item",
        %{"item_name" => item_name},
        socket
      ) do
    update_table_model(
      assign(
        socket,
        :params,
        update_params(socket.assigns.params, %{text_search: item_name})
      )
    )
  end

  def handle_event(
        "paged_table_page_change",
        %{"limit" => limit, "offset" => offset},
        socket
      ) do
    update_table_model(
      assign(
        socket,
        :params,
        update_params(socket.assigns.params, %{
          limit: String.to_integer(limit),
          offset: String.to_integer(offset)
        })
      )
    )
  end

  def handle_event(
        "paged_table_sort",
        %{"sort_by" => sort_by} = _params,
        socket
      ) do
    update_table_model(
      assign(
        socket,
        :params,
        update_params(socket.assigns.params, %{sort_by: String.to_existing_atom(sort_by)})
      )
    )
  end

  defp decode_params(params) do
    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      sort_order:
        Params.get_atom_param(
          params,
          "sort_order",
          [:asc, :desc],
          @default_params.sort_order
        ),
      sort_by:
        Params.get_atom_param(
          params,
          "sort_by",
          [
            :title,
            :start_date,
            :end_date,
            :name,
            :enrollment_date
          ],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search)
    }
  end

  defp apply_filters(list_to_work, params, step) do
    list_to_work =
      list_to_work
      |> maybe_filter_by_text(params.text_search, step)
      |> sort_by(params.sort_by, params.sort_order)

    {length(list_to_work), list_to_work |> Enum.drop(params.offset) |> Enum.take(params.limit)}
  end

  defp maybe_filter_by_text(list_to_work, nil, _), do: list_to_work
  defp maybe_filter_by_text(list_to_work, "", _), do: list_to_work

  defp maybe_filter_by_text(list_to_work, text_search, step) do
    case step do
      :step_1 ->
        Enum.filter(list_to_work, fn data ->
          String.contains?(
            safe_downcase(data.title),
            safe_downcase(text_search)
          )
        end)

      :step_2 ->
        Enum.filter(list_to_work, fn data ->
          String.contains?(
            safe_downcase(data.name),
            safe_downcase(text_search)
          )
        end)
    end
  end

  defp sort_by(list_to_work, sort_by, sort_order) do
    case sort_by do
      :title ->
        Enum.sort_by(
          list_to_work,
          fn data -> data.title |> safe_downcase end,
          sort_order
        )

      :start_date ->
        Enum.sort_by(list_to_work, fn data -> data.start_date end, sort_order)

      :end_date ->
        Enum.sort_by(list_to_work, fn data -> data.end_date end, sort_order)

      :enrollment_date ->
        Enum.sort_by(list_to_work, fn data -> data.enrollment_date end, sort_order)

      :name ->
        Enum.sort_by(
          list_to_work,
          fn data -> data.name |> safe_downcase end,
          sort_order
        )
    end
  end

  defp safe_downcase(nil), do: ""
  defp safe_downcase(string), do: String.downcase(string)

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
