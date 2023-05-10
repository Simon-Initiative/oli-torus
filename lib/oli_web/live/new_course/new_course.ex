defmodule OliWeb.Delivery.NewCourse do
  use OliWeb, :live_view

  alias Oli.Accounts
  alias Oli.Delivery
  alias Oli.Lti.LtiParams
  alias Oli.Delivery.Sections.{Section}
  alias Oli.Delivery.Sections
  alias Oli.Repo

  alias OliWeb.Common.Stepper
  alias OliWeb.Common.Stepper.Step
  alias OliWeb.Delivery.NewCourse.{CourseDetails, NameCourse, SelectSource}

  alias Lti_1p3.Tool.ContextRoles

  alias Phoenix.LiveView.JS

  @form_id "open_and_free_form"
  def mount(_params, session, socket) do
    changeset = Sections.change_independent_learner_section(%Section{registration_open: true})

    steps = [
      %Step{
        title: "Select your base course project or course product",
        description:
          "Select a course project or product on which to base your course curriculum.",
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

    lti_params =
      case session["lti_params_id"] do
        nil ->
          nil

        lti_params_id ->
          %{params: lti_params} = LtiParams.get_lti_params(lti_params_id)
          lti_params
      end

    current_user =
      case session["current_user_id"] do
        nil -> nil
        current_user_id -> Accounts.get_user!(current_user_id, preload: [:author])
      end

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
       changeset: changeset
     )}
  end

  def render(assigns) do
    ~H"""
      <div id={@form_id} phx-hook="SubmitForm">
        <.live_component
          id="course_creation_stepper"
          module={Stepper}
          on_cancel="redirect_to_courses"
          steps={@steps || []}
          current_step={@current_step}
          data={get_step_data(assigns)} />
      </div>
    """
  end

  slot :inner_block, required: true

  defp header(assigns) do
    ~H"""
      <h5 class="px-9 py-4 border-gray-200 dark:border-gray-600 border-b text-sm font-semibold">
        New course set up
      </h5>
      <div class="overflow-y-auto scrollbar-hide relative h-full">
        <%= render_slot(@inner_block) %>
      </div>
    """
  end

  def render_step(:select_source, assigns) do
    ~H"""
      <.header>
        <div class="flex flex-col items-center gap-3 pl-9 pr-16 py-4">
          <h2>Course details</h2>
          <p>We pulled the information we can from your LMS, but feel free to adjust it</p>
          <.live_component
            id="select_source_step"
            module={SelectSource}
            session={@session}
            on_select={@on_select}
            on_select_target={@on_select_target}
            source={@source}
            current_user={@current_user}
            lti_params={@lti_params}
          />
        </div>
      </.header>
    """
  end

  def render_step(:name_course, assigns) do
    ~H"""
      <.header>
        <div class="flex flex-col items-center gap-3 pl-9 pr-16 py-4">
          <img src="/images/icons/course-creation-wizard-step-1.svg" />
          <h2>Name your course</h2>
          <p class="mb-0">We pulled the information we can from your LMS, but feel free to adjust it</p>
          <NameCourse.render changeset={@changeset} />
        </div>
      </.header>
    """
  end

  def render_step(:course_details, assigns) do
    ~H"""
    <.header>
      <div class="flex flex-col items-center gap-3 pl-9 pr-16 py-4">
        <img src="/images/icons/course-creation-wizard-step-2.svg" />
        <h2>Course details</h2>
        <p>We pulled the information we can from your LMS, but feel free to adjust it</p>
        <CourseDetails.render on_select={@on_select} changeset={@changeset} />
      </div>
    </.header>
    """
  end

  defp get_step_data(assigns) do
    case assigns.current_step do
      0 ->
        %{
          session: assigns.session,
          source: assigns[:source],
          on_select: "source_selection",
          on_select_target: "##{@form_id}",
          current_user: assigns.current_user,
          lti_params: assigns.lti_params
        }

      1 ->
        %{changeset: assigns.changeset}

      _ ->
        %{changeset: assigns.changeset, on_select: "day_selection"}
    end
  end

  def create_section(:lms_instructor, socket) do
    section_params =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes()
      |> Map.from_struct()

    case Delivery.create_section(
           socket.assigns.source,
           socket.assigns.current_user,
           socket.assigns.lti_params,
           %{
             class_modality: section_params.class_modality,
             class_days: section_params.class_days,
             course_section_number: section_params.course_section_number,
             start_date: section_params.start_date,
             end_date: section_params.end_date
           }
         ) do
      {:ok, _section} ->
        {:noreply,
         socket
         |> put_flash(:info, "Section successfully created.")
         |> push_redirect(to: Routes.delivery_path(OliWeb.Endpoint, :index))}

      {:error, error} ->
        {_error_id, error_msg} = log_error("Failed to create new section", error)
        # {:noreply, put_flash(socket, :error, error_msg)}
        {:noreply, socket}
    end
  end

  def create_section(_, socket) do
    %{source: source, changeset: changeset} = socket.assigns

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
            has_experiments: has_experiments
          })

        case create_from_publication(socket, publication, section_params) do
          {:ok, section} ->
            socket = put_flash(socket, :info, "Section created successfully.")

            {:noreply,
             redirect(socket,
               to: Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section.slug)
             )}

          {:error, _} ->
            {:noreply, socket}
        end

      {blueprint, _, :product_slug} ->
        project = Oli.Repo.get(Oli.Authoring.Course.Project, blueprint.base_project_id)

        section_params =
          changeset
          |> Ecto.Changeset.apply_changes()
          |> Map.from_struct()
          |> Map.merge(%{
            blueprint_id: blueprint.id,
            type: :enrollable,
            open_and_free: true,
            has_experiments: project.has_experiments,
            base_project_id: blueprint.base_project_id,
            context_id: UUID.uuid4()
          })

        case create_from_product(socket, blueprint, section_params) do
          {:ok, section} ->
            socket = put_flash(socket, :info, "Section created successfully.")

            {:noreply,
             redirect(socket,
               to: Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section.slug)
             )}

          _ ->
            {:noreply, socket}
        end
    end
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
           {:ok, _enrollment} <- enroll(socket, section),
           {:ok, updated_section} <-
             Oli.Delivery.maybe_update_section_contains_explorations(section) do
        updated_section
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
           {:ok, _maybe_enrollment} <- enroll(socket, section) do
        section
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

  def handle_event("redirect_to_courses", _, socket) do
    {:noreply,
     redirect(socket,
       to: Routes.delivery_path(socket, :open_and_free_index)
     )}
  end

  def handle_event("source_selection", %{"id" => source}, socket) do
    {:noreply, assign(socket, source: source)}
  end

  def handle_event("day_selection", %{"class_days" => class_days}, socket) do
    class_days =
      Enum.reduce(class_days, [], fn {day, checked}, days ->
        if String.to_atom(checked) do
          [day | days]
        else
          days
        end
      end)

    changeset = Ecto.Changeset.change(socket.assigns.changeset, %{class_days: class_days})

    {:noreply, assign(socket, changeset: changeset)}
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
    changeset =
      socket.assigns.changeset
      |> Section.changeset(section)

    socket = assign(socket, changeset: changeset, current_step: current_step)

    if current_step > 2 do
      create_section(socket.assigns.live_action, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_event(
        "js_form_data_response",
        %{"current_step" => current_step},
        socket
      ) do
    {:noreply, assign(socket, current_step: current_step)}
  end
end
