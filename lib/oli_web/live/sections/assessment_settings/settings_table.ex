defmodule OliWeb.Sections.AssessmentSettings.SettingsTable do
  use Surface.LiveComponent

  import Phoenix.HTML.Form
  import OliWeb.ErrorHelpers

  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Common.{PagedTable, SearchInput}

  alias OliWeb.Sections.AssessmentSettings.SettingsTableModel
  alias OliWeb.Common.Params
  alias Phoenix.LiveView.JS
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Repo

  prop(assessments, :list, required: true)
  prop(params, :map, required: true)
  prop(section, :map, required: true)
  prop(context, :map, required: true)

  data(flash, :map)
  data(table_model, :map)
  data(modal_assigns, :map)
  data(total_count, :integer)

  @default_params %{
    offset: 0,
    limit: 25,
    sort_order: :asc,
    sort_by: :assessment,
    text_search: nil
  }

  def mount(socket) do
    {:ok, assign(socket, modal_assigns: %{show: false})}
  end

  def update(assigns, socket) do
    params = decode_params(assigns.params)

    {total_count, rows} = apply_filters(assigns.assessments, params)

    {:ok, table_model} = SettingsTableModel.new(rows, assigns.section.slug, assigns.context)

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
       context: assigns.context
     )}
  end

  def render(assigns) do
    ~F"""
    <div class="mx-10 mb-10 bg-white shadow-sm">
      {modal(@modal_assigns)}
      <div class="flex flex-col sm:flex-row sm:items-center pr-6 bg-white">
        <div class="flex flex-col pl-9 mr-auto">
          <h4 class="torus-h4">Assessment Settings</h4>
          <p>These are your current assessment settings.</p>
        </div>
        {flash_message(%{flash: @flash, myself: @myself})}
        <form for="search" phx-target={@myself} phx-change="search_assessment" class="pb-6 ml-9 sm:pb-0">
          <SearchInput.render
            id="assessments_search_input"
            name="assessment_name"
            text={@params.text_search}
          />
        </form>
      </div>
      <form for="settings_table" phx-target={@myself} phx-change="update_setting">
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
        />
      </form>
    </div>
    """
  end

  def flash_message(assigns) do
    ~F"""
    {#if live_flash(@flash, :info)}
      <div class="alert alert-info flex flex-row justify-between" role="alert">
        {live_flash(@flash, :info)}
        <button
          type="button"
          class="close ml-4"
          data-bs-dismiss="alert"
          aria-label="Close"
          phx-click="lv:clear-flash"
          phx-target={@myself}
          phx-value-key="info"
        >
          <i class="fa-solid fa-xmark fa-lg" />
        </button>
      </div>
    {/if}
    {#if live_flash(@flash, :error)}
      <div class="alert alert-danger flex flex-row justify-between" role="alert">
        {live_flash(@flash, :error)}
        <button
          type="button"
          class="close ml-4"
          data-bs-dismiss="alert"
          aria-label="Close"
          phx-click="lv:clear-flash"
          phx-target={@myself}
          phx-value-key="error"
        >
          <i class="fa-solid fa-xmark fa-lg" />
        </button>
      </div>
    {/if}
    """
  end

  def modal(%{show: true} = assigns) do
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
                  for={@changeset}
                  phx-submit="submit_scheduled_date"
                  phx-change="validate_scheduled_date"
                  phx-target={@myself}
                  :let={f}
                >
                  <div class="flex flex-col space-y-2">
                    <%= label f, :feedback_scheduled_date, "Scheduled Date", class: "control-label" %>
                    <%= datetime_local_input f, :feedback_scheduled_date, class: "mr-auto" %>
                    <%= error_tag f, :feedback_scheduled_date, true %>
                  </div>
                  <div class="flex space-x-3 mt-6 justify-end">
                    <button
                      type="button"
                      id="scheduled_cancel_button"
                      class="btn btn-link"
                      phx-click="cancel_scheduled_modal"
                      phx-target={@myself}
                    >Cancel</button>

                    <button
                      type="submit"
                      class="btn btn-primary"
                    >Save</button>
                  </div>
                </.form>
              </div>
            </div>
          </div>
        </div>
    """
  end

  def modal(%{show: false}), do: nil

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
           :settings,
           :all,
           update_params(socket.assigns.params, %{text_search: assessment_name})
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
           :settings,
           :all,
           update_params(socket.assigns.params, %{limit: limit, offset: offset})
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
           :settings,
           :all,
           update_params(socket.assigns.params, %{
             sort_by: String.to_existing_atom(sort_by)
           })
         )
     )}
  end

  def handle_event("update_setting", params, socket) do
    case decode_target(params, socket.assigns.context) do
      {:feedback_mode, assessment_setting_id, :scheduled} ->
        assessment_for_scheduled =
          Sections.get_section_resource(
            socket.assigns.section.id,
            assessment_setting_id
          )
          |> Map.update(
            :feedback_scheduled_date,
            nil,
            fn scheduled_date -> value_from_datetime(scheduled_date, socket.assigns.context) end
          )

        changeset =
          SectionResource.changeset(assessment_for_scheduled, %{
            feedback_mode: :scheduled
          })

        {:noreply,
         assign(socket,
           modal_assigns: %{
             show: true,
             changeset: changeset,
             assessment_for_scheduled: assessment_for_scheduled,
             myself: socket.assigns.myself
           }
         )}

      {key, assessment_setting_id, new_value} when new_value != "" ->
        Sections.get_section_resource(
          socket.assigns.section.id,
          assessment_setting_id
        )
        |> SectionResource.changeset(Map.new([{key, new_value}]))
        |> Repo.update()
        |> case do
          {:error, _changeset} ->
            {:noreply,
             socket
             |> clear_flash()
             |> put_flash(:error, "ERROR: Setting could not be updated")}

          {:ok, _section_resource} ->
            {:noreply,
             socket
             |> update_assessments(assessment_setting_id, [{key, new_value}])
             |> clear_flash()
             |> put_flash(:info, "Setting updated!")}
        end

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
    utc_datetime =
      FormatDateTime.datestring_to_utc_datetime(
        feedback_scheduled_date,
        socket.assigns.context
      )

    socket.assigns.modal_assigns.assessment_for_scheduled
    |> SectionResource.changeset(%{feedback_scheduled_date: utc_datetime})
    |> Ecto.Changeset.validate_required(:feedback_scheduled_date)
    |> Repo.update()
    |> case do
      {:error, changeset} ->
        {:noreply,
         assign(socket,
           modal_assigns: Map.merge(socket.assigns.modal_assigns, %{changeset: changeset})
         )}

      {:ok, _section_resource} ->
        {:noreply,
         socket
         |> update_assessments(
           socket.assigns.modal_assigns.changeset.data.resource_id,
           [
             {:feedback_scheduled_date, utc_datetime},
             {:feedback_mode, :scheduled}
           ]
         )
         |> clear_flash()
         |> put_flash(:info, "Setting updated!")
         |> assign(modal_assigns: %{show: false})}
    end
  end

  defp update_assessments(socket, assessment_setting_id, key_value_list) do
    updated_assessment =
      Enum.find(socket.assigns.table_model.rows, fn assessment ->
        assessment.resource_id == assessment_setting_id
      end)
      |> Map.merge(Map.new(key_value_list))

    send(self(), {:assessment_updated, updated_assessment})

    socket
  end

  defp decode_target(params, context) do
    [target_str] = params["_target"]
    [key, id] = String.split(target_str, "-")

    value =
      case {key, Map.get(params, target_str)} do
        {key, value}
        when key in [
               "late_submit",
               "late_start",
               "retake_mode",
               "feedback_mode",
               "review_submission"
             ] ->
          String.to_existing_atom(value)

        {key, value}
        when key in ["scoring_strategy_id", "time_limit", "max_attempts"] and
               value != "" ->
          abs(String.to_integer(value))

        {"end_date", value} ->
          FormatDateTime.datestring_to_utc_datetime(value, context)

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
          [:assessment],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search)
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
    # TODO set other sort options
    case sort_by do
      :assessment ->
        Enum.sort_by(
          assessments,
          fn assessment ->
            assessment.name
          end,
          sort_order
        )

      _ ->
        Enum.sort_by(
          assessments,
          fn assessment ->
            assessment.name
          end,
          sort_order
        )
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

  defp value_from_datetime(nil, _context), do: nil

  defp value_from_datetime(datetime, context) do
    datetime
    |> FormatDateTime.convert_datetime(context)
    |> DateTime.to_iso8601()
    |> String.slice(0, 16)
  end
end
