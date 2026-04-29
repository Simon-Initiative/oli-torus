defmodule OliWeb.Sections.AssessmentSettings.SettingsTable do
  use OliWeb, :live_component

  import Ecto.Query, only: [from: 2]
  import OliWeb.ErrorHelpers
  import Phoenix.HTML.Form

  alias Oli.Accounts.Author
  alias Oli.Delivery.DepotCoordinator
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Settings
  alias Oli.Delivery.Settings.AssessmentSettings
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo
  alias Oli.Utils
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Common.PagedTable
  alias OliWeb.Common.Paging
  alias OliWeb.Common.Params
  alias OliWeb.Common.Utils, as: CommonUtils
  alias OliWeb.Common.SearchInput
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.AssessmentSettings.SettingsTableModel
  alias Phoenix.LiveView.JS

  @default_params %{
    offset: 0,
    limit: 10,
    sort_order: :asc,
    sort_by: :index,
    text_search: nil,
    bulk_apply_selected_assessment_id: nil
  }

  def mount(socket) do
    {:ok, assign(socket, modal_assigns: %{show: false})}
  end

  def update(%{update_sort_order: false} = _assigns, socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    params = decode_params(assigns.params)

    {total_count, rows} = apply_filters(assigns.assessments, params)

    {:ok, table_model} =
      SettingsTableModel.new(
        rows,
        assigns.section.slug,
        assigns.ctx,
        JS.push("edit_date", target: socket.assigns.myself),
        JS.push("edit_password", target: socket.assigns.myself),
        JS.push("no_edit_password", target: socket.assigns.myself),
        nil,
        include_student_exceptions?: assigns.section.type != :blueprint
      )

    table_model =
      Map.merge(table_model, %{
        rows: rows,
        sort_order: params.sort_order,
        sort_by_spec:
          Enum.find(table_model.column_specs, fn col_spec ->
            col_spec.name == params.sort_by
          end)
      })

    {:ok,
     assign(socket,
       table_model: table_model,
       total_count: total_count,
       params: params,
       section: assigns.section,
       user: assigns.user,
       ctx: assigns.ctx,
       assessments: assigns.assessments,
       form_id: UUID.uuid4(),
       bulk_apply_selected_assessment_id:
         get_valid_assessment_id(assigns.assessments, params.bulk_apply_selected_assessment_id),
       selected_assessment: nil
     )}
  end

  attr(:assessments, :list, required: true)
  attr(:params, :map, required: true)
  attr(:section, :map, required: true)
  attr(:ctx, :map, required: true)
  attr(:update_sort_order, :boolean, required: true)

  attr(:flash, :map)
  attr(:table_model, :map)
  attr(:modal_assigns, :map)
  attr(:total_count, :integer)
  attr(:form_id, :string)
  attr(:bulk_apply_selected_assessment_id, :integer)
  attr(:selected_assessment, :map)

  def render(assigns) do
    ~H"""
    <div id="settings_table" class="bg-white dark:bg-gray-800 shadow-sm">
      {due_date_modal(assigns)}
      {available_date_modal(assigns)}
      {modal(@modal_assigns)}
      <div class="flex flex-col space-y-4 lg:space-y-0 lg:flex-row lg:items-center lg:justify-between pr-6 mb-4">
        <div class="flex flex-col pl-9">
          <h4 class="torus-h4 whitespace-nowrap">Assessment Settings</h4>
          <p>These are your current assessment settings.</p>
        </div>
        <form
          for="bulk_apply_settings"
          phx-target={@myself}
          phx-submit="bulk_apply"
          class="ml-9 flex space-x-4 items-center lg:flex-col lg:pb-0 lg:pt-6 lg:items-start lg:space-x-0"
        >
          <label>Copy and apply settings from one assessment to all:</label>
          <div class="flex lg:space-x-4 lg:mt-2">
            <select
              id="assessment_select"
              class="torus-select"
              name="assessment_id"
              phx-target={@myself}
              phx-change="select_assessment"
            >
              <option
                :for={assessment <- @assessments}
                selected={assessment.resource_id == @bulk_apply_selected_assessment_id}
                value={assessment.resource_id}
              >
                {assessment.name_with_container_label}
              </option>
            </select>
            <button
              type="submit"
              class="torus-button flex justify-center primary h-9 px-4 whitespace-nowrap lg:ml-4"
            >
              Bulk apply
            </button>
          </div>
        </form>
        <form
          for="search"
          phx-target={@myself}
          phx-change="search_assessment"
          class="pb-6 ml-9 sm:pb-0 w-56"
        >
          <SearchInput.render
            id="assessments_search_input"
            name="assessment_name"
            text={@params.text_search}
          />
        </form>
      </div>
      <Paging.render
        id="header_paging"
        total_count={@total_count}
        offset={@params.offset}
        limit={@params.limit}
        click={JS.push("paged_table_page_change", target: @myself)}
      />
      <form
        id={"form-#{@form_id}"}
        for="settings_table"
        phx-target={@myself}
        phx-change="update_setting"
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
      id="assessment_available_date_modal"
      title={if @selected_assessment, do: "#{@selected_assessment.name} available date"}
      module={OliWeb.Components.LiveModal}
      on_confirm={
        JS.dispatch("submit", to: "#assessment-available-date-form")
        |> JS.push("close", target: "#assessment_available_date_modal")
      }
      on_confirm_label="Save"
    >
      <div class="p-4">
        <form
          id="assessment-available-date-form"
          for="settings_table"
          phx-target={@myself}
          phx-submit="edit_date"
        >
          <label for="start_date_input">
            Please pick an available date for the selected assessment
          </label>
          <div class="flex gap-2 items-center mt-2">
            <input
              id="start_date_input"
              name="start_date"
              type="datetime-local"
              max={CommonUtils.datetime_input_limit(:start_date, @selected_assessment, @ctx)}
              phx-debounce={500}
              value={value_from_datetime(@selected_assessment.start_date, @ctx)}
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
      id="assessment_due_date_modal"
      title={if @selected_assessment, do: "#{@selected_assessment.name} due date"}
      module={OliWeb.Components.LiveModal}
      on_confirm={
        JS.dispatch("submit", to: "#assessment-due-date-form")
        |> JS.push("close", target: "#assessment_due_date_modal")
      }
      on_confirm_label="Save"
    >
      <div class="p-4">
        <form
          id="assessment-due-date-form"
          for="settings_table"
          phx-target={@myself}
          phx-submit="edit_date"
        >
          <label for="end_date_input">Please pick a due date for the selected assessment</label>
          <div class="flex gap-2 items-center mt-2">
            <input
              id="end_date_input"
              name="end_date"
              type="datetime-local"
              min={CommonUtils.datetime_input_limit(:end_date, @selected_assessment, @ctx)}
              phx-debounce={500}
              value={value_from_datetime(@selected_assessment.end_date, @ctx)}
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
                {label(f, :feedback_scheduled_date, "Scheduled Date", class: "control-label")}
                {datetime_local_input(f, :feedback_scheduled_date, class: "mr-auto")}
                {error_tag(f, :feedback_scheduled_date, true)}
              </div>
              <div class="flex space-x-3 mt-6 justify-end">
                <button
                  type="button"
                  id="scheduled_cancel_button"
                  class="btn btn-link"
                  phx-click="cancel_scheduled_modal"
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

  def modal(%{show: "confirm_bulk_apply"} = assigns) do
    ~H"""
    <div
      id="confirm_bulk_apply_modal"
      class="modal fade show bg-gray-900 bg-opacity-50"
      tabindex="-1"
      role="dialog"
      aria-hidden="true"
      style="display: block;"
      phx-window-keydown={JS.dispatch("click", to: "#cancel_bulk_apply_button")}
      phx-key="Escape"
    >
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Confirm Bulk Apply</h5>
            <button
              type="button"
              class="btn-close box-content w-4 h-4 p-1 border-none rounded-none opacity-50 focus:shadow-none focus:outline-none focus:opacity-100 hover:opacity-75 hover:no-underline"
              aria-label="Close"
              phx-click={JS.dispatch("click", to: "#cancel_bulk_apply_button")}
            >
              <i class="fa-solid fa-xmark fa-xl" />
            </button>
          </div>
          <div class="modal-body">
            <.form
              for={%{}}
              as={:confirm_bulk_apply}
              phx-submit="confirm_bulk_apply"
              phx-target={@myself}
            >
              <div class="flex flex-col space-y-2">
                <p>
                  Are you sure you want to apply the <strong>{@base_assessment.name}</strong>
                  settings to all other assessments?
                </p>
              </div>
              <div class="flex space-x-3 mt-6 justify-end">
                <button
                  type="button"
                  id="cancel_bulk_apply_button"
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

  def modal(%{show: false}), do: nil

  def handle_event("edit_date", %{"assessment_id" => assessment_id}, socket) do
    base_assessment =
      Enum.find(socket.assigns.assessments, fn a ->
        a.resource_id == String.to_integer(assessment_id)
      end)

    {:noreply, assign(socket, selected_assessment: base_assessment)}
  end

  def handle_event("edit_date", %{"start_date" => start_date}, socket),
    do: on_edit_date(:start_date, start_date, socket)

  def handle_event("edit_date", %{"end_date" => end_date}, socket),
    do: on_edit_date(:end_date, end_date, socket)

  def handle_event("hide_modal", _params, socket) do
    {:noreply,
     assign(socket,
       modal_assigns: %{show: false}
     )}
  end

  def handle_event("bulk_apply", %{"assessment_id" => assessment_id}, socket) do
    base_assessment =
      Enum.find(socket.assigns.assessments, fn a ->
        a.resource_id == String.to_integer(assessment_id)
      end)

    {:noreply,
     assign(socket,
       modal_assigns: %{
         show: "confirm_bulk_apply",
         myself: socket.assigns.myself,
         base_assessment: base_assessment
       },
       bulk_apply_selected_assessment_id: base_assessment.resource_id
     )}
  end

  def handle_event("select_assessment", %{"assessment_id" => assessment_id}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Sections.AssessmentSettings.SettingsLive,
           socket.assigns.section.slug,
           :all,
           update_params(socket.assigns.params, %{
             bulk_apply_selected_assessment_id: String.to_integer(assessment_id)
           })
         )
     )}
  end

  def handle_event(
        "search_assessment",
        %{"assessment_name" => assessment_name},
        socket
      ) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Sections.AssessmentSettings.SettingsLive,
           socket.assigns.section.slug,
           :all,
           update_params(socket.assigns.params, %{
             text_search: assessment_name,
             offset: 0,
             bulk_apply_selected_assessment_id: socket.assigns.bulk_apply_selected_assessment_id
           })
         )
     )}
  end

  def handle_event("confirm_bulk_apply", _params, socket) do
    %{
      section: section,
      user: user,
      assessments: assessments,
      modal_assigns: %{base_assessment: base_assessment}
    } =
      socket.assigns

    set_values =
      if(base_assessment.feedback_mode == :scheduled,
        do: [feedback_scheduled_date: base_assessment.feedback_scheduled_date],
        else: []
      ) ++
        [
          max_attempts: base_assessment.max_attempts,
          retake_mode: base_assessment.retake_mode,
          assessment_mode: base_assessment.assessment_mode,
          late_submit: base_assessment.late_submit,
          late_start: base_assessment.late_start,
          time_limit: base_assessment.time_limit,
          grace_period: base_assessment.grace_period,
          scoring_strategy_id: base_assessment.scoring_strategy_id,
          review_submission: base_assessment.review_submission,
          feedback_mode: base_assessment.feedback_mode,
          password: base_assessment.password
        ]

    from(
      [sr, _s, _spp, _pr, rev] in DeliveryResolver.section_resource_revisions(
        socket.assigns.section.slug
      ),
      where:
        rev.resource_type_id == 1 and rev.graded == true and
          sr.resource_id != ^base_assessment.resource_id,
      select: sr
    )
    |> Repo.update_all(set: set_values)

    # Instruct the DepotCoordinator to update the SRS for these assessments
    srs = get_assessment_srs(socket.assigns.section.id, Enum.map(assessments, & &1.resource_id))

    DepotCoordinator.update_all(SectionResourceDepot.depot_desc(), srs)

    settings_changes =
      assessments
      |> Enum.filter(fn a -> a.resource_id != base_assessment.resource_id end)
      |> Enum.flat_map(&generate_setting_changes(&1, set_values, section.id, user))

    Settings.bulk_insert_settings_changes(settings_changes)

    {:noreply,
     redirect(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Sections.AssessmentSettings.SettingsLive,
           socket.assigns.section.slug,
           :all,
           update_params(socket.assigns.params, %{
             bulk_apply_selected_assessment_id: socket.assigns.bulk_apply_selected_assessment_id
           })
         )
     )}
  end

  def handle_event(
        "paged_table_page_change",
        %{"limit" => limit, "offset" => offset},
        socket
      ) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Sections.AssessmentSettings.SettingsLive,
           socket.assigns.section.slug,
           :all,
           update_params(socket.assigns.params, %{
             limit: limit,
             offset: offset,
             bulk_apply_selected_assessment_id: socket.assigns.bulk_apply_selected_assessment_id
           })
         )
     )}
  end

  def handle_event(
        "paged_table_sort",
        %{"sort_by" => sort_by} = _params,
        socket
      ) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Sections.AssessmentSettings.SettingsLive,
           socket.assigns.section.slug,
           :all,
           update_params(socket.assigns.params, %{
             sort_by: String.to_existing_atom(sort_by),
             bulk_apply_selected_assessment_id: socket.assigns.bulk_apply_selected_assessment_id
           })
         )
     )}
  end

  def handle_event(event, params, socket) when event in ["no_edit_password", "edit_password"] do
    edit_password_id =
      case params["assessment_id"] do
        nil -> nil
        assessment_id -> String.to_integer(assessment_id)
      end

    {:ok, table_model} =
      SettingsTableModel.new(
        socket.assigns.table_model.rows,
        socket.assigns.section.slug,
        socket.assigns.ctx,
        JS.push("edit_date", target: socket.assigns.myself),
        JS.push("edit_password", target: socket.assigns.myself),
        JS.push("no_edit_password", target: socket.assigns.myself),
        edit_password_id,
        include_student_exceptions?: socket.assigns.section.type != :blueprint
      )

    {:noreply,
     assign(socket,
       table_model: table_model
     )}
  end

  def handle_event("update_setting", params, socket) do
    %{section: section, ctx: ctx, user: user, assessments: assessments} = socket.assigns

    case decode_target(params, ctx) do
      {:feedback_mode, assessment_setting_id, :scheduled} ->
        assessment_for_scheduled =
          Sections.get_section_resource(section.id, assessment_setting_id)
          |> Map.update(:feedback_scheduled_date, nil, fn scheduled_date ->
            value_from_datetime(scheduled_date, ctx)
          end)

        changeset =
          SectionResource.changeset(assessment_for_scheduled, %{feedback_mode: :scheduled})

        {:noreply,
         assign(socket,
           modal_assigns: %{
             show: "scheduled_feedback",
             changeset: changeset,
             assessment_for_scheduled: assessment_for_scheduled,
             myself: socket.assigns.myself
           }
         )}

      {key = :password, assessment_setting_id, new_value} ->
        AssessmentSettings.update(
          section,
          user,
          assessment_setting_id,
          %{key => new_value},
          %{assessments: assessments, ctx: ctx}
        )
        |> process_updated_result(socket)

      {key, assessment_setting_id, new_value} when new_value != "" ->
        AssessmentSettings.update(
          section,
          user,
          assessment_setting_id,
          %{key => new_value},
          %{assessments: assessments, ctx: ctx}
        )
        |> process_updated_result(socket)

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("cancel_scheduled_modal", _params, socket) do
    {:noreply, assign(socket, modal_assigns: %{show: false})}
  end

  def handle_event(
        "validate_scheduled_date",
        %{
          "section_resource" => %{
            "feedback_scheduled_date" => feedback_scheduled_date
          }
        },
        socket
      ) do
    changeset =
      socket.assigns.modal_assigns.assessment_for_scheduled
      |> SectionResource.changeset(%{
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
          "section_resource" => %{
            "feedback_scheduled_date" => feedback_scheduled_date
          }
        },
        socket
      ) do
    %{section: section, ctx: ctx, user: user, assessments: assessments} = socket.assigns
    assessment = socket.assigns.modal_assigns.assessment_for_scheduled

    AssessmentSettings.update(
      section,
      user,
      assessment.resource_id,
      %{
        feedback_mode: :scheduled,
        feedback_scheduled_date: feedback_scheduled_date
      },
      %{assessments: assessments, ctx: ctx}
    )
    |> case do
      {:ok, result} ->
        {:noreply,
         socket
         |> refresh_assessment(result.assessment, false)
         |> flash_to_liveview(:info, "Setting updated!")
         |> assign(modal_assigns: %{show: false})
         |> assign(form_id: UUID.uuid4())}

      {:error, :update_section_resource, changeset, _} ->
        {:noreply,
         assign(socket,
           modal_assigns: Map.merge(socket.assigns.modal_assigns, %{changeset: changeset})
         )}

      {:error, :get_section_resource, message, _} ->
        {:noreply, flash_to_liveview(socket, :error, message)}

      {:error, :settings_changes, _, _} ->
        {:noreply, flash_to_liveview(socket, :error, "ERROR: Failed to insert the setting")}

      {:error, {:invalid_feedback_schedule, :feedback_scheduled_date_required}} ->
        changeset =
          socket.assigns.modal_assigns.assessment_for_scheduled
          |> SectionResource.changeset(%{
            feedback_scheduled_date: feedback_scheduled_date,
            feedback_mode: :scheduled
          })
          |> Ecto.Changeset.validate_required(:feedback_scheduled_date)
          |> Map.put(:action, :validate)

        {:noreply,
         assign(socket,
           modal_assigns: Map.merge(socket.assigns.modal_assigns, %{changeset: changeset})
         )}
    end
  end

  defp process_updated_result({:ok, %{assessment: assessment}}, socket) do
    {:noreply,
     refresh_assessment(socket, assessment, false)
     |> flash_to_liveview(:info, "Setting updated!")}
  end

  defp process_updated_result({:error, :update_section_resource, _, _}, socket) do
    {:noreply, flash_to_liveview(socket, :error, "ERROR: Failed to update the section resource")}
  end

  defp process_updated_result({:error, :get_section_resource, message, _}, socket) do
    {:noreply, flash_to_liveview(socket, :error, message)}
  end

  defp process_updated_result({:error, :settings_changes, _, _}, socket) do
    {:noreply, flash_to_liveview(socket, :error, "ERROR: Failed to insert the setting")}
  end

  defp generate_setting_changes(assessment, values, section_id, user) do
    date = DateTime.utc_now() |> DateTime.truncate(:second)

    Enum.map(values, fn {key, new_value} ->
      old_value = Map.get(assessment, key, nil)

      %{
        resource_id: assessment.resource_id,
        section_id: section_id,
        user_id: user.id,
        user_type: get_user_type(user),
        key: Atom.to_string(key),
        new_value: stringify_setting_value(new_value),
        old_value: stringify_setting_value(old_value),
        inserted_at: date,
        updated_at: date
      }
    end)
  end

  defp stringify_setting_value(nil), do: nil
  defp stringify_setting_value(value), do: Kernel.to_string(value)

  defp on_edit_date(date_field, new_date, socket) do
    assessment = socket.assigns.selected_assessment
    %{section: section, ctx: ctx, user: user, assessments: assessments} = socket.assigns

    AssessmentSettings.update(
      section,
      user,
      assessment.resource_id,
      %{date_field => new_date},
      %{assessments: assessments, ctx: ctx}
    )
    |> case do
      {:ok, %{assessment: updated_assessment, applied_changes: applied_changes}} ->
        {:noreply,
         socket
         |> refresh_assessment(updated_assessment, false)
         |> flash_to_liveview(
           :info,
           "Setting updated.#{date_adjustment_message(date_field, applied_changes)}"
         )}

      {:error, :settings_changes, _, _} ->
        {:noreply,
         socket
         |> flash_to_liveview(:error, "ERROR: Setting change not be inserted")}

      _ ->
        {:noreply,
         socket
         |> flash_to_liveview(:error, "ERROR: Setting could not be updated")}
    end
  end

  defp date_adjustment_message(:start_date, %{end_date: _}),
    do:
      " The due date was adjusted to preserve the time distance between the start and end dates."

  defp date_adjustment_message(:end_date, %{start_date: _}),
    do:
      " The available date was adjusted to preserve the time distance between the start and end dates."

  defp date_adjustment_message(_date_field, _applied_changes), do: ""

  defp update_assessments(socket, assessment_setting_id, key_value_list, update_sort_order) do
    %{assigns: %{section: section, table_model: table_model}} = socket
    student_exceptions = AssessmentSettings.get_student_exceptions(section.id)
    assessments = AssessmentSettings.get_assessments(section, student_exceptions)

    {updated_assessment, updated_assessments} =
      Enum.reduce(assessments, {nil, []}, fn assessment, acc ->
        {current_assesment, current_assessments} = acc

        if assessment.resource_id == assessment_setting_id do
          updated_assessment = assessment |> Map.merge(Map.new(key_value_list))

          {updated_assessment, [updated_assessment | current_assessments]}
        else
          {current_assesment, [assessment | current_assessments]}
        end
      end)

    updated_rows =
      Enum.reduce(table_model.rows, [], fn row, acc ->
        if row.resource_id == assessment_setting_id do
          [updated_assessment | acc]
        else
          [row | acc]
        end
      end)
      |> Enum.reverse()

    updated_table_model = Map.merge(table_model, %{rows: updated_rows})

    send(self(), {:assessment_updated, updated_assessment, update_sort_order})

    assign(socket, assessments: updated_assessments, table_model: updated_table_model)
  end

  defp refresh_assessment(socket, assessment, update_sort_order) do
    refresh_keys =
      AssessmentSettings.supported_keys() ++
        [:scheduling_type, :name, :name_with_container_label, :exceptions_count, :index]

    key_value_list =
      Enum.map(refresh_keys, fn key ->
        {key, Map.get(assessment, key)}
      end)

    update_assessments(socket, assessment.resource_id, key_value_list, update_sort_order)
  end

  defp decode_target(params, ctx) do
    [target_str] = params["_target"]
    [key, id] = String.split(target_str, "-")

    value =
      case {key, Map.get(params, target_str)} do
        {key, value}
        when key in ~w(late_policy retake_mode assessment_mode feedback_mode review_submission replacement_strategy) ->
          String.to_existing_atom(value)

        {key, value}
        when key in ~w(scoring_strategy_id time_limit max_attempts) and value != "" ->
          abs(String.to_integer(value))

        {key, value} when key in ~w(start_date end_date) ->
          FormatDateTime.datestring_to_utc_datetime(value, ctx)

        {key, value} when key in ~w(allow_hints batch_scoring) ->
          Utils.string_to_boolean(value)

        {_, value} ->
          value
      end

    {String.to_existing_atom(key), String.to_integer(id), value}
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
            :name,
            :available_date,
            :due_date,
            :max_attempts,
            :time_limit,
            :late_policy,
            :scoring,
            :grace_period,
            :retake_mode,
            :assessment_mode,
            :feedback_mode,
            :review_submission,
            :exceptions_count,
            :scoring_strategy_id,
            :allow_hints
          ],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search),
      bulk_apply_selected_assessment_id:
        Params.get_int_param(
          params,
          "bulk_apply_selected_assessment_id",
          @default_params.bulk_apply_selected_assessment_id
        )
    }
  end

  defp apply_filters(assessments, params) do
    assessments =
      assessments
      |> maybe_filter_by_text(params.text_search)
      |> sort_by(params.sort_by, params.sort_order)

    {length(assessments), assessments |> Enum.drop(params.offset) |> Enum.take(params.limit)}
  end

  defp maybe_filter_by_text(assessments, nil), do: assessments
  defp maybe_filter_by_text(assessments, ""), do: assessments

  defp maybe_filter_by_text(assessments, text_search) do
    Enum.filter(assessments, fn assessment ->
      String.contains?(
        String.downcase(assessment.name),
        String.downcase(text_search)
      )
    end)
  end

  defp sort_by(assessments, sort_by, sort_order) do
    to_unix = fn
      nil -> 0
      datetime -> DateTime.to_unix(datetime)
    end

    case sort_by do
      :late_policy ->
        Enum.sort_by(
          assessments,
          fn
            %{late_start: :allow, late_submit: :allow} -> 1
            %{late_start: :disallow, late_submit: :allow} -> 2
            %{late_start: :disallow, late_submit: :disallow} -> 3
          end,
          sort_order
        )

      :available_date ->
        Enum.sort_by(assessments, fn a -> to_unix.(a.start_date) end, sort_order)

      :due_date ->
        Enum.sort_by(
          assessments,
          fn a ->
            if a.scheduling_type == :due_by, do: to_unix.(a.end_date), else: 0
          end,
          sort_order
        )

      _ ->
        Enum.sort_by(assessments, fn a -> Map.get(a, sort_by) end, sort_order)
    end
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
    |> purge_default_params()
  end

  defp purge_default_params(params) do
    # there is no need to add a param to the url if its value is equal to the default one
    Map.filter(params, fn {key, value} ->
      @default_params[key] != value
    end)
  end

  defp value_from_datetime(nil, _ctx), do: nil

  defp value_from_datetime(datetime, ctx) do
    datetime
    |> FormatDateTime.convert_datetime(ctx)
    |> FormatDateTime.format_datetime(precision: :simple_iso8601)
  end

  defp flash_to_liveview(socket, type, message) do
    send(self(), {:flash_message, type, message})
    socket
  end

  defp get_user_type(%Author{} = _), do: :author
  defp get_user_type(_), do: :instructor

  defp get_assessment_srs(section_id, resource_ids) do
    Repo.all(
      from(s in SectionResource,
        where: s.section_id == ^section_id and s.resource_id in ^resource_ids,
        select: s
      )
    )
  end

  defp get_valid_assessment_id([], _), do: nil

  defp get_valid_assessment_id(assessments, nil),
    do: hd(assessments).resource_id

  defp get_valid_assessment_id(_assessments, id), do: id
end
