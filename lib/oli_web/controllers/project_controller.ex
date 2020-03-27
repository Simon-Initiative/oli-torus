defmodule OliWeb.ProjectController do
  use OliWeb, :controller

  def overview(conn, %{"project" => project_id, }) do
    params = %{title: "Overview", project: project_id, active: :overview}
    render %{conn | assigns: Map.merge(conn.assigns, params)}, "overview.html"
  end

  def objectives(conn, %{"project" => project_id}) do
    render conn, "objectives.html", title: "Objectives", project: project_id, active: :objectives
  end

  def curriculum(conn, %{"project" => project_id}) do
    render conn, "curriculum.html", title: "Curriculum", project: project_id, active: :curriculum
  end


  def publish(conn, %{"project" => project_id}) do
    render conn, "publish.html", title: "Publish", project: project_id, active: :publish
  end

  def insights(conn, %{"project" => project_id}) do
    render conn, "insights.html", title: "Insights", project: project_id, active: :insights
  end
end
