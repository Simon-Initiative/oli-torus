defmodule OliWeb.Delivery.NewCourse do
  use OliWeb, :live_view

  alias Oli.Accounts
  alias Oli.Delivery
  alias Oli.Lti.LtiParams
  alias Oli.Delivery.Sections.{Section}
  alias Oli.Delivery.Sections
  alias Oli.Repo

  alias OliWeb.Common.{Breadcrumb, Stepper}
  alias OliWeb.Common.Stepper.Step
  alias OliWeb.Delivery.NewCourse.{CourseDetails, NameCourse, SelectSource}

  alias Lti_1p3.Tool.ContextRoles

  alias Phoenix.LiveView.JS

  @form_id "open_and_free_form"
  def mount(_params, session, socket) do
    changeset = Sections.change_independent_learner_section(%Section{registration_open: true})

    steps = [
      %Step{
        title: "Select your source materials",
        description:
          "Select the source of materials to base your course curriculum on.",
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
       changeset: changeset,
       breadcrumbs: breadcrumbs(socket.assigns.live_action)
     )}
  end

  attr :breadcrumbs, :any, default: [Breadcrumb.new(%{full_title: "Course Creation"})]

  def render(assigns) do
    ~H"""
      <div id={@form_id} phx-hook="SubmitForm">
        <.live_component
          id="course_creation_stepper"
          module={Stepper}
          on_cancel="redirect_to_courses"
          steps={@steps || []}
          current_step={@current_step}
          next_step_disabled={next_step_disabled?(assigns)}
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

  attr :flash, :any, default: %{}

  defp render_flash(assigns) do
    ~H"""
      <%= if live_flash(@flash, :form_error) do %>
        <div class="alert alert-danger m-0 flex flex-row justify-between w-full" role="alert">

          <%= live_flash(@flash, :form_error) %>

          <button type="button" class="close" data-bs-dismiss="alert" aria-label="Close" phx-click="lv:clear-flash" phx-value-key="error">
            <i class="fa-solid fa-xmark fa-lg"></i>
          </button>

        </div>
      <% end %>
    """
  end

  def render_step(:select_source, assigns) do
    ~H"""
      <.header>
        <div class="flex flex-col items-center gap-3 pl-9 pr-16 py-4">
          <h2>Select source</h2>
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
          <.render_flash flash={@flash} />
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
        <.render_flash flash={@flash} />
        <CourseDetails.render on_select={@on_select} changeset={@changeset} />
      </div>
    </.header>
    """
  end

  def breadcrumbs(:admin) do
    OliWeb.OpenAndFreeController.set_breadcrumbs() ++
      [
        Breadcrumb.new(%{
          full_title: "Course Creation",
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
          on_select: "source_selection",
          on_select_target: "##{@form_id}",
          current_user: assigns.current_user,
          lti_params: assigns.lti_params
        }

      1 ->
        %{changeset: assigns.changeset, flash: assigns.flash}

      _ ->
        %{changeset: assigns.changeset, on_select: "day_selection", flash: assigns.flash}
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
        socket = put_flash(socket, :form_error, error_msg)
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
            socket = put_flash(socket, :info, "Section successfully created.")

            {:noreply,
             redirect(socket,
               to: Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section.slug)
             )}

          {:error, error} ->
            {_error_id, error_msg} = log_error("Failed to create new section", error)
            socket = put_flash(socket, :form_error, error_msg)
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
            socket = put_flash(socket, :info, "Section successfully created.")

            {:noreply,
             redirect(socket,
               to: Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section.slug)
             )}

          {:error, error} ->
            {_error_id, error_msg} = log_error("Failed to create new section", error)
            socket = put_flash(socket, :form_error, error_msg)
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
       to:
         if(socket.assigns.lti_params,
           do: Routes.delivery_path(socket, :index),
           else: Routes.delivery_path(socket, :open_and_free_index)
         )
     )}
  end

  def handle_event("source_selection", %{"id" => source}, socket) do
    {:noreply, assign(socket, source: source, current_step: 1)}
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
    section =
      case Map.get(section, "class_days") do
        class_days when not (is_nil(class_days) or is_list(class_days)) ->
          Map.put(section, "class_days", [class_days])

        _ ->
          section
      end

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
            [:class_days, :start_date, :end_date]
          else
            [:start_date, :end_date]
          end

        if validate_fields(changeset, fields_to_validate) do
          if validate_course_dates(changeset) do
            create_section(socket.assigns.live_action, assign(socket, changeset: changeset))
          else
            {:noreply,
             assign(socket, changeset: changeset)
             |> put_flash(
               :form_error,
               "The course's start date must be earlier than its end date"
             )}
          end
        else
          {:noreply,
           assign(socket, changeset: changeset)
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

  defp validate_course_dates(changeset) do
    {_, start_date} = Ecto.Changeset.fetch_field(changeset, :start_date)
    {_, end_date} = Ecto.Changeset.fetch_field(changeset, :end_date)
    Date.diff(start_date, end_date) < 0
  end
end
