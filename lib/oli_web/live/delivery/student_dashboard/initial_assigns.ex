defmodule OliWeb.Delivery.StudentDashboard.InitialAssigns do
  @moduledoc """
  Ensure common assigns are applied to all StudentDashboard LiveViews attaching this hook.
  """
  use OliWeb, :verified_routes

  alias OliWeb.Sections.Mount
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Components.Delivery.Utils
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Accounts
  alias Oli.Delivery.Metrics

  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, :not_mounted_at_router, _session, socket) do
    {:cont, socket}
  end

  def on_mount(
        :default,
        %{"section_slug" => section_slug, "student_id" => student_id},
        session,
        socket
      ) do
    case Mount.for(section_slug, socket) do
      {:error, error} ->
        {:halt, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, error))}

      {_user_type, _user, section} ->
        section =
          section
          |> Oli.Repo.preload([:base_project, :root_section_resource])

        student =
          Accounts.get_user!(student_id)
          |> add_students_survey_data(section_slug)
          |> add_students_metrics(section.id)

        {:cont,
         assign(socket,
           browser_timezone: Map.get(session, "browser_timezone"),
           student: student,
           preview_mode: socket.assigns[:live_action] == :preview,
           section: section
         )
         |> Phoenix.LiveView.attach_hook(
           :maybe_set_breadcrumbs,
           :handle_params,
           &maybe_set_breadcrumbs/3
         )}
    end
  end

  def maybe_set_breadcrumbs(params, _url, socket) do
    socket =
      if !socket.assigns[:breadcrumbs] and socket.assigns[:route_name] do
        assign(socket, breadcrumbs: set_breadcrumbs(socket, params))
      else
        socket
      end

    {:cont, socket}
  end

  defp set_breadcrumbs(socket, params) do
    url_params =
      if !is_nil(params["container_id"]), do: %{container_id: params["container_id"]}, else: %{}

    case socket.assigns[:route_name] do
      :student_dashboard_preview ->
        [
          Breadcrumb.new(%{
            full_title: "Student reports",
            link:
              Routes.instructor_dashboard_path(
                socket,
                :preview,
                socket.assigns.section.slug,
                :reports,
                :students,
                url_params
              )
          }),
          Breadcrumb.new(%{
            full_title: "#{Utils.user_name(socket.assigns.student)} information"
          })
        ]

      _ ->
        [
          Breadcrumb.new(%{
            full_title: "Student reports",
            link:
              ~p"/sections/#{socket.assigns.section.slug}/instructor_dashboard/overview/students"
          }),
          Breadcrumb.new(%{
            full_title: "#{Utils.user_name(socket.assigns.student)} information"
          })
        ]
    end
  end

  defp add_students_metrics(student, section_id) do
    progress = Metrics.progress_for(section_id, student.id)

    avg_score =
      Metrics.avg_score_for(section_id, student.id)
      |> Map.get(student.id, nil)

    Map.merge(student, %{
      avg_score: avg_score,
      progress: progress
    })
  end

  defp add_students_survey_data(student, _section_slug) do
    # TODO get real data from students initial course survey (MER-1722)
    Map.merge(student, %{purpose: nil, experience: nil, pronouns: nil, mayor: nil})
  end
end
