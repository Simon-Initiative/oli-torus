defmodule OliWeb.Delivery.NewCourse do
  use OliWeb, :live_view

  on_mount {OliWeb.UserAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx
  on_mount OliWeb.LiveSessionPlugs.SetSection
  on_mount OliWeb.LiveSessionPlugs.SetBrand
  on_mount OliWeb.LiveSessionPlugs.SetPreviewMode

  alias Oli.Delivery
  alias Oli.Delivery.DepotCoordinator
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Section, SectionResourceDepot, SectionSpecification}
  alias OliWeb.Common.{Breadcrumb, Stepper, FormatDateTime}
  alias OliWeb.Common.Stepper.Step
  alias OliWeb.Components.Common
  alias OliWeb.Delivery.NewCourse.{CourseDetails, NameCourse, SelectSource}

  alias Phoenix.LiveView.JS

  import OliWeb.Components.Delivery.Layouts

  on_mount {OliWeb.UserAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  @context_claims "https://purl.imsglobal.org/spec/lti/claim/context"
  @resource_link_claims "https://purl.imsglobal.org/spec/lti/claim/resource_link"

  @form_id "open_and_free_form"
  def mount(params, _session, socket) do
    current_user = socket.assigns.current_user

    steps = [
      %Step{
        title: "Select your source materials",
        description: "Select the source of materials to base your course curriculum on.",
        render_fn: fn assigns -> render_step(:select_source, assigns) end,
        on_next_step: JS.push("change_step", value: %{current_step: 1})
      },
      %Step{
        title: "Name your course",
        description: "Give your course section a name, a number, and tell us how you meet.",
        render_fn: fn assigns -> render_step(:name_course, assigns) end,
        on_previous_step:
          JS.push("change_step", value: %{form_id: "name-course-form", current_step: 0}),
        on_next_step:
          JS.push("change_step", value: %{form_id: "name-course-form", current_step: 2})
      },
      %Step{
        title: "Course details",
        description:
          "If you meet as a group, let us know what days of the week your class meets. Everyone needs to tell us your course’s start and end dates.",
        render_fn: fn assigns -> render_step(:course_details, assigns) end,
        on_previous_step:
          JS.push("change_step", value: %{form_id: "course-details-form", current_step: 1}),
        on_next_step:
          JS.push("change_step", value: %{form_id: "course-details-form", current_step: 3}),
        next_button_label: "Create section"
      }
    ]

    # Build section specification. If a context id is provided as a param, then we are creating
    # an LTI section. Otherwise, we are creating a direct delivery section.
    section_spec =
      case params do
        %{"context_id" => context_id} ->
          SectionSpecification.lti(current_user, context_id)

        _ ->
          SectionSpecification.direct()
      end

    # Create a changeset for the section that will be used by the form.
    # Suggest a title for the course based on the LTI resource link or context title and provide
    # any reasonable default values for the course section.
    suggested_title = suggest_title(section_spec)
    changeset = Sections.change_section(%Section{title: suggested_title, registration_open: true})

    {:ok,
     assign(socket,
       form_id: @form_id,
       context_id: params["context_id"],
       steps: steps,
       current_step: 0,
       current_user: current_user,
       section_spec: section_spec,
       changeset: changeset,
       breadcrumbs: breadcrumbs(socket.assigns.live_action),
       loading: false
     )}
  end

  attr(:breadcrumbs, :any, default: [Breadcrumb.new(%{full_title: "Course Creation"})])
  attr(:is_admin, :boolean, required: true)

  def render(assigns) do
    ~H"""
    <%= case @live_action do %>
      <% :admin -> %>
      <% _ -> %>
        <.header
          ctx={@ctx}
          section={@section}
          preview_mode={@preview_mode}
          is_admin={@is_admin}
          include_logo
        />
    <% end %>
    <div id={@form_id} phx-hook="SubmitForm" class="mt-14 h-[calc(100vh-56px)]">
      <.live_component
        id="course_creation_stepper"
        module={Stepper}
        on_cancel={JS.push("redirect_to_courses")}
        steps={@steps || []}
        current_step={@current_step}
        next_step_disabled={next_step_disabled?(assigns) || @loading}
        show_spinner={@loading}
        data={get_step_data(assigns)}
      />
    </div>
    """
  end

  slot(:inner_block, required: true)

  defp new_course_header(assigns) do
    ~H"""
    <h5 class="px-9 py-4 border-gray-200 dark:border-gray-600 border-b text-sm font-semibold">
      New course set up
    </h5>
    <div class="overflow-y-auto scrollbar-hide relative h-full">
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:flash, :any, default: %{})

  defp render_flash(assigns) do
    ~H"""
    <%= if Phoenix.Flash.get(@flash, :form_error) do %>
      <div class="alert alert-danger m-0 flex flex-row justify-between w-full" role="alert">
        {Phoenix.Flash.get(@flash, :form_error)}

        <button
          type="button"
          class="close"
          data-bs-dismiss="alert"
          aria-label="Close"
          phx-click="lv:clear-flash"
          phx-value-key="error"
        >
          <i class="fa-solid fa-xmark fa-lg"></i>
        </button>
      </div>
    <% end %>
    """
  end

  def render_step(:select_source, assigns) do
    ~H"""
    <.new_course_header>
      <div class="flex flex-col items-center gap-3 pr-9 pl-16 py-6">
        <h2>Select source</h2>
        <.live_component
          id="select_source_step"
          module={SelectSource}
          ctx={@ctx}
          on_select={@on_select}
          source={@source}
          current_user={@current_user}
          is_admin={@is_admin}
          section_spec={@section_spec}
        />
      </div>
    </.new_course_header>
    """
  end

  def render_step(:name_course, assigns) do
    ~H"""
    <.new_course_header>
      <div class="flex flex-col items-center gap-3 pr-9 pl-16 py-6">
        <img src="/images/icons/course-creation-wizard-step-1.svg" style="height: 170px;" />
        <h2>Name your course</h2>
        <.render_flash flash={@flash} />
        <NameCourse.render changeset={to_form(@changeset)} />
      </div>
    </.new_course_header>
    """
  end

  def render_step(:course_details, assigns) do
    ~H"""
    <.new_course_header>
      <div class="flex flex-col items-center gap-3 pr-9 pl-16 py-6">
        <img src="/images/icons/course-creation-wizard-step-2.svg" style="height: 170px;" />
        <h2>Course details</h2>
        <.render_flash flash={@flash} />
        <CourseDetails.render changeset={to_form(@changeset)} />
      </div>
    </.new_course_header>
    """
  end

  def breadcrumbs(:admin) do
    OliWeb.Sections.SectionsView.set_breadcrumbs() ++
      [
        Breadcrumb.new(%{
          full_title: "Create Section",
          link: Routes.select_source_path(OliWeb.Endpoint, :admin)
        })
      ]
  end

  def breadcrumbs(_), do: []

  defp get_step_data(assigns) do
    case assigns.current_step do
      0 ->
        %{
          ctx: assigns.ctx,
          source: assigns[:source],
          on_select: JS.push("source_selection", target: "##{@form_id}"),
          current_user: assigns.current_user,
          section_spec: assigns.section_spec,
          is_admin: assigns.is_admin
        }

      1 ->
        %{changeset: assigns.changeset, flash: assigns.flash}

      _ ->
        %{
          changeset: assigns.changeset,
          flash: assigns.flash
        }
    end
  end

  defp next_step_disabled?(assigns) do
    case assigns.current_step do
      0 ->
        true

      _ ->
        false
    end
  end

  # Suggests a title for the section based on the LTI params. The title is suggested based on the
  # following order of precedence:
  #   1. The title from the resource link claims
  #   2. The title from the context claims
  defp suggest_title(%SectionSpecification.Lti{lti_params: lti_params}) do
    get_in(lti_params, [@resource_link_claims, "title"]) ||
      get_in(lti_params, [@context_claims, "title"])
  end

  defp suggest_title(_), do: nil

  def create_section(socket) do
    %{
      current_user: current_user,
      source: source,
      changeset: changeset,
      section_spec: section_spec
    } = socket.assigns

    liveview_pid = self()

    # start an async task to create the section and send the result back to the liveview
    Task.Supervisor.start_child(Oli.TaskSupervisor, fn ->
      case Delivery.create_section(
             changeset,
             source,
             current_user,
             section_spec
           ) do
        {:ok, section_id, section_slug} ->
          send(liveview_pid, {:section_created, section_id, section_slug})

        {:error, error} ->
          send(liveview_pid, {:section_created_error, error})
      end
    end)

    {:noreply, assign(socket, loading: true)}
  end

  def handle_info({:section_created, section_id, section_slug}, socket) do
    Task.Supervisor.start_child(Oli.TaskSupervisor, fn ->
      depot_desc = SectionResourceDepot.depot_desc()
      DepotCoordinator.init_if_necessary(depot_desc, section_id, SectionResourceDepot)
    end)

    socket
    |> put_flash(:info, "Section successfully created.")
    |> redirect(to: ~p"/sections/#{section_slug}/manage")
    |> noreply_wrapper()
  end

  def handle_info({:section_created_error, error_msg}, socket) do
    socket = put_flash(socket, :form_error, error_msg)
    {:noreply, socket}
  end

  def handle_event("redirect_to_courses", _, socket) do
    {:noreply,
     push_navigate(socket,
       to:
         case socket.assigns.context_id do
           nil ->
             if Oli.Accounts.is_admin?(socket.assigns.current_author) do
               ~p"/admin/sections"
             else
               # If the user is not an author, redirect to the instructor workspace
               ~p"/workspaces/instructor"
             end

           context_id ->
             ~p"/sections/new/#{context_id}"
         end
     )}
  end

  def handle_event("source_selection", %{"id" => source}, socket) do
    {:noreply, assign(socket, source: source, current_step: 1)}
  end

  def handle_event(
        "change_step",
        %{"form_id" => _form_id, "current_step" => _current_step} = params,
        socket
      ) do
    {:noreply, push_event(socket, "js_form_data_request", Map.put(params, :target_id, @form_id))}
  end

  def handle_event(
        "change_step",
        %{"current_step" => current_step},
        socket
      ) do
    {:noreply, assign(socket, current_step: current_step)}
  end

  # This is the response returned from the SubmitForm hook
  def handle_event(
        "js_form_data_response",
        %{"section" => section, "current_step" => current_step},
        socket
      ) do
    section =
      case Map.get(section, "class_days") do
        class_days when not (is_nil(class_days) or is_list(class_days)) ->
          Map.put(section, "class_days", [class_days])

        _ ->
          section
      end
      |> convert_dates(socket.assigns.ctx)

    changeset =
      socket.assigns.changeset
      |> Section.changeset(section)

    case current_step do
      step when step == 0 or step == 1 ->
        {:noreply, assign(socket, changeset: changeset, current_step: current_step)}

      2 ->
        if validate_fields(changeset, [:title, :course_section_number, :class_modality]) do
          {:noreply, assign(socket, changeset: changeset, current_step: current_step)}
        else
          {:noreply,
           assign(socket, changeset: changeset)
           |> put_flash(:form_error, "Some fields require your attention")}
        end

      3 ->
        class_modality =
          Ecto.Changeset.fetch_field(changeset, :class_modality)
          |> elem(1)

        fields_to_validate =
          if class_modality != :never do
            [:class_days, :start_date, :end_date, :preferred_scheduling_time]
          else
            [:start_date, :end_date, :preferred_scheduling_time]
          end

        if validate_fields(changeset, fields_to_validate) do
          if validate_course_dates(changeset) do
            create_section(assign(socket, changeset: changeset))
          else
            {:noreply,
             assign(socket, changeset: localize_dates(changeset, socket.assigns.ctx))
             |> put_flash(
               :form_error,
               "The course's start date must be earlier than its end date"
             )}
          end
        else
          {:noreply,
           assign(socket, changeset: localize_dates(changeset, socket.assigns.ctx))
           |> put_flash(:form_error, "Some fields require your attention")}
        end
    end
  end

  def handle_event(
        "js_form_data_response",
        %{"current_step" => current_step},
        socket
      ) do
    {:noreply, assign(socket, current_step: current_step)}
  end

  defp validate_fields(changeset, fields) do
    fields
    |> Enum.map(&Ecto.Changeset.fetch_field(changeset, &1))
    |> Enum.all?(fn field ->
      case field do
        {_, nil} -> false
        {_, []} -> false
        :error -> false
        _ -> true
      end
    end)
  end

  defp convert_dates(%{"start_date" => start_date, "end_date" => end_date} = params, ctx) do
    utc_start_date = FormatDateTime.datestring_to_utc_datetime(start_date, ctx)
    utc_end_date = FormatDateTime.datestring_to_utc_datetime(end_date, ctx)

    params
    |> Map.put("start_date", utc_start_date)
    |> Map.put("end_date", utc_end_date)
  end

  defp convert_dates(params, _ctx), do: params

  defp localize_dates(changeset, ctx) do
    utc_start_date = Common.fetch_field(changeset, :start_date)
    utc_end_date = Common.fetch_field(changeset, :end_date)

    local_start_date = FormatDateTime.convert_datetime(utc_start_date, ctx)
    local_end_date = FormatDateTime.convert_datetime(utc_end_date, ctx)

    changeset
    |> Ecto.Changeset.put_change(:start_date, local_start_date)
    |> Ecto.Changeset.put_change(:end_date, local_end_date)
  end

  defp validate_course_dates(changeset) do
    {_, start_date} = Ecto.Changeset.fetch_field(changeset, :start_date)
    {_, end_date} = Ecto.Changeset.fetch_field(changeset, :end_date)
    DateTime.compare(start_date, end_date) == :lt
  end
end
