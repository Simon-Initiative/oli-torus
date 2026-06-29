defmodule OliWeb.ResourceView do
  use OliWeb, :view

  alias Oli.Authoring.Editing.ResourceContext

  def previous_url(
        conn,
        %ResourceContext{previous_page: %{"slug" => slug}, projectSlug: projectSlug},
        action
      ) do
    Routes.resource_path(conn, action, projectSlug, slug)
  end

  def previous_title(%ResourceContext{previous_page: %{"title" => title}}) do
    title
  end

  def next_url(
        conn,
        %ResourceContext{next_page: %{"slug" => slug}, projectSlug: projectSlug},
        action
      ) do
    Routes.resource_path(conn, action, projectSlug, slug)
  end

  def next_title(%ResourceContext{next_page: %{"title" => title}}) do
    title
  end
end
