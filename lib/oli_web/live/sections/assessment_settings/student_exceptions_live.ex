defmodule OliWeb.Sections.AssessmentSettings.StudentExceptionsLive do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Settings.AssessmentSettings
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount

  @impl true
  def mount(%{"section_slug" => section_slug} = _params, _session, socket) do
    case Mount.for(section_slug, socket) do
      {:error, error} ->
        {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, error))}

      {user_type, user, section} ->
        section =
          section
          |> Oli.Repo.preload([:base_project, :root_section_resource])

        student_exceptions = AssessmentSettings.get_student_exceptions(section.id)

        {:ok,
         assign(socket,
           preview_mode: socket.assigns[:live_action] == :preview,
           title: "Student Exceptions",
           section: section,
           user: user,
           student_exceptions: student_exceptions,
           assessments: AssessmentSettings.get_assessments(section.slug, student_exceptions),
           students:
             Sections.enrolled_students(section.slug)
             |> Enum.reject(fn s -> s.user_role_id != 4 end)
             |> Enum.sort(),
           breadcrumbs: set_breadcrumbs(user_type, section)
         )}
    end
  end

  defp set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Student Exceptions",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  @impl true
  def handle_params(params, _, socket) do
    {:noreply, assign(socket, params: params, update_sort_order: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto">
      <.live_component
        id="student_exeptions_table"
        module={OliWeb.Sections.AssessmentSettings.StudentExceptionsTable}
        student_exceptions={@student_exceptions}
        students={@students}
        assessments={@assessments}
        params={@params}
        section={@section}
        ctx={@ctx}
      />
    </div>
    """
  end

  @impl true
  def handle_info({:flash_message, type, message}, socket) do
    {:noreply, socket |> clear_flash |> put_flash(type, message)}
  end

  @impl true
  def handle_info({:student_exception, action, student_exceptions, update_sort_order}, socket)
      when is_list(student_exceptions) do
    updated_student_exceptions =
      case action do
        :updated ->
          socket.assigns.student_exceptions
          |> Enum.into([], fn se ->
            Enum.find(student_exceptions, se, fn s_ex -> s_ex.id == se.id end)
          end)

        :added ->
          student_exceptions ++ socket.assigns.student_exceptions

        :deleted ->
          ids = Enum.map(student_exceptions, fn se -> se.id end)

          Enum.reject(socket.assigns.student_exceptions, fn se ->
            se.id in ids
          end)
      end

    updated_assessments =
      socket.assigns.assessments
      |> update_assessments_students_exception_count(updated_student_exceptions)

    {:noreply,
     socket
     |> assign(
       student_exceptions: updated_student_exceptions,
       assessments: updated_assessments,
       update_sort_order: update_sort_order
     )}
  end

  defp update_assessments_students_exception_count(assessments, student_exceptions) do
    exceptions_resource_id = Enum.group_by(student_exceptions, fn se -> se.resource_id end)

    assessments
    |> Enum.map(fn a ->
      exceptions_count = Map.get(exceptions_resource_id, a.resource_id, []) |> length()
      Map.merge(a, %{exceptions_count: exceptions_count})
    end)
  end
end
