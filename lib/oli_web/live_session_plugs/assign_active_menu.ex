defmodule OliWeb.LiveSessionPlugs.AssignActiveMenu do
  import Phoenix.Component, only: [assign: 2]

  @moduledoc """
  Adds the active workspace and active view to the socket assigns based on the invoked module.

  This is used to determine which menu item should be active in the UI.

  This Plug handles the following cases:

  - Modules ending with 'Live,' such as 'OliWeb.Workspaces.CourseAuthor.OverviewLive,'
  where the active_workspace will be :course_author and the active_view will be :overview.

  - Modules containing the sub-workspace (AKA the active view), such as 'OliWeb.Workspaces.CourseAuthor.Activities.ActivityReviewLive',
  where the active_workspace will be :course_author and the active_view will be :activities."
  """

  @valid_views_for_instructor [
    "course_content",
    "students",
    "quiz_scores",
    "recommended_actions",
    "content",
    "learning_objectives",
    "scored_activities",
    "practice_activities",
    "surveys",
    "manage",
    "activity"
  ]

  def on_mount(:default, params, _session, socket) do
    socket =
      case Module.split(socket.view) do
        ["OliWeb", "Workspaces", "CourseAuthor", view | _rest] ->
          active_view =
            view
            |> String.split(~r/(?=[A-Z])/, trim: true)
            |> Enum.reject(&(&1 == "Live"))
            |> Enum.map(&String.downcase/1)
            |> Enum.join("_")
            |> String.to_existing_atom()

          assign(socket, active_workspace: :course_author, active_view: active_view)

        ["OliWeb", "Workspaces", "Instructor" | _rest] ->
          case params["active_tab"] || params["view"] do
            active_view_string when active_view_string in @valid_views_for_instructor ->
              active_view = String.to_atom(active_view_string)
              assign(socket, active_workspace: :instructor, active_view: active_view)

            _ ->
              socket
          end

        _ ->
          socket
      end

    {:cont, socket}
  end
end
