defmodule OliWeb.ProjectController do
  use OliWeb, :controller

  def overview(conn, %{"project" => project_id}) do
    render conn, "overview.html", title: "Overview", project: project_id, active: :overview
  end

  def objectives(conn, %{"project" => project_id}) do
    render conn, "objectives.html", title: "Objectives", project: project_id, active: :objectives
  end

  def curriculum(conn, %{"project" => project_id}) do
    render conn, "curriculum.html", title: "Curriculum", project: project_id, active: :curriculum
  end

  def page(conn, %{"project" => project_id}) do
    render conn, "page.html", title: "Page", project: project_id, active: :page
  end

  def resource_editor(conn, %{"project" => project_id}) do
    render conn, "resource_editor.html", title: "Resource Editor", project: project_id, active: :resource_editor
  end

  def publish(conn, %{"project" => project_id}) do
    render conn, "publish.html", title: "Publish", project: project_id, active: :publish
  end

  def insights(conn, %{"project" => project_id}) do
    render conn, "insights.html", title: "Insights", project: project_id, active: :insights
  end
end
