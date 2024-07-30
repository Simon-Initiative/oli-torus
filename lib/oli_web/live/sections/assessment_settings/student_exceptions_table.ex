defmodule OliWeb.Sections.AssessmentSettings.StudentExceptionsTable do
  use OliWeb, :live_component

  import Phoenix.HTML.Form
  import OliWeb.ErrorHelpers
  import Ecto.Query, only: [from: 2]

  alias OliWeb.Common.{FormatDateTime, PagedTable, Paging, Params}
  alias OliWeb.Sections.AssessmentSettings.StudentExceptionsTableModel
  alias OliWeb.Common.Utils, as: CommonUtils
  alias Phoenix.LiveView.JS
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.{Delivery, Repo, Utils}
  alias Oli.Delivery.Settings
  alias Oli.Delivery.Settings.{AutoSubmitCustodian, StudentException}

  @default_params %{
    offset: 0,
    limit: 10,
    sort_order: :asc,
    sort_by: :student
  }

  def mount(socket) do
    {:ok, assign(socket, selected_student_exceptions: [], modal_assigns: %{show: false})}
  end

  def update(assigns, socket) do
    params = decode_params(assigns.params)

    selected_assessment =
      Enum.find(assigns.assessments, fn a -> a.resource_id == params.selected_assessment_id end)

    {total_count, rows, assessment_student_exceptions} =
      apply_filters(assigns.student_exceptions, params)

    {:ok, table_model} =
      StudentExceptionsTableModel.new(
        rows,
        assigns.section.slug,
        selected_assessment,
        socket.assigns.myself,
        socket.assigns.selected_student_exceptions,
        assigns.ctx,
        JS.push("edit_date", target: socket.assigns.myself),
        JS.push("edit_password", target: socket.assigns.myself),
        JS.push("no_edit_password", target: socket.assigns.myself)
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
       section: assigns.section,
       ctx: assigns.ctx,
       assessments: assigns.assessments,
       students: assigns.students,
       form_id: UUID.uuid4(),
       assessment_student_exceptions: assessment_student_exceptions,
       options_for_select: Enum.map(assigns.assessments, fn a -> {a.name, a.resource_id} end),
       selected_setting: socket.assigns[:selected_setting] || nil,
       selected_assessment: selected_assessment
     )}
  end

  attr(:student_exceptions, :list, required: true)
  attr(:assessments, :list, required: true)
  attr(:params, :map, required: true)
  attr(:ctx, :map, required: true)
  attr(:section, :map, required: true)

  attr(:table_model, :map)
  attr(:total_count, :integer)
  attr(:total_exceptions, :integer)
  attr(:options_for_select, :list)
  attr(:students, :list)
  attr(:selected_student_exceptions, :list)
  attr(:modal_assigns, :map)
  attr(:form_id, :string)
  attr(:selected_setting, :map)

  def render(assigns) do
    assigns = assign(assigns, assessment_changeset: to_form(%{}, as: :assessments))

    ~H"""
    <div id="student_exceptions_table" class="bg-white dark:bg-gray-800 shadow-sm">
      <%= due_date_modal(assigns) %>
      <%= available_date_modal(assigns) %>
      <%= modal(@modal_assigns) %>
      <div class="flex flex-col sm:flex-row sm:items-center pr-6 mb-4">
        <div class="flex flex-col pl-9 mr-auto">
          <h4 class="torus-h4">Student Exceptions</h4>
          <.form
            for={@assessment_changeset}
            id="assessment_select"
            phx-change="change_assessment"
            phx-target={@myself}
          >
            <div class="form-group">
              <.input
                type="select"
                field={@assessment_changeset[:assessment_id]}
                label="Select an assessment to manage student specific exceptions"
                class="ml-4"
                options={@options_for_select}
              />
            </div>
          </.form>
          <%= if @total_count > 0 do %>
            <p class={
              if @total_exceptions > 0, do: "bg-blue-100 p-3 mr-auto rounded-lg bg-opacity-50"
            }>
              Current exceptions: <%= exceptions_text(@total_count, @total_exceptions) %>
            </p>
          <% end %>
        </div>
        <div class="flex space-x-4">
          <button
            class="torus-button flex justify-center primary h-9 w-48"
            disabled={@selected_student_exceptions == []}
            phx-click="show_modal"
            phx-value-modal_name="confirm_removal"
            phx-target={@myself}
          >
            Remove Selected
          </button>
          <button
            class="torus-button flex justify-center primary h-9 w-48"
            disabled={length(@students) == @total_count}
            phx-click="show_modal"
            phx-value-modal_name="add_student_exception"
            phx-target={@myself}
          >
            Add New
          </button>
        </div>
      </div>
      <p class="pl-9 pr-6">
        Note: Setting an availability date in the past will effectively allow a student to access the page.
      </p>
      <Paging.render
        id="header_paging"
        total_count={@total_count}
        offset={@params.offset}
        limit={@params.limit}
        click={JS.push("paged_table_page_change", target: @myself)}
      />
      <form
        id={"form-#{@form_id}"}
        for="student_exceptions_table"
        phx-target={@myself}
        phx-change="update_student_exception"
      >
        <PagedTable.render
          table_model={@table_model}
          total_count={@total_count}
          offset={@params.offset}
          limit={@params.limit}
          sort={JS.push("paged_table_sort", target: @myself)}
          additional_table_class="instructor_dashboard_table"
          show_bottom_paging={false}
          show_top_paging={false}
          render_top_info={false}
        />
      </form>
    </div>
    """
  end

  def available_date_modal(assigns) do
    ~H"""
    <.live_component
      id="student_available_date_modal"
      title={if @selected_setting, do: "Available date for #{@selected_setting.user.name}"}
      module={OliWeb.Components.LiveModal}
      on_confirm={
        JS.dispatch("submit", to: "#student-available-date-form")
        |> JS.push("close", target: "#student_available_date_modal")
      }
      on_confirm_label="Save"
    >
      <div class="p-4">
        <form
          id="student-available-date-form"
          for="settings_table"
          phx-target={@myself}
          phx-submit="edit_date"
        >
          <label for="start_date_input">Please pick an available date for the selected student</label>
          <div class="flex gap-2 items-center mt-2">
            <input
              id="start_date_input"
              name="start_date"
              type="datetime-local"
              max={CommonUtils.datetime_input_limit(:start_date, @selected_setting, @ctx)}
              phx-debounce={500}
              value={value_from_datetime(@selected_setting.start_date, @ctx)}
            />
            <button
              class="torus-button primary"
              type="button"
              phx-click={JS.set_attribute({"value", ""}, to: "#start_date_input")}
            >
              Clear
            </button>
          </div>
        </form>
      </div>
    </.live_component>
    """
  end

  def due_date_modal(assigns) do
    ~H"""
    <.live_component
      id="student_due_date_modal"
      title={if @selected_setting, do: "Due date for #{@selected_setting.user.name}"}
      module={OliWeb.Components.LiveModal}
      on_confirm={
        JS.dispatch("submit", to: "#student-due-date-form")
        |> JS.push("close", target: "#student_due_date_modal")
      }
      on_confirm_label="Save"
    >
      <div class="p-4">
        <form
          id="student-due-date-form"
          for="settings_table"
          phx-target={@myself}
          phx-submit="edit_date"
        >
          <label for="end_date_input">Please pick a due date for the selected student</label>
          <div class="flex gap-2 items-center mt-2">
            <input
              id="end_date_input"
              name="end_date"
              type="datetime-local"
              min={CommonUtils.datetime_input_limit(:end_date, @selected_setting, @ctx)}
              phx-debounce={500}
              value={value_from_datetime(@selected_setting.end_date, @ctx)}
            />
            <button
              class="torus-button primary"
              type="button"
              phx-click={JS.set_attribute({"value", ""}, to: "#end_date_input")}
            >
              Clear
            </button>
          </div>
        </form>
      </div>
    </.live_component>
    """
  end

  def modal(%{show: false}), do: nil

  def modal(%{show: "add_student_exception"} = assigns) do
    ~H"""
    <div
      id="add_student_exception_modal"
      class="modal fade show bg-gray-900 bg-opacity-50"
      tabindex="-1"
      role="dialog"
      aria-hidden="true"
      style="display: block;"
      phx-window-keydown={JS.dispatch("click", to: "#cancel_exception_button")}
      phx-key="Escape"
    >
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Add Exception</h5>
            <button
              type="button"
              class="btn-close box-content w-4 h-4 p-1 border-none rounded-none opacity-50 focus:shadow-none focus:outline-none focus:opacity-100 hover:opacity-75 hover:no-underline"
              aria-label="Close"
              phx-click={JS.dispatch("click", to: "#cancel_exception_button")}
            >
              <i class="fa-solid fa-xmark fa-xl" />
            </button>
          </div>
          <div class="modal-body">
            <.form
              :let={f}
              for={%{}}
              as={:student_exception}
              phx-submit="add_student_exception"
              phx-target={@myself}
            >
              <div class="flex flex-col space-y-2">
                <%= label(f, :student, "Select Student", class: "control-label") %>
                <%= select(f, :student_id, @student_options) %>
              </div>
              <div class="flex space-x-3 mt-6 justify-end">
                <button
                  type="button"
                  id="cancel_exception_button"
                  class="btn btn-link"
                  phx-click="hide_modal"
                  phx-target={@myself}
                >
                  Cancel
                </button>

                <button type="submit" class="btn btn-primary">Add</button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def modal(%{show: "confirm_removal"} = assigns) do
    ~H"""
    <div
      id="confirm_removal_modal"
      class="modal fade show bg-gray-900 bg-opacity-50"
      tabindex="-1"
      role="dialog"
      aria-hidden="true"
      style="display: block;"
      phx-window-keydown={JS.dispatch("click", to: "#cancel_removal_button")}
      phx-key="Escape"
    >
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Confirm Removal</h5>
            <button
              type="button"
              class="btn-close box-content w-4 h-4 p-1 border-none rounded-none opacity-50 focus:shadow-none focus:outline-none focus:opacity-100 hover:opacity-75 hover:no-underline"
              aria-label="Close"
              phx-click={JS.dispatch("click", to: "#cancel_removal_button")}
            >
              <i class="fa-solid fa-xmark fa-xl" />
            </button>
          </div>
          <div class="modal-body">
            <.form
              for={%{}}
              as={:confirm_removal}
              phx-submit="remove_student_exceptions"
              phx-target={@myself}
            >
              <div class="flex flex-col space-y-2">
                <p>Are you sure you want to remove the selected exceptions?</p>
              </div>
              <div class="flex space-x-3 mt-6 justify-end">
                <button
                  type="button"
                  id="cancel_removal_button"
                  class="btn btn-link"
                  phx-click="hide_modal"
                  phx-target={@myself}
                >
                  Cancel
                </button>

                <button type="submit" class="btn btn-primary">Confirm</button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def modal(%{show: "scheduled_feedback"} = assigns) do
    ~H"""
    <div
      id="scheduled_modal"
      class="modal fade show bg-gray-900 bg-opacity-50"
      tabindex="-1"
      role="dialog"
      aria-hidden="true"
      style="display: block;"
      phx-window-keydown={JS.dispatch("click", to: "#scheduled_cancel_button")}
      phx-key="Escape"
    >
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">View Feedback</h5>
            <button
              type="button"
              class="btn-close box-content w-4 h-4 p-1 border-none rounded-none opacity-50 focus:shadow-none focus:outline-none focus:opacity-100 hover:opacity-75 hover:no-underline"
              aria-label="Close"
              phx-click={JS.dispatch("click", to: "#scheduled_cancel_button")}
            >
              <i class="fa-solid fa-xmark fa-xl" />
            </button>
          </div>
          <div class="modal-body">
            <.form
              :let={f}
              for={@changeset}
              phx-submit="submit_scheduled_date"
              phx-change="validate_scheduled_date"
              phx-target={@myself}
            >
              <div class="flex flex-col space-y-2">
                <%= label(f, :feedback_scheduled_date, "Scheduled Date", class: "control-label") %>
                <%= datetime_local_input(f, :feedback_scheduled_date, class: "mr-auto") %>
                <%= error_tag(f, :feedback_scheduled_date, true) %>
              </div>
              <div class="flex space-x-3 mt-6 justify-end">
                <button
                  type="button"
                  id="scheduled_cancel_button"
                  class="btn btn-link"
                  phx-click="hide_modal"
                  phx-target={@myself}
                >
                  Cancel
                </button>

                <button type="submit" class="btn btn-primary">Save</button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event(event, params, socket) when event in ["no_edit_password", "edit_password"] do
    edit_password_id =
      case params["user_id"] do
        nil -> nil
        user_id -> String.to_integer(user_id)
      end

    {:ok, table_model} =
      StudentExceptionsTableModel.new(
        socket.assigns.table_model.rows,
        socket.assigns.section.slug,
        socket.assigns.selected_assessment,
        socket.assigns.myself,
        socket.assigns.selected_student_exceptions,
        socket.assigns.ctx,
        JS.push("edit_date", target: socket.assigns.myself),
        JS.push("edit_password", target: socket.assigns.myself),
        JS.push("no_edit_password", target: socket.assigns.myself),
        edit_password_id
      )

    {:noreply,
     assign(socket,
       table_model: table_model
     )}
  end

  def handle_event("edit_date", %{"user_id" => user_id}, socket) do
    selected_setting =
      Enum.find(socket.assigns.table_model.rows, fn s ->
        s.user_id == String.to_integer(user_id)
      end)

    {:noreply, assign(socket, selected_setting: selected_setting)}
  end

  def handle_event("edit_date", %{"start_date" => start_date}, socket),
    do: on_edit_date(:start_date, start_date, socket)

  def handle_event("edit_date", %{"end_date" => end_date}, socket),
    do: on_edit_date(:end_date, end_date, socket)

  def handle_event("show_modal", %{"modal_name" => name}, socket) do
    common_modal_assings = %{show: name, myself: socket.assigns.myself}

    case name do
      "confirm_removal" ->
        {:noreply, assign(socket, modal_assigns: common_modal_assings)}

      "add_student_exception" ->
        student_with_exceptions =
          Enum.map(socket.assigns.assessment_student_exceptions, fn se -> se.user_id end)

        student_options =
          socket.assigns.students
          |> Enum.reduce([], fn s, acc ->
            if s.id in student_with_exceptions, do: acc, else: [{s.name, s.id}] ++ acc
          end)

        {:noreply,
         assign(socket,
           modal_assigns:
             Map.merge(common_modal_assings, %{
               student_options: student_options
             })
         )}
    end
  end

  def handle_event("hide_modal", _params, socket) do
    {:noreply, assign(socket, modal_assigns: %{show: false})}
  end

  def handle_event("update_student_exception", params, socket) do
    case decode_target(params, socket.assigns.ctx) do
      {:feedback_mode, user_id, :scheduled} ->
        student_exception =
          socket.assigns.table_model.rows
          |> Enum.find(fn student_exception -> student_exception.user_id == user_id end)
          |> Map.update(
            :feedback_scheduled_date,
            nil,
            fn scheduled_date -> value_from_datetime(scheduled_date, socket.assigns.ctx) end
          )

        changeset =
          StudentException.changeset(student_exception, %{
            feedback_mode: :scheduled
          })

        {:noreply,
         assign(socket,
           modal_assigns: %{
             show: "scheduled_feedback",
             changeset: changeset,
             student_exception: student_exception,
             myself: socket.assigns.myself
           }
         )}

      {:checkbox, user_id, value} ->
        selected_student_exceptions =
          case value do
            nil -> List.delete(socket.assigns.selected_student_exceptions, user_id)
            "on" -> [user_id | socket.assigns.selected_student_exceptions]
          end

        table_model_data =
          Map.merge(socket.assigns.table_model.data, %{
            selected_student_exceptions: selected_student_exceptions
          })

        {:noreply,
         assign(socket,
           selected_student_exceptions: selected_student_exceptions,
           table_model: Map.merge(socket.assigns.table_model, %{data: table_model_data})
         )}

      {:password, user_id, new_value} ->
        do_update(:password, user_id, new_value, socket)

      {:late_submit, user_id, :allow} ->
        result =
          Repo.transaction(fn ->
            AutoSubmitCustodian.cancel(
              socket.assigns.section.id,
              socket.assigns.params.selected_assessment_id,
              user_id
            )

            do_update(:late_submit, user_id, :allow, socket)
          end)

        case result do
          {:ok, return} ->
            return

          {:error, _} ->
            {:noreply,
             socket
             |> flash_to_liveview(:error, "ERROR: Student Exception could not be updated")
             |> assign(modal_assigns: %{show: false})}
        end

      {key, user_id, new_value} when new_value != "" ->
        do_update(key, user_id, new_value, socket)

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("remove_student_exceptions", _params, socket) do
    selected_student_exceptions =
      Enum.filter(socket.assigns.table_model.rows, fn se ->
        se.user_id in socket.assigns.selected_student_exceptions
      end)

    from(se in StudentException,
      where:
        se.user_id in ^socket.assigns.selected_student_exceptions and
          se.resource_id == ^socket.assigns.params.selected_assessment_id
    )
    |> Repo.delete_all()

    update_liveview_student_exceptions(
      :deleted,
      selected_student_exceptions,
      true
    )

    {:noreply,
     socket
     |> flash_to_liveview(:info, "Student Exception/s removed!")
     |> assign(modal_assigns: %{show: false}, selected_student_exceptions: [])}
  end

  def handle_event(
        "add_student_exception",
        %{"student_exception" => %{"student_id" => student_id}},
        socket
      ) do
    %StudentException{}
    |> StudentException.changeset(%{
      user_id: student_id,
      section_id: socket.assigns.section.id,
      resource_id: socket.assigns.params.selected_assessment_id
    })
    |> Repo.insert()
    |> case do
      {:error, _changeset} ->
        {:noreply,
         socket
         |> flash_to_liveview(:error, "ERROR: Student Exception could not be updated")
         |> assign(modal_assigns: %{show: false})}

      {:ok, student_exception} ->
        update_liveview_student_exceptions(
          :added,
          [Repo.preload(student_exception, :user)],
          true
        )

        {:noreply,
         socket
         |> flash_to_liveview(:info, "Student Exception added!")
         |> assign(modal_assigns: %{show: false})}
    end
  end

  def handle_event(
        "validate_scheduled_date",
        %{
          "student_exception" => %{
            "feedback_scheduled_date" => feedback_scheduled_date
          }
        },
        socket
      ) do
    changeset =
      socket.assigns.modal_assigns.student_exception
      |> StudentException.changeset(%{
        feedback_scheduled_date: feedback_scheduled_date
      })
      |> Ecto.Changeset.validate_required(:feedback_scheduled_date)
      |> Map.put(:action, :validate)

    {:noreply,
     assign(socket,
       modal_assigns: Map.merge(socket.assigns.modal_assigns, %{changeset: changeset})
     )}
  end

  def handle_event(
        "submit_scheduled_date",
        %{
          "student_exception" => %{
            "feedback_scheduled_date" => feedback_scheduled_date
          }
        },
        socket
      ) do
    utc_datetime =
      FormatDateTime.datestring_to_utc_datetime(
        feedback_scheduled_date,
        socket.assigns.ctx
      )

    socket.assigns.modal_assigns.student_exception
    |> Settings.update_student_exception(
      %{
        feedback_scheduled_date: utc_datetime,
        feedback_mode: :scheduled
      },
      [:feedback_scheduled_date]
    )
    |> case do
      {:error, changeset} ->
        {:noreply,
         assign(socket,
           modal_assigns: Map.merge(socket.assigns.modal_assigns, %{changeset: changeset})
         )}

      {:ok, updated_student_exception} ->
        update_liveview_student_exceptions(
          :updated,
          [Repo.preload(updated_student_exception, :user)],
          false
        )

        {:noreply,
         socket
         |> flash_to_liveview(:info, "Student Exception updated!")
         |> assign(modal_assigns: %{show: false})}
    end
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Sections.AssessmentSettings.SettingsLive,
           socket.assigns.section.slug,
           :student_exceptions,
           socket.assigns.params.selected_assessment_id,
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
           socket.assigns.section.slug,
           :student_exceptions,
           socket.assigns.params.selected_assessment_id,
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
           socket.assigns.section.slug,
           :student_exceptions,
           assessment_id
         )
     )}
  end

  defp maybe_adjust_dates(date_field, new_date, selected_setting, ctx) do
    new_date =
      if String.length(new_date) > 0 do
        FormatDateTime.datestring_to_utc_datetime(
          new_date,
          ctx
        )
      else
        nil
      end

    {new_start_date, new_end_date, changed_date_field} =
      CommonUtils.maybe_preserve_dates_distance(date_field, new_date, selected_setting)

    message =
      if changed_date_field do
        " The #{Utils.stringify_atom(changed_date_field)} was adjusted to preserve the time distance between the start and end dates."
      else
        ""
      end

    {new_start_date, new_end_date, message}
  end

  defp perform_edits(selected_setting, date_field, new_start_date, new_end_date, socket) do
    Repo.transaction(fn ->
      existing_student_exception =
        Delivery.get_delivery_setting_by(%{
          resource_id: selected_setting.resource_id,
          user_id: selected_setting.user_id
        })

      message =
        if existing_student_exception.late_submit == :disallow do
          case AutoSubmitCustodian.adjust(
                 socket.assigns.section.id,
                 socket.assigns.selected_assessment.resource_id,
                 existing_student_exception.end_date,
                 new_end_date,
                 existing_student_exception.user_id
               ) do
            {:ok, 0} ->
              ""

            {:ok, count} ->
              " Adjusted the deadline for #{count} active student #{Gettext.ngettext(OliWeb.Gettext, "attempt", "attempts", count)}."

            e ->
              Repo.rollback(e)
          end
        end

      updated_student_exception =
        change_student_exception(
          existing_student_exception,
          date_field,
          new_start_date,
          new_end_date
        )
        |> Repo.update()
        |> case do
          {:ok, updated_student_exception} ->
            updated_student_exception

          e ->
            Repo.rollback(e)
        end

      {updated_student_exception, message}
    end)
  end

  defp on_edit_date(date_field, new_date, socket) do
    selected_setting = socket.assigns.selected_setting

    {new_start_date, new_end_date, message} =
      maybe_adjust_dates(date_field, new_date, selected_setting, socket.assigns.ctx)

    case perform_edits(selected_setting, date_field, new_start_date, new_end_date, socket) do
      {:ok, {updated_student_exception, additional_message}} ->
        update_liveview_student_exceptions(
          :updated,
          [Repo.preload(updated_student_exception, :user)],
          false
        )

        {:noreply,
         socket
         |> flash_to_liveview(:info, "Student Exception updated!.#{message}#{additional_message}")}

      _ ->
        {:noreply,
         socket
         |> flash_to_liveview(:error, "ERROR: Student Exception could not be updated")}
    end
  end

  defp change_student_exception(student_exception, :start_date, start_date, end_date) do
    StudentException.changeset(student_exception, %{
      start_date: start_date,
      end_date: end_date
    })
  end

  defp change_student_exception(student_exception, :end_date, start_date, end_date) do
    StudentException.changeset(student_exception, %{
      start_date: start_date,
      end_date: end_date,
      scheduling_type: unless(is_nil(end_date), do: :due_by, else: :read_by)
    })
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
          [
            :name,
            :due_date,
            :available_date,
            :max_attempts,
            :time_limit,
            :late_submit,
            :late_start,
            :scoring,
            :grace_period,
            :retake_mode,
            :assessment_mode,
            :feedback_mode,
            :review_submission,
            :exceptions_count,
            :scoring_strategy_id
          ],
          @default_params.sort_by
        ),
      selected_assessment_id: Params.get_int_param(params, "assessment_id", 0)
    }
  end

  defp do_update(key, user_id, new_value, socket) do
    Delivery.get_delivery_setting_by(%{
      resource_id: socket.assigns.params.selected_assessment_id,
      user_id: user_id
    })
    |> StudentException.changeset(Map.new([{key, new_value}]))
    |> Repo.update()
    |> case do
      {:error, _changeset} ->
        {:noreply,
         socket
         |> flash_to_liveview(:error, "ERROR: Student Exception could not be updated")}

      {:ok, updated_student_exception} ->
        update_liveview_student_exceptions(
          :updated,
          [Repo.preload(updated_student_exception, :user)],
          false
        )

        {:noreply,
         socket
         |> flash_to_liveview(:info, "Student Exception updated!")}
    end
  end

  defp apply_filters(student_exceptions, params) do
    student_exceptions =
      student_exceptions
      |> filter_by_selected_assessment(params.selected_assessment_id)
      |> sort_by(params.sort_by, params.sort_order)

    {length(student_exceptions),
     student_exceptions |> Enum.drop(params.offset) |> Enum.take(params.limit),
     student_exceptions}
  end

  defp filter_by_selected_assessment(student_exceptions, assessment_id) do
    Enum.filter(student_exceptions, fn se -> se.resource_id == assessment_id end)
  end

  defp sort_by(student_exceptions, sort_by, sort_order) do
    case sort_by do
      :student ->
        Enum.sort_by(student_exceptions, fn se -> se.user.name end, sort_order)

      :available_date ->
        Enum.sort_by(student_exceptions, fn se -> se.start_date end, sort_order)

      :due_date ->
        Enum.sort_by(
          student_exceptions,
          fn se -> if se.scheduling_type == :due_by, do: se.end_date, else: nil end,
          sort_order
        )

      _ ->
        Enum.sort_by(student_exceptions, fn se -> Map.get(se, sort_by) end, sort_order)
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
        key not in [
          :__struct__,
          :collab_space_config,
          :explanation_strategy,
          :exceptions_count,
          :name,
          :scheduling_type,
          :feedback_scheduled_date
        ]
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

  defp value_from_datetime(nil, _ctx), do: nil

  defp value_from_datetime(datetime, ctx) do
    datetime
    |> FormatDateTime.convert_datetime(ctx)
    |> FormatDateTime.format_datetime(precision: :simple_iso8601)
  end

  defp update_liveview_student_exceptions(action, student_exceptions, update_sort_order) do
    send(self(), {:student_exception, action, student_exceptions, update_sort_order})
  end

  defp decode_target(params, ctx) do
    [target_str] = params["_target"]
    [key, id] = String.split(target_str, "-")

    value =
      case {key, Map.get(params, target_str)} do
        {key, value}
        when key in [
               "late_submit",
               "late_start",
               "retake_mode",
               "assessment_mode",
               "feedback_mode",
               "review_submission"
             ] ->
          String.to_existing_atom(value)

        {key, value}
        when key in ["scoring_strategy_id", "time_limit", "max_attempts"] and value != "" ->
          abs(String.to_integer(value))

        {key, value} when key in ["start_date", "end_date"] ->
          FormatDateTime.datestring_to_utc_datetime(value, ctx)

        {_, value} ->
          value
      end

    {String.to_existing_atom(key), String.to_integer(id), value}
  end

  defp flash_to_liveview(socket, type, message) do
    send(self(), {:flash_message, type, message})
    socket
  end
end
