defmodule OliWeb.Delivery.StudentDashboard.InitialAssigns do
  @moduledoc """
  Ensure common assigns are applied to all StudentDashboard LiveViews attaching this hook.
  """
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.SessionContext
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
    case Mount.for(section_slug, session) do
      {:error, error} ->
        {:halt, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, error))}

      {_user_type, current_user, section} ->
        section =
          section
          |> Oli.Repo.preload([:base_project, :root_section_resource])

        {:cont,
         assign(socket,
           ctx: SessionContext.init(socket, session, user: current_user),
           browser_timezone: Map.get(session, "browser_timezone"),
           current_user: current_user,
           student:
             Accounts.get_user!(student_id)
             |> add_students_survey_data(section_slug)
             |> add_students_metrics(section.id),
           preview_mode: socket.assigns[:live_action] == :preview,
           section: section
         )}
    end
  end

  defp add_students_metrics(student, section_id) do
    progress = Metrics.progress_for(section_id, student.id) |> Map.get(student.id, 0.0)

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
