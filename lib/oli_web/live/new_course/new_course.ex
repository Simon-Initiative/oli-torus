defmodule OliWeb.Delivery.NewCourse do
  alias Oli.Lti.LtiParams
  use OliWeb, :live_view

  on_mount {OliWeb.UserAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx
  on_mount OliWeb.LiveSessionPlugs.SetSection
  on_mount OliWeb.LiveSessionPlugs.SetBrand
  on_mount OliWeb.LiveSessionPlugs.SetPreviewMode

  alias Oli.Accounts
  alias Oli.Delivery
  alias Oli.Delivery.DistributedDepotCoordinator
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.PostProcessing
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Repo
  alias OliWeb.Common.{Breadcrumb, Stepper, FormatDateTime}
  alias OliWeb.Common.Stepper.Step
  alias OliWeb.Components.Common
  alias OliWeb.Delivery.NewCourse.{CourseDetails, NameCourse, SelectSource}
  alias Lti_1p3.Tool.ContextRoles

  alias Phoenix.LiveView.JS

  import OliWeb.Components.Delivery.Layouts

  on_mount {OliWeb.UserAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  @form_id "open_and_free_form"
  def mount(_params, session, socket) do
    changeset = Sections.change_independent_learner_section(%Section{registration_open: true})

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

    current_user = Accounts.preload_author(socket.assigns.current_user)
    lti_params = LtiParams.get_latest_lti_params_for_user(current_user.id)

    changeset =
      case lti_params["https://purl.imsglobal.org/spec/lti/claim/resource_link"] do
        nil -> changeset
        params -> Section.changeset(changeset, %{title: params["title"]})
      end

    {:ok,
     assign(socket,
       form_id: @form_id,
       steps: steps,
       current_step: 0,
       session: Map.put(session, "live_action", socket.assigns.live_action),
       current_user: current_user,
       lti_params: lti_params,
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
        <.header ctx={@ctx} section={@section} preview_mode={@preview_mode} is_admin={@is_admin} />
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
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr(:flash, :any, default: %{})

  defp render_flash(assigns) do
    ~H"""
    <%= if Phoenix.Flash.get(@flash, :form_error) do %>
      <div class="alert alert-danger m-0 flex flex-row justify-between w-full" role="alert">
        <%= Phoenix.Flash.get(@flash, :form_error) %>

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
          session={@session}
          on_select={@on_select}
          source={@source}
          current_user={@current_user}
          lti_params={@lti_params}
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
          session: assigns.session,
          source: assigns[:source],
          on_select: JS.push("source_selection", target: "##{@form_id}"),
          current_user: assigns.current_user,
          lti_params: assigns.lti_params
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

  def create_section(:lms_instructor, socket) do
    section_params =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes()
      |> Map.from_struct()

    liveview_pid = self()

    Task.Supervisor.start_child(Oli.TaskSupervisor, fn ->
      case Delivery.create_section(
             socket.assigns.source,
             socket.assigns.current_user,
             socket.assigns.lti_params,
             %{
               class_modality: section_params.class_modality,
               class_days: section_params.class_days,
               course_section_number: section_params.course_section_number,
               start_date: section_params.start_date,
               end_date: section_params.end_date,
               preferred_scheduling_time: section_params.preferred_scheduling_time,
               analytics_version: :v2
             }
           ) do
        {:ok, section} ->
          send(liveview_pid, {:section_created, section.id, section.slug})

        {:error, error} ->
          {_error_id, error_msg} = log_error("Failed to create new section", error)

          send(liveview_pid, {:section_created_error, error_msg})
      end
    end)

    {:noreply, assign(socket, loading: true)}
  end

  def create_section(_, socket) do
    %{source: source, changeset: changeset} = socket.assigns

    liveview_pid = self()

    Task.Supervisor.start_child(Oli.TaskSupervisor, fn ->
      case source_info(source) do
        {project, _, :project_slug} ->
          %{id: project_id, has_experiments: has_experiments} =
            Oli.Authoring.Course.get_project_by_slug(project.slug)

          publication =
            Oli.Publishing.get_latest_published_publication_by_slug(project.slug)
            |> Repo.preload(:project)

          customizations =
            case publication.project.customizations do
              nil -> nil
              labels -> Map.from_struct(labels)
            end

          section_params =
            changeset
            |> Ecto.Changeset.apply_changes()
            |> Map.from_struct()
            |> Map.merge(%{
              type: :enrollable,
              base_project_id: project_id,
              open_and_free: true,
              context_id: UUID.uuid4(),
              customizations: customizations,
              has_experiments: has_experiments,
              analytics_version: :v2,
              welcome_title: project.welcome_title,
              encouraging_subtitle: project.encouraging_subtitle,
              certificate: nil
            })

          case create_from_publication(socket, publication, section_params) do
            {:ok, section} ->
              send(liveview_pid, {:section_created, section.id, section.slug})

            {:error, error} ->
              {_error_id, error_msg} = log_error("Failed to create new section", error)
              send(liveview_pid, {:section_created_error, error_msg})
          end

        {blueprint, _, :product_slug} ->
          project = Oli.Repo.get(Oli.Authoring.Course.Project, blueprint.base_project_id)

          section_params =
            changeset
            |> Ecto.Changeset.apply_changes()
            |> Map.from_struct()
            |> Map.take([
              :title,
              :course_section_number,
              :class_modality,
              :class_days,
              :start_date,
              :end_date,
              :preferred_scheduling_time
            ])
            |> Map.merge(%{
              blueprint_id: blueprint.id,
              required_survey_resource_id: project.required_survey_resource_id,
              type: :enrollable,
              open_and_free: true,
              has_experiments: project.has_experiments,
              context_id: UUID.uuid4(),
              analytics_version: :v2,
              welcome_title: blueprint.welcome_title,
              encouraging_subtitle: blueprint.encouraging_subtitle
            })

          case create_from_product(socket, blueprint, section_params) do
            {:ok, section} ->
              send(liveview_pid, {:section_created, section.id, section.slug})

            {:error, error} ->
              {_error_id, error_msg} = log_error("Failed to create new section", error)

              send(liveview_pid, {:section_created_error, error_msg})
          end
      end
    end)

    {:noreply, assign(socket, loading: true)}
  end

  defp source_info(source_id) do
    case source_id do
      "product:" <> id ->
        {Sections.get_section!(String.to_integer(id)), "Source Product", :product_slug}

      "publication:" <> id ->
        publication =
          Oli.Publishing.get_publication!(String.to_integer(id)) |> Repo.preload(:project)

        {publication.project, "Source Project", :project_slug}

      "project:" <> id ->
        project = Oli.Authoring.Course.get_project!(id)

        {project, "Source Project", :project_slug}
    end
  end

  defp create_from_publication(socket, publication, section_params) do
    Repo.transaction(fn ->
      with {:ok, section} <- Sections.create_section(section_params),
           {:ok, section} <- Sections.create_section_resources(section, publication),
           {:ok, _} <- Sections.rebuild_contained_pages(section),
           {:ok, _} <- Sections.rebuild_contained_objectives(section),
           {:ok, _enrollment} <- enroll(socket, section) do
        PostProcessing.apply(section, :all)
      else
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp create_from_product(socket, blueprint, section_params) do
    Repo.transaction(fn ->
      with {:ok, section} <- Oli.Delivery.Sections.Blueprint.duplicate(blueprint, section_params),
           {:ok, _} <- Sections.rebuild_contained_pages(section),
           {:ok, _} <- Sections.rebuild_contained_objectives(section),
           {:ok, _maybe_enrollment} <- enroll(socket, section) do
        PostProcessing.apply(section, :discussions)
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp enroll(socket, section) do
    if is_nil(socket.assigns.current_user) do
      {:ok, nil}
    else
      Sections.enroll(socket.assigns.current_user.id, section.id, [
        ContextRoles.get_role(:context_instructor)
      ])
    end
  end

  def handle_info({:section_created, section_id, section_slug}, socket) do
    Task.Supervisor.start_child(Oli.TaskSupervisor, fn ->
      depot_desc = SectionResourceDepot.depot_desc()
      DistributedDepotCoordinator.init_if_necessary(depot_desc, section_id, SectionResourceDepot)
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
     redirect(socket,
       to:
         if(socket.assigns.lti_params,
           do: Routes.delivery_path(socket, :index),
           else: Routes.live_path(socket, OliWeb.Workspaces.Instructor)
         )
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
            create_section(socket.assigns.live_action, assign(socket, changeset: changeset))
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
