defmodule OliWeb.Delivery.StudentDashboard.Components.QuizzScoresTab do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
      <div>
        <.live_component
          id="quiz_scores_table"
          module={OliWeb.Components.Delivery.QuizScores}
          params={@params}
          section={@section}
          patch_url_type={:quiz_scores_student}
          student_id={@student_id}
          scores={@scores}
        />
      </div>
    """
  end
end
