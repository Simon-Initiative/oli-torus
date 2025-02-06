defmodule OliWeb.Components.Delivery.Students do
  use OliWeb, :live_component

  import OliWeb.Components.Delivery.Buttons, only: [toggle_chevron: 1]

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Accounts.{Author, User}
  alias Oli.Delivery.Metrics
  alias OliWeb.Common.{SearchInput, Params, Utils}
  alias OliWeb.Common.InstructorDashboardPagedTable
  alias OliWeb.Components.Delivery.CardHighlights
  alias OliWeb.Delivery.Content.Progress
  alias OliWeb.Delivery.InstructorDashboard.HTMLComponents
  alias OliWeb.Delivery.Sections.EnrollmentsTableModel
  alias OliWeb.Icons
  alias OliWeb.Router.Helpers, as: Routes
  alias Phoenix.LiveView.JS

  @default_params %{
    offset: 0,
    limit: 20,
    container_id: nil,
    section_slug: nil,
    page_id: nil,
    sort_order: :asc,
    sort_by: :name,
    text_search: nil,
    filter_by: :enrolled,
    payment_status: nil,
    selected_card_value: nil,
    container_filter_by: :students,
    navigation_data: Jason.encode!(%{}),
    progress_percentage: 100,
    progress_selector: nil,
    selected_proficiency_ids: Jason.encode!([])
  }

  @proficiency_options [
    %{id: 1, name: "Low", selected: false},
    %{id: 2, name: "Medium", selected: false},
    %{id: 3, name: "High", selected: false}
  ]

  def update(
        %{
          params: params,
          section: section,
          ctx: ctx,
          students: students,
          dropdown_options: dropdown_options
        } = assigns,
        socket
      ) do
    {total_count, rows} = apply_filters(students, params)

    {:ok, table_model} = EnrollmentsTableModel.new(rows, section, ctx)

    navigation_data = Jason.decode!(params.navigation_data)

    {previous_id, next_id} =
      case navigation_data["containers"] do
        nil ->
          {nil, nil}

        _ ->
          filtered_containers =
            filter_containers_by_option(navigation_data)

          get_navigation_ids(
            filtered_containers,
            navigation_data["current_container_id"]
          )
      end

    table_model =
      Map.merge(table_model, %{
        rows: rows,
        sort_order: params.sort_order,
        sort_by_spec:
          Enum.find(table_model.column_specs, fn col_spec -> col_spec.name == params.sort_by end)
      })

    selected_card_value = Map.get(assigns.params, :selected_card_value, nil)
    students_count = students_count(students, params.filter_by)

    card_props = [
      %{
        title: "Low Progress",
        count: Map.get(students_count, :low_progress),
        is_selected: selected_card_value == :low_progress,
        value: :low_progress
      },
      %{
        title: "Low Proficiency",
        count: Map.get(students_count, :low_proficiency),
        is_selected: selected_card_value == :low_proficiency,
        value: :low_proficiency
      },
      %{
        title: "Zero interaction in a week",
        count: Map.get(students_count, :zero_interaction_in_a_week),
        is_selected: selected_card_value == :zero_interaction_in_a_week,
        value: :zero_interaction_in_a_week
      }
    ]

    selected_proficiency_ids = Jason.decode!(params.selected_proficiency_ids)

    proficiency_options =
      update_proficiency_options(selected_proficiency_ids, @proficiency_options)

    selected_proficiency_options =
      Enum.reduce(proficiency_options, %{}, fn option, acc ->
        if option.selected,
          do: Map.put(acc, option.id, option.name),
          else: acc
      end)

    {:ok,
     assign(socket,
       id: assigns.id,
       total_count: total_count,
       table_model: table_model,
       params: params,
       section_slug: section.slug,
       section_open_and_free: section.open_and_free,
       dropdown_options: dropdown_options,
       view: assigns[:view],
       title: Map.get(assigns, :title, "Students"),
       tab_name: Map.get(assigns, :tab_name, :students),
       show_progress_csv_download: Map.get(assigns, :show_progress_csv_download, false),
       add_enrollments_step: :step_1,
       add_enrollments_selected_role: :student,
       add_enrollments_emails: [],
       add_enrollments_grouped_by_status: %{
         enrolled: [],
         suspended: [],
         pending_confirmation: [],
         rejected: [],
         non_existing_users: [],
         not_enrolled_users: []
       },
       add_enrollments_effective_count: 0,
       inviter: if(is_nil(ctx.author), do: "user", else: "author"),
       current_user: ctx.user,
       current_author: ctx.author,
       card_props: card_props,
       previous_id: previous_id,
       next_id: next_id,
       navigation_data: navigation_data,
       proficiency_options: proficiency_options,
       selected_proficiency_options: selected_proficiency_options,
       selected_proficiency_ids: selected_proficiency_ids
     )}
  end

  defp apply_filters(students, params) do
    students =
      students
      |> maybe_filter_by_text(params.text_search)
      |> maybe_filter_by_option(params.filter_by)
      |> maybe_filter_by_card(params.selected_card_value, params.filter_by)
      |> maybe_filter_by_progress(params.progress_selector, params.progress_percentage)
      |> maybe_filter_by_proficiency(params.selected_proficiency_ids)
      |> sort_by(params.sort_by, params.sort_order)

    {length(students), students |> Enum.drop(params.offset) |> Enum.take(params.limit)}
  end

  defp maybe_filter_by_proficiency(students, "[]") do
    students
  end

  defp maybe_filter_by_proficiency(students, selected_proficiency_ids) do
    selected_proficiency_ids = Jason.decode!(selected_proficiency_ids)

    mapper_ids =
      Enum.reduce(selected_proficiency_ids, [], fn id, acc ->
        case id do
          1 -> ["Low" | acc]
          2 -> ["Medium" | acc]
          3 -> ["High" | acc]
          _ -> acc
        end
      end)

    Enum.filter(students, fn student ->
      student.overall_proficiency in mapper_ids
    end)
  end

  defp maybe_filter_by_progress(students, progress_selector, percentage) do
    case progress_selector do
      :is_equal_to ->
        Enum.filter(students, fn student ->
          parse_progress(student.progress || 0.0) == percentage
        end)

      :is_less_than_or_equal ->
        Enum.filter(students, fn student ->
          parse_progress(student.progress || 0.0) <= percentage
        end)

      :is_greather_than_or_equal ->
        Enum.filter(students, fn student ->
          parse_progress(student.progress || 0.0) >= percentage
        end)

      nil ->
        students
    end
  end

  defp parse_progress(progress) do
    {progress, _} =
      Float.round(progress * 100)
      |> Float.to_string()
      |> Integer.parse()

    progress
  end

  defp maybe_filter_by_text(students, nil), do: students
  defp maybe_filter_by_text(students, ""), do: students

  defp maybe_filter_by_text(students, text_search) do
    Enum.filter(students, fn student ->
      String.contains?(
        String.downcase(Utils.name(student.name, student.given_name, student.family_name)),
        String.downcase(text_search)
      )
    end)
  end

  defp maybe_filter_by_card(students, :low_progress, filter_by) do
    Enum.filter(students, fn student ->
      Metrics.progress_range(student.progress) == "Low" ||
        (is_nil(student.progress) and is_learner_selected(student, filter_by))
    end)
  end

  defp maybe_filter_by_card(students, :low_proficiency, filter_by) do
    Enum.filter(students, fn student ->
      student.overall_proficiency == "Low" ||
        (is_nil(student.overall_proficiency) and is_learner_selected(student, filter_by))
    end)
  end

  defp maybe_filter_by_card(students, :zero_interaction_in_a_week, filter_by) do
    Enum.filter(students, fn student ->
      diff_days = Timex.Comparable.diff(DateTime.utc_now(), student.last_interaction, :days)

      diff_days > 7 and is_learner_selected(student, filter_by)
    end)
  end

  defp maybe_filter_by_card(students, _, _filter_by), do: students

  defp maybe_filter_by_option(students, dropdown_value) do
    case dropdown_value do
      :enrolled ->
        Enum.filter(students, fn student ->
          student.enrollment_status == :enrolled and
            student.user_role_id == 4
        end)

      :suspended ->
        Enum.filter(students, fn student ->
          student.enrollment_status == :suspended and
            student.user_role_id == 4
        end)

      :paid ->
        Enum.filter(students, fn student ->
          student.enrollment_status == :enrolled and
            student.user_role_id == 4 and student.payment_status == :paid
        end)

      :not_paid ->
        Enum.filter(students, fn student ->
          student.enrollment_status == :enrolled and
            student.user_role_id == 4 and student.payment_status == :not_paid
        end)

      :grace_period ->
        Enum.filter(students, fn student ->
          student.enrollment_status == :enrolled and
            student.user_role_id == 4 and student.payment_status == :within_grace_period
        end)

      :non_students ->
        Enum.filter(students, fn student ->
          student.enrollment_status == :enrolled and
            student.user_role_id != 4
        end)

      :pending_confirmation ->
        Enum.filter(students, fn student -> student.enrollment_status == :pending_confirmation end)

      :rejected ->
        Enum.filter(students, fn student -> student.enrollment_status == :rejected end)

      _ ->
        students
    end
  end

  defp sort_by(students, sort_by, sort_order) do
    case sort_by do
      :name ->
        Enum.sort_by(
          students,
          fn student -> Utils.name(student.name, student.given_name, student.family_name) end,
          sort_order
        )

      :email ->
        Enum.sort_by(students, fn student -> student.email end, sort_order)

      :last_interaction ->
        Enum.sort_by(students, & &1.last_interaction, {sort_order, DateTime})

      :progress ->
        Enum.sort_by(
          students,
          fn student -> {student.progress || 0, student.family_name} end,
          sort_order
        )

      :overall_proficiency ->
        Enum.sort_by(students, fn student -> student.overall_proficiency end, sort_order)

      :engagement ->
        Enum.sort_by(students, fn student -> student.engagement end, sort_order)

      :payment_status ->
        Enum.sort_by(
          students,
          &{&1.payment_status, &1.payment_date && DateTime.to_unix(&1.payment_date)},
          sort_order
        )

      _ ->
        Enum.sort_by(
          students,
          fn student -> Utils.name(student.name, student.given_name, student.family_name) end,
          sort_order
        )
    end
  end

  attr(:ctx, :map, required: true)
  attr(:title, :string, default: "Students")
  attr(:tab_name, :atom, default: :students)
  attr(:section_slug, :string, default: nil)
  attr(:section_open_and_free, :boolean, default: false)
  attr(:params, :map, required: true)
  attr(:total_count, :integer, required: true)
  attr(:table_model, :map, required: true)
  attr(:dropdown_options, :list, required: true)
  attr(:show_progress_csv_download, :boolean, default: false)
  attr(:view, :atom)
  attr(:add_enrollments_step, :atom, default: :step_1)
  attr(:add_enrollments_selected_role, :atom, default: :student)
  attr(:add_enrollments_emails, :list, default: [])
  attr(:current_user, :any, required: false)
  attr(:current_author, :any, required: false)
  attr(:inviter, :string, required: false)
  attr(:myself, :string, required: false)
  attr(:card_props, :list)
  attr(:previous_id, :integer)
  attr(:next_id, :integer)
  attr(:navigation_data, :map, required: true)

  def render(assigns) do
    ~H"""
    <div id={@id} class="flex flex-col gap-2 mx-10 mb-10">
      <.live_component
        module={OliWeb.Components.LiveModal}
        id="students_table_add_enrollments_modal"
        title="Add enrollments"
        on_confirm={
          case @add_enrollments_step do
            :step_1 ->
              JS.push("add_enrollments_go_to_step_2", target: @myself)

            :step_2 ->
              JS.push("add_enrollments_go_to_step_3", target: @myself)

            :step_3 ->
              if(@add_enrollments_effective_count > 0,
                do: JS.dispatch("click", to: "#add_enrollments_form button"),
                else:
                  JS.dispatch("click",
                    to: "#students_table_add_enrollments_modal_backdrop button[phx-click='close']"
                  )
              )
          end
        }
        on_confirm_label={if @add_enrollments_step == :step_3, do: "Confirm", else: "Next"}
        on_cancel={
          if @add_enrollments_step == :step_1,
            do: nil,
            else: JS.push("add_enrollments_go_to_step_1", target: @myself)
        }
        on_confirm_disabled={if length(@add_enrollments_emails) == 0, do: true, else: false}
        on_cancel_label={if @add_enrollments_step == :step_1, do: nil, else: "Back"}
      >
        <.add_enrollments
          add_enrollments_emails={@add_enrollments_emails}
          add_enrollments_step={@add_enrollments_step}
          add_enrollments_selected_role={@add_enrollments_selected_role}
          add_enrollments_grouped_by_status={@add_enrollments_grouped_by_status}
          add_enrollments_effective_count={@add_enrollments_effective_count}
          section_slug={@section_slug}
          target={@id}
          current_user={@current_user}
          current_author={@current_author}
          inviter={@inviter}
          myself={@myself}
        />
      </.live_component>
      <%= unless is_nil(@navigation_data["containers"]) do %>
        <div class="flex flex-col mb-8">
          <div class="flex mt-4 mb-2">
            <.link navigate={@navigation_data["request_path"]} role="back button">
              <div class="flex gap-2 items-center">
                <Icons.left_chevron_blue />
                <div class="text-zinc-700 text-sm font-semibold tracking-tight dark:text-white">
                  Back to <%= String.capitalize(@navigation_data["container_filter_by"]) %>
                </div>
              </div>
            </.link>
          </div>
          <div class="flex flex-row justify-center items-center">
            <div class="w-28 py-2 rounded-md justify-center items-center gap-2 inline-flex">
              <button
                disabled={is_nil(@previous_id)}
                phx-click="change_navigation"
                value={@previous_id}
                phx-target={@myself}
              >
                <Icons.previous_arrow color={if is_nil(@previous_id), do: "#a3a3a3", else: "#468AEF"} />
              </button>
            </div>
            <div class="w-auto px-2 py-1 rounded-md flex-col justify-center items-center text-center inline-flex">
              <div class="self-stretch text-zinc-700 text-xl font-bold leading-none tracking-tight dark:text-white">
                <%= @title %>
              </div>
            </div>
            <div class="w-auto py-2 flex rounded-md justify-center items-center gap-2">
              <button
                disabled={is_nil(@next_id)}
                phx-click="change_navigation"
                value={@next_id}
                phx-target={@myself}
              >
                <Icons.next_arrow color={if is_nil(@next_id), do: "#a3a3a3", else: "#468AEF"} />
              </button>
            </div>
          </div>
          <form phx-change="select_option" phx-target={@myself} id="container_option">
            <div class="flex justify-center items-center">
              <div class="flex flex-col items-start gap-y-2">
                <%= label class: "form-check-label flex flex-row items-center cursor-pointer gap-x-2" do %>
                  <%= radio_button(:container, :option, :by_filtered,
                    class: "form-check-input",
                    checked: @navigation_data["navigation_criteria"] == "by_filtered"
                  ) %>
                  <div class="w-full text-zinc-900 text-xs font-normal leading-none dark:text-white">
                    Navigate within <%= @navigation_data["filtered_count"] %> filtered <%= @navigation_data[
                      "container_filter_by"
                    ] %> <%= get_card_type(@navigation_data["filter_criteria_card"]) %>
                  </div>
                <% end %>
                <%= label class: "form-check-label flex flex-row items-center cursor-pointer gap-x-2" do %>
                  <%= radio_button(:container, :option, :by_all,
                    class: "form-check-input",
                    checked: @navigation_data["navigation_criteria"] == "by_all"
                  ) %>
                  <div class="w-full text-zinc-900 text-xs font-normal leading-none dark:text-white">
                    Navigate within ALL <%= @navigation_data["container_filter_by"] %>
                  </div>
                <% end %>
              </div>
            </div>
          </form>
        </div>
      <% end %>
      <div class="bg-white dark:bg-gray-800 shadow-sm">
        <div class="flex justify-between sm:items-end px-4 sm:px-9 py-4 instructor_dashboard_table">
          <div>
            <h4 class="torus-h4 !py-0 sm:mr-auto mb-2">Students Enrolled in <%= @title %></h4>
            <%= if @show_progress_csv_download do %>
              <a
                class="self-end"
                href={
                  Routes.metrics_path(
                    OliWeb.Endpoint,
                    :download_container_progress,
                    @section_slug,
                    @params.container_id || ""
                  )
                }
                download="progress.csv"
              >
                <i class="fa-solid fa-download mr-1" /> Download student progress CSV
              </a>
            <% else %>
              <a
                href={
                  Routes.delivery_path(OliWeb.Endpoint, :download_students_progress, @section_slug)
                }
                class="self-end"
              >
                <i class="fa-solid fa-download ml-1" /> Download
              </a>
            <% end %>
          </div>
          <div class="flex flex-col-reverse sm:flex-row gap-2 items-end">
            <button
              :if={@section_open_and_free}
              phx-click="open"
              phx-target="#students_table_add_enrollments_modal"
              class="torus-button primary mr-4"
            >
              Add Enrollments
            </button>
            <div class="flex w-full sm:w-auto sm:items-end gap-2">
              <form class="w-full" phx-change="filter_by" phx-target={@myself}>
                <label class="cursor-pointer inline-flex flex-col gap-1 w-full">
                  <small class="torus-small uppercase">Filter by</small>
                  <select class="torus-select" name="filter">
                    <option
                      :for={elem <- @dropdown_options}
                      selected={@params.filter_by == elem.value}
                      value={elem.value}
                    >
                      <%= elem.label %>
                    </option>
                  </select>
                </label>
              </form>
            </div>
          </div>
        </div>
        <div class="flex flex-row mx-9 my-4 gap-x-4">
          <%= for card <- @card_props do %>
            <CardHighlights.render
              title={card.title}
              count={card.count}
              is_selected={card.is_selected}
              value={card.value}
              on_click={JS.push("select_card", target: @myself)}
              container_filter_by={@params.container_filter_by}
            />
          <% end %>
        </div>

        <div class="flex gap-2 mx-9 mt-4 mb-10 ">
          <form for="search" phx-target={@myself} phx-change="search_student" class="w-56">
            <SearchInput.render
              id="students_search_input"
              name="student_name"
              text={@params.text_search}
            />
          </form>

          <Progress.render
            target={@myself}
            progress_percentage={@params.progress_percentage}
            progress_selector={@params.progress_selector}
          />

          <.multi_select
            id="proficiency_select"
            options={@proficiency_options}
            selected_values={@selected_proficiency_options}
            selected_proficiency_ids={@selected_proficiency_ids}
            target={@myself}
            disabled={@selected_proficiency_ids == %{}}
            placeholder="Proficiency"
          />

          <button
            class="text-center text-blue-500 text-xs font-semibold underline leading-none"
            phx-click="clear_all_filters"
            phx-target={@myself}
          >
            Clear All Filters
          </button>
        </div>

        <InstructorDashboardPagedTable.render
          table_model={@table_model}
          total_count={@total_count}
          offset={@params.offset}
          limit={@params.limit}
          render_top_info={false}
          additional_table_class="instructor_dashboard_table"
          sort={JS.push("paged_table_sort", target: @myself)}
          page_change={JS.push("paged_table_page_change", target: @myself)}
          limit_change={JS.push("paged_table_limit_change", target: @myself)}
          show_limit_change={true}
        />
        <HTMLComponents.view_example_student_progress_modal />
      </div>
    </div>
    """
  end

  attr :placeholder, :string, default: "Select an option"
  attr :disabled, :boolean, default: false
  attr :options, :list, default: []
  attr :id, :string
  attr :target, :map, default: %{}
  attr :selected_values, :map, default: %{}
  attr :selected_proficiency_ids, :list, default: []

  def multi_select(assigns) do
    ~H"""
    <div class={"flex flex-col border relative rounded-md h-9 #{if @selected_values != %{}, do: "border-blue-500", else: "border-zinc-400"}"}>
      <div
        phx-click={
          if(!@disabled,
            do:
              JS.toggle(to: "##{@id}-options-container")
              |> JS.toggle(to: "##{@id}-down-icon")
              |> JS.toggle(to: "##{@id}-up-icon")
          )
        }
        class={[
          "flex gap-x-4 px-4 h-9 justify-between items-center w-auto hover:cursor-pointer rounded",
          if(@disabled, do: "bg-gray-300 hover:cursor-not-allowed")
        ]}
        id={"#{@id}-selected-options-container"}
      >
        <div class="flex gap-1 flex-wrap">
          <span
            :if={@selected_values == %{}}
            class="text-zinc-900 text-xs font-semibold leading-none dark:text-white"
          >
            <%= @placeholder %>
          </span>
          <span :if={@selected_values != %{}} class="text-blue-500 text-xs font-semibold leading-none">
            Proficiency is <%= show_proficiency_selected_values(@selected_values) %>
          </span>
        </div>
        <.toggle_chevron id={@id} map_values={@selected_values} />
      </div>
      <div class="relative">
        <div
          class="py-4 hidden z-50 absolute dark:bg-gray-800 bg-white w-48 border overflow-y-scroll top-1 rounded"
          id={"#{@id}-options-container"}
          phx-click-away={
            JS.hide() |> JS.hide(to: "##{@id}-up-icon") |> JS.show(to: "##{@id}-down-icon")
          }
        >
          <div>
            <.form
              :let={_f}
              class="flex flex-column gap-y-3 px-4"
              for={%{}}
              as={:options}
              phx-change="toggle_selected"
              phx-target={@target}
            >
              <.input
                :for={option <- @options}
                name={option.id}
                value={option.selected}
                label={option.name}
                checked={option.id in @selected_proficiency_ids}
                type="checkbox"
                label_class="text-zinc-900 text-xs font-normal leading-none dark:text-white"
              />
            </.form>
          </div>
          <div class="w-full border border-gray-200 my-4"></div>
          <div class="flex flex-row items-center justify-end px-4 gap-x-4">
            <button
              class="text-center text-neutral-600 text-xs font-semibold leading-none dark:text-white"
              phx-click={
                JS.hide(to: "##{@id}-options-container")
                |> JS.hide(to: "##{@id}-up-icon")
                |> JS.show(to: "##{@id}-down-icon")
              }
            >
              Cancel
            </button>
            <button
              class="px-4 py-2 bg-blue-500 rounded justify-center items-center gap-2 inline-flex opacity-90 text-right text-white text-xs font-semibold leading-none"
              phx-click={
                JS.push("apply_proficiency_filter")
                |> JS.hide(to: "##{@id}-options-container")
                |> JS.hide(to: "##{@id}-up-icon")
                |> JS.show(to: "##{@id}-down-icon")
              }
              phx-target={@target}
              phx-value={@selected_proficiency_ids}
              disabled={@disabled}
            >
              Apply
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  #### Add enrollments modal related stuff ####
  def add_enrollments(%{add_enrollments_step: :step_1} = assigns) do
    ~H"""
    <div class="px-4">
      <p class="mb-2">
        Please write the email addresses of the users you want to invite to the course.
      </p>
      <OliWeb.Components.EmailList.render
        id="enrollments_email_list"
        emails_list={@add_enrollments_emails}
        on_update="add_enrollments_update_list"
        on_remove="add_enrollments_remove_from_list"
        target={@target}
      />
      <label class="flex flex-col mt-4 w-40 ml-auto">
        <small class="torus-small uppercase">Role</small>
        <form class="w-full" phx-change="add_enrollments_change_selected_role" phx-target={@myself}>
          <select name="role" class="torus-select w-full">
            <option selected={:instructor == @add_enrollments_selected_role} value={:instructor}>
              Instructor
            </option>
            <option selected={:student == @add_enrollments_selected_role} value={:student}>
              Student
            </option>
          </select>
        </form>
      </label>
    </div>
    """
  end

  def add_enrollments(%{add_enrollments_step: :step_2} = assigns) do
    ~H"""
    <div class="px-4 flex flex-col space-y-4">
      <div
        :if={@add_enrollments_grouped_by_status[:non_existing_users] not in [[], nil]}
        id="non_existing_users"
      >
        <p>
          The following emails don't exist in the database. If you still want to proceed, an email will be sent and they
          will become enrolled once they sign up. Please, review them and click on "Next" to continue.
        </p>
        <div>
          <li class="list-none mt-4 max-h-80 overflow-y-scroll">
            <%= for email <- @add_enrollments_grouped_by_status[:non_existing_users] do %>
              <ul class="odd:bg-gray-200 dark:odd:bg-neutral-600 even:bg-gray-100 dark:even:bg-neutral-500 p-2 first:rounded-t last:rounded-b">
                <div class="flex items-center justify-between">
                  <p><%= email %></p>
                  <button
                    phx-click={
                      JS.push("add_enrollments_remove_from_list",
                        value: %{email: email, status: :non_existing_users},
                        target: "##{@target}"
                      )
                    }
                    class="torus-button error"
                  >
                    Remove
                  </button>
                </div>
              </ul>
            <% end %>
          </li>
        </div>
      </div>

      <div
        :if={@add_enrollments_grouped_by_status[:pending_confirmation] not in [[], nil]}
        id="pending_confirmation_enrollments"
      >
        <p>
          The following emails have a "pending confirmation" invitation. A new invitation will be sent by email.
        </p>
        <div>
          <li class="list-none mt-4 max-h-80 overflow-y-scroll">
            <%= for email <- @add_enrollments_grouped_by_status[:pending_confirmation] do %>
              <ul class="odd:bg-gray-200 dark:odd:bg-neutral-600 even:bg-gray-100 dark:even:bg-neutral-500 p-2 first:rounded-t last:rounded-b">
                <div class="flex items-center justify-between">
                  <p><%= email %></p>
                  <button
                    phx-click={
                      JS.push("add_enrollments_remove_from_list",
                        value: %{email: email, status: :pending_confirmation},
                        target: "##{@target}"
                      )
                    }
                    class="torus-button error"
                  >
                    Remove
                  </button>
                </div>
              </ul>
            <% end %>
          </li>
        </div>
      </div>

      <div
        :if={@add_enrollments_grouped_by_status[:rejected] not in [[], nil]}
        id="rejected_enrollments"
      >
        <p>
          The following emails have a "rejected" invitation. A new invitation will be sent by email.
        </p>
        <div>
          <li class="list-none mt-4 max-h-80 overflow-y-scroll">
            <%= for email <- @add_enrollments_grouped_by_status[:rejected] do %>
              <ul class="odd:bg-gray-200 dark:odd:bg-neutral-600 even:bg-gray-100 dark:even:bg-neutral-500 p-2 first:rounded-t last:rounded-b">
                <div class="flex items-center justify-between">
                  <p><%= email %></p>
                  <button
                    phx-click={
                      JS.push("add_enrollments_remove_from_list",
                        value: %{email: email, status: :rejected},
                        target: "##{@target}"
                      )
                    }
                    class="torus-button error"
                  >
                    Remove
                  </button>
                </div>
              </ul>
            <% end %>
          </li>
        </div>
      </div>

      <div
        :if={@add_enrollments_grouped_by_status[:suspended] not in [[], nil]}
        id="suspended_enrollments"
      >
        <p>
          The following emails have a "suspended" enrollment. A new invitation will be sent by email so they can rejoin.
        </p>
        <div>
          <li class="list-none mt-4 max-h-80 overflow-y-scroll">
            <%= for email <- @add_enrollments_grouped_by_status[:suspended] do %>
              <ul class="odd:bg-gray-200 dark:odd:bg-neutral-600 even:bg-gray-100 dark:even:bg-neutral-500 p-2 first:rounded-t last:rounded-b">
                <div class="flex items-center justify-between">
                  <p><%= email %></p>
                  <button
                    phx-click={
                      JS.push("add_enrollments_remove_from_list",
                        value: %{email: email, status: :suspended},
                        target: "##{@target}"
                      )
                    }
                    class="torus-button error"
                  >
                    Remove
                  </button>
                </div>
              </ul>
            <% end %>
          </li>
        </div>
      </div>

      <div :if={@add_enrollments_grouped_by_status[:enrolled] not in [[], nil]} id="already_enrolled">
        <p>
          The following emails are already enrolled in the course (no email invitation will be sent)
        </p>
        <div>
          <li class="list-none mt-4 max-h-80 overflow-y-scroll">
            <%= for email <- @add_enrollments_grouped_by_status[:enrolled] do %>
              <ul class="odd:bg-gray-200 dark:odd:bg-neutral-600 even:bg-gray-100 dark:even:bg-neutral-500 p-2 first:rounded-t last:rounded-b">
                <div class="flex items-center justify-between">
                  <p><%= email %></p>
                  <button
                    phx-click={
                      JS.push("add_enrollments_remove_from_list",
                        value: %{email: email, status: :enrolled},
                        target: "##{@target}"
                      )
                    }
                    class="torus-button error"
                  >
                    Remove
                  </button>
                </div>
              </ul>
            <% end %>
          </li>
        </div>
      </div>
    </div>
    """
  end

  def add_enrollments(
        %{add_enrollments_step: :step_3, add_enrollments_effective_count: 0} = assigns
      ) do
    ~H"""
    <div class="px-4">
      <p>
        The emails you provided are already enrolled in the course. No email invitation will be sent.
      </p>
    </div>
    """
  end

  def add_enrollments(%{add_enrollments_step: :step_3} = assigns) do
    ~H"""
    <.form
      for={%{}}
      id="add_enrollments_form"
      class="hidden"
      method="POST"
      action={Routes.invite_path(OliWeb.Endpoint, :create_bulk, @section_slug)}
    >
      <input
        name="non_existing_users_emails"
        value={Jason.encode!(List.wrap(@add_enrollments_grouped_by_status[:non_existing_users]))}
        hidden
      />
      <input
        name="not_enrolled_users_emails"
        value={Jason.encode!(List.wrap(@add_enrollments_grouped_by_status[:not_enrolled_users]))}
        hidden
      />
      <input
        name="not_active_enrolled_users_emails"
        value={
          Jason.encode!(
            List.wrap(@add_enrollments_grouped_by_status[:suspended]) ++
              List.wrap(@add_enrollments_grouped_by_status[:pending_confirmation]) ++
              List.wrap(@add_enrollments_grouped_by_status[:rejected])
          )
        }
        hidden
      />
      <input name="role" value={@add_enrollments_selected_role} />
      <input name="section_slug" value={@section_slug} />
      <input name="inviter" value={@inviter} />
      <button type="submit" class="hidden" />
    </.form>
    <div class="px-4">
      <p>
        Are you sure you want to send an enrollment email invitation to <%= "#{if @add_enrollments_effective_count == 1, do: "one user", else: "#{@add_enrollments_effective_count} users"}" %>?
      </p>
      <.inviter
        current_author={@current_author}
        current_user={@current_user}
        inviter={@inviter}
        myself={@myself}
      />
    </div>
    """
  end

  attr(:current_author, :any, required: true)
  attr(:current_user, :any, required: true)
  attr(:inviter, :string, required: true)
  attr(:myself, :string, required: true)

  defp inviter(assigns) do
    ~H"""
    <div
      :if={show_senders(@current_author, @current_user)}
      class="mt-5 p-5 border-solid border-2 border-blue-400 rounded"
    >
      <p>You're signed with two accounts.</p>
      <p>Please select the one to use as an inviter:</p>
      <fieldset class="mt-2">
        <div class="ml-2">
          <input
            type="radio"
            id="author"
            name="inviter"
            phx-value-inviter="author"
            phx-click="select_inviter"
            phx-target={@myself}
            checked={@inviter == "author"}
          />
          <label for="author" class="ml-2"><%= Map.get(@current_author, :name) %></label>
        </div>
        <div class="ml-2">
          <input
            type="radio"
            id="user"
            name="inviter"
            phx-value-inviter="user"
            phx-click="select_inviter"
            phx-target={@myself}
            checked={@inviter == "user"}
          />
          <label for="user" class="ml-2"><%= Map.get(@current_user, :name) %></label>
        </div>
      </fieldset>
    </div>
    """
  end

  def handle_event("toggle_selected", %{"_target" => [id]}, socket) do
    selected_id = String.to_integer(id)
    do_update_selection(socket, selected_id)
  end

  def handle_event("apply_proficiency_filter", _params, socket) do
    %{
      selected_proficiency_ids: selected_proficiency_ids
    } = socket.assigns

    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           socket.assigns.view,
           socket.assigns.tab_name,
           update_params(socket.assigns.params, %{
             selected_proficiency_ids: Jason.encode!(selected_proficiency_ids)
           })
         )
     )}
  end

  def handle_event(
        "apply_progress_filter",
        %{
          "progress_percentage" => progress_percentage,
          "progress" => %{"option" => progress_selector}
        },
        socket
      ) do
    new_params = %{
      progress_percentage: progress_percentage,
      progress_selector: progress_selector
    }

    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           socket.assigns.view,
           socket.assigns.tab_name,
           update_params(socket.assigns.params, new_params)
         )
     )}
  end

  def handle_event("clear_all_filters", _params, socket) do
    %{section_slug: section_slug, view: view, params: params} = socket.assigns

    path =
      case view do
        :overview ->
          ~p"/sections/#{section_slug}/instructor_dashboard/overview/students"

        :insights ->
          new_params = %{
            navigation_data: params.navigation_data,
            container_id: params.container_id
          }

          ~p"/sections/#{section_slug}/instructor_dashboard/insights/content?#{new_params}"
      end

    {:noreply, push_patch(socket, to: path)}
  end

  def handle_event("select_card", %{"selected" => value}, socket) do
    value =
      if String.to_existing_atom(value) == Map.get(socket.assigns.params, :selected_card_value),
        do: nil,
        else: String.to_existing_atom(value)

    send(
      self(),
      {:selected_card_students, {value, socket.assigns.params.container_id, socket.assigns.view}}
    )

    {:noreply, socket}
  end

  def handle_event("select_inviter", %{"inviter" => inviter}, socket) do
    {:noreply, assign(socket, :inviter, inviter)}
  end

  def handle_event("add_enrollments_go_to_step_1", _, socket) do
    {:noreply, assign(socket, :add_enrollments_step, :step_1)}
  end

  def handle_event("add_enrollments_go_to_step_2", _, socket) do
    all_required_enrollments = socket.assigns.add_enrollments_emails

    # we need to distinguish all required enrollments between existing users and non existing users
    existing_users =
      Oli.Accounts.get_users_by_email(all_required_enrollments) |> Enum.map(& &1.email)

    non_existing_users = all_required_enrollments -- existing_users

    # From the existing users we need to distinguish wich have already an enrollment in the current course
    enrollments_by_emails =
      Oli.Delivery.Sections.get_enrollments_by_emails(socket.assigns.section_slug, existing_users)

    enrolled_emails = Enum.map(enrollments_by_emails, & &1.user.email)

    existing_users_with_an_enrollment =
      Enum.filter(existing_users, fn email -> email in enrolled_emails end)

    not_enrolled_users = existing_users -- existing_users_with_an_enrollment

    # we finally group all the required enrollments by status

    add_enrollments_grouped_by_status =
      enrollments_by_emails
      |> Enum.group_by(& &1.status, fn enrollment -> enrollment.user.email end)
      |> Map.merge(%{
        non_existing_users: non_existing_users,
        not_enrolled_users: not_enrolled_users
      })

    if add_enrollment_warning_step_required?(
         add_enrollments_grouped_by_status,
         all_required_enrollments
       ) do
      {:noreply,
       assign(socket, %{
         add_enrollments_step: :step_2,
         add_enrollments_grouped_by_status: add_enrollments_grouped_by_status
       })}
    else
      {:noreply,
       assign(socket, %{
         add_enrollments_step: :step_3,
         add_enrollments_grouped_by_status: add_enrollments_grouped_by_status,
         add_enrollments_effective_count:
           add_enrollments_effective_count(add_enrollments_grouped_by_status)
       })}
    end
  end

  def handle_event("add_enrollments_go_to_step_3", _, socket) do
    {:noreply,
     assign(socket, %{
       add_enrollments_step: :step_3,
       add_enrollments_effective_count:
         add_enrollments_effective_count(socket.assigns.add_enrollments_grouped_by_status)
     })}
  end

  def handle_event("add_enrollments_change_selected_role", %{"role" => role}, socket) do
    {:noreply, assign(socket, :add_enrollments_selected_role, String.to_existing_atom(role))}
  end

  def handle_event("add_enrollments_update_list", %{"value" => list}, socket)
      when is_list(list) do
    current_emails = socket.assigns.add_enrollments_emails

    maybe_updated_add_enrollments_emails = remove_duplicates(current_emails, list)

    socket = assign(socket, add_enrollments_emails: maybe_updated_add_enrollments_emails)

    {:noreply, socket}
  end

  def handle_event("add_enrollments_update_list", %{"value" => value}, socket) do
    current_emails = socket.assigns.add_enrollments_emails

    maybe_updated_add_enrollments_emails = remove_duplicates(current_emails, value)

    socket = assign(socket, add_enrollments_emails: maybe_updated_add_enrollments_emails)

    {:noreply, socket}
  end

  def handle_event(
        "add_enrollments_remove_from_list",
        %{"email" => email, "status" => status},
        socket
      ) do
    add_enrollments_emails = Enum.filter(socket.assigns.add_enrollments_emails, &(&1 != email))

    add_enrollments_grouped_by_status =
      update_enrollments_grouped_by_status(
        socket.assigns.add_enrollments_grouped_by_status,
        email,
        status
      )

    step =
      cond do
        length(add_enrollments_emails) == 0 ->
          :step_1

        socket.assigns.add_enrollments_step == :step_2 and
            !add_enrollment_warning_step_required?(
              add_enrollments_grouped_by_status,
              add_enrollments_emails
            ) ->
          :step_1

        true ->
          socket.assigns.add_enrollments_step
      end

    {:noreply,
     assign(socket, %{
       add_enrollments_emails: add_enrollments_emails,
       add_enrollments_grouped_by_status: add_enrollments_grouped_by_status,
       add_enrollments_effective_count:
         add_enrollments_effective_count(add_enrollments_grouped_by_status),
       add_enrollments_step: step
     })}
  end

  def handle_event(
        "add_enrollments_remove_from_list",
        %{"email" => email},
        socket
      ) do
    {:noreply,
     assign(socket, %{
       add_enrollments_emails: Enum.filter(socket.assigns.add_enrollments_emails, &(&1 != email))
     })}
  end

  #### End of enrollments modal related stuff ####

  def handle_event("search_student", %{"student_name" => student_name}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           socket.assigns.view,
           socket.assigns.tab_name,
           update_params(socket.assigns.params, %{text_search: student_name, offset: 0})
         )
     )}
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           socket.assigns.view,
           socket.assigns.tab_name,
           update_params(socket.assigns.params, %{limit: limit, offset: offset})
         )
     )}
  end

  def handle_event(
        "paged_table_limit_change",
        params,
        %{assigns: %{params: current_params}} = socket
      ) do
    new_limit = Params.get_int_param(params, "limit", 20)

    new_offset =
      OliWeb.Common.PagingParams.calculate_new_offset(
        current_params.offset,
        new_limit,
        socket.assigns.total_count
      )

    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           socket.assigns.view,
           socket.assigns.tab_name,
           update_params(socket.assigns.params, %{limit: new_limit, offset: new_offset})
         )
     )}
  end

  def handle_event("paged_table_sort", %{"sort_by" => sort_by} = _params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           socket.assigns.view,
           socket.assigns.tab_name,
           update_params(socket.assigns.params, %{sort_by: String.to_existing_atom(sort_by)})
         )
     )}
  end

  def handle_event("filter_by", %{"filter" => filter}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           socket.assigns.view,
           socket.assigns.tab_name,
           update_params(socket.assigns.params, %{filter_by: String.to_existing_atom(filter)})
         )
     )}
  end

  def handle_event(
        "select_option",
        %{"_target" => _, "container" => %{"option" => "by_filtered"}},
        socket
      ) do
    navigation_data = socket.assigns.navigation_data

    containers = navigation_data["containers"]
    current_container_id = navigation_data["current_container_id"]

    filtered_containers =
      Enum.filter(containers, fn container -> container["was_filtered"] end)

    exist =
      Enum.any?(filtered_containers, fn container ->
        container["id"] == current_container_id
      end)

    navigation_data =
      if exist,
        do: Map.merge(navigation_data, %{"navigation_criteria" => "by_filtered"}),
        else:
          Map.merge(navigation_data, %{
            "navigation_criteria" => "by_filtered",
            "current_container_id" => Enum.at(filtered_containers, 0)["id"]
          })

    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           socket.assigns.view,
           socket.assigns.tab_name,
           update_params(socket.assigns.params, %{navigation_data: Jason.encode!(navigation_data)})
         )
     )}
  end

  def handle_event(
        "select_option",
        %{"_target" => _, "container" => %{"option" => "by_all"}},
        socket
      ) do
    %{navigation_data: navigation_data} = socket.assigns

    navigation_data =
      Map.merge(navigation_data, %{
        "navigation_criteria" => "by_all"
      })
      |> Jason.encode!()

    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           socket.assigns.view,
           socket.assigns.tab_name,
           update_params(socket.assigns.params, %{navigation_data: navigation_data})
         )
     )}
  end

  def handle_event("change_navigation", %{"value" => value}, socket) do
    %{navigation_data: navigation_data} = socket.assigns

    navigation_data =
      Map.merge(navigation_data, %{
        "current_container_id" => String.to_integer(value)
      })
      |> Jason.encode!()

    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           socket.assigns.view,
           socket.assigns.tab_name,
           update_params(socket.assigns.params, %{navigation_data: navigation_data})
         )
     )}
  end

  def decode_params(params) do
    navigation_data =
      Params.get_param(params, "navigation_data", @default_params.navigation_data)
      |> Jason.decode!()

    container_id =
      if is_nil(navigation_data),
        do: Params.get_int_param(params, "container_id", @default_params.container_id),
        else: navigation_data["current_container_id"]

    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      container_id: container_id,
      section_slug: Params.get_int_param(params, "section_slug", @default_params.section_slug),
      page_id: Params.get_int_param(params, "page_id", @default_params.page_id),
      sort_order:
        Params.get_atom_param(params, "sort_order", [:asc, :desc], @default_params.sort_order),
      sort_by:
        Params.get_atom_param(
          params,
          "sort_by",
          [
            :name,
            :email,
            :last_interaction,
            :progress,
            :overall_proficiency,
            :engagement,
            :payment_status
          ],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search),
      filter_by:
        Params.get_atom_param(
          params,
          "filter_by",
          [
            :enrolled,
            :suspended,
            :paid,
            :not_paid,
            :grace_period,
            :non_students,
            :pending_confirmation,
            :rejected
          ],
          @default_params.filter_by
        ),
      selected_card_value:
        Params.get_atom_param(
          params,
          "selected_card_value",
          [:low_progress, :low_proficiency, :zero_interaction_in_a_week],
          @default_params.selected_card_value
        ),
      container_filter_by:
        Params.get_atom_param(
          params,
          "container_filter_by",
          [:students],
          @default_params.container_filter_by
        ),
      navigation_data: navigation_data |> Jason.encode!(),
      progress_percentage:
        Params.get_int_param(params, "progress_percentage", @default_params.progress_percentage),
      progress_selector:
        Params.get_atom_param(
          params,
          "progress_selector",
          [:is_equal_to, :is_less_than_or_equal, :is_greather_than_or_equal],
          @default_params.progress_selector
        ),
      selected_proficiency_ids:
        Params.get_param(
          params,
          "selected_proficiency_ids",
          @default_params.selected_proficiency_ids
        )
    }
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

  defp show_senders(%Author{} = _current_author, %User{} = _current_user), do: true
  defp show_senders(_current_author, _current_user), do: false

  defp remove_duplicates(current_elements, new_elements) do
    new_elements
    |> List.wrap()
    |> MapSet.new()
    |> MapSet.union(MapSet.new(current_elements))
    |> MapSet.to_list()
  end

  defp students_count(students, filter_by) do
    %{
      low_progress:
        Enum.count(students, fn student ->
          (Metrics.progress_range(student.progress) == "Low" ||
             is_nil(student.progress)) and is_learner_selected(student, filter_by)
        end),
      low_proficiency:
        Enum.count(students, fn student ->
          student.overall_proficiency == "Low" ||
            (is_nil(student.overall_proficiency) and is_learner_selected(student, filter_by))
        end),
      zero_interaction_in_a_week:
        Enum.count(students, fn student ->
          diff_days = Timex.Comparable.diff(DateTime.utc_now(), student.last_interaction, :days)

          diff_days > 7 and is_learner_selected(student, filter_by)
        end)
    }
  end

  ## Determine if a learner is selected based on the filter_by value
  defp is_learner_selected(student, filter_by) do
    student_role_id = ContextRoles.get_role(:context_learner).id

    student.enrollment_status == filter_by and
      student.user_role_id == student_role_id
  end

  defp get_navigation_ids(
         containers_list,
         current_container_id
       ) do
    current_index =
      Enum.find_index(containers_list, fn container ->
        container["id"] == current_container_id
      end)

    previous_id =
      if current_index > 0, do: Enum.at(containers_list, current_index - 1)["id"], else: nil

    next_id =
      if current_index < length(containers_list) - 1,
        do: Enum.at(containers_list, current_index + 1)["id"],
        else: nil

    {previous_id, next_id}
  end

  defp filter_containers_by_option(navigation_data) do
    containers = navigation_data["containers"]

    navigation_criteria =
      navigation_data["navigation_criteria"] |> String.to_existing_atom()

    case navigation_criteria do
      :by_filtered ->
        Enum.filter(containers, fn container -> container["was_filtered"] end)

      :by_all ->
        containers
    end
  end

  defp get_card_type(filter_criteria_card) do
    case filter_criteria_card do
      :zero_student_progress -> "(Zero Student Progress)"
      :high_progress_low_proficiency -> "(High Progress, Low Proficiency)"
      _ -> ""
    end
  end

  defp show_proficiency_selected_values(values) do
    Enum.map_join(values, ", ", fn {_id, values} -> values end)
  end

  defp update_proficiency_options(selected_proficiency_ids, proficiency_options) do
    Enum.map(proficiency_options, fn option ->
      if option.id in selected_proficiency_ids,
        do: %{option | selected: true},
        else: option
    end)
  end

  defp do_update_selection(socket, selected_id) do
    %{proficiency_options: proficiency_options} = socket.assigns

    updated_options =
      Enum.map(proficiency_options, fn option ->
        if option.id == selected_id, do: %{option | selected: !option.selected}, else: option
      end)

    {selected_proficiency_options, selected_ids} =
      Enum.reduce(updated_options, {%{}, []}, fn option, {values, acc_ids} ->
        if option.selected,
          do: {Map.put(values, option.id, option.name), [option.id | acc_ids]},
          else: {values, acc_ids}
      end)

    {:noreply,
     assign(socket,
       selected_proficiency_options: selected_proficiency_options,
       proficiency_options: updated_options,
       selected_proficiency_ids: selected_ids
     )}
  end

  _docp = """
  Checks if the step 2 of the "add enrollments" wizard is required to be shown.
  It should be shown if not existing users and/or users with any enrollment
  status ("enrolled", "pending_confirmation", "rejected" or "suspended") where required by the instructor.
  """

  defp add_enrollment_warning_step_required?(
         add_enrollments_grouped_by_status,
         all_required_enrollments
       ),
       do:
         length(add_enrollments_grouped_by_status[:not_enrolled_users] || []) !=
           length(all_required_enrollments)

  _docp = """
  Counts the amount of enrollments invitations that will be sent, not
  considering the ones that are already enrolled to the course.
  """

  defp add_enrollments_effective_count(add_enrollments_grouped_by_status) do
    add_enrollments_grouped_by_status
    |> Map.drop([:enrolled])
    |> Enum.reduce(0, fn {_, emails}, acc ->
      length(emails) + acc
    end)
  end

  defp update_enrollments_grouped_by_status(
         add_enrollments_grouped_by_status,
         email,
         status
       ) do
    Map.update(
      add_enrollments_grouped_by_status,
      String.to_existing_atom(status),
      [],
      fn emails ->
        Enum.filter(emails, fn e -> e != email end)
      end
    )
  end
end
