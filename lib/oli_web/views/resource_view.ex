defmodule OliWeb.ResourceView do
  use OliWeb, :view

  alias Oli.Authoring.Editing.ResourceContext

  def previous_url(conn, %ResourceContext{previous_page: %{"num_page_breaks" => num_page_breaks, "slug" => slug}, projectSlug: projectSlug}, action) do
    if num_page_breaks > 1 && action != :edit do
      Routes.resource_path(conn, action, projectSlug, slug, num_page_breaks)
    else
      Routes.resource_path(conn, action, projectSlug, slug)
    end
  end


  def previous_title(%ResourceContext{previous_page: %{"title" => title, "num_page_breaks" => num_page_breaks}}, action) do
    if num_page_breaks > 1 && action != :edit do
      "#{title} (#{num_page_breaks}/#{num_page_breaks})"
    else
      title
    end
  end

  def next_url(conn, %ResourceContext{next_page: %{"num_page_breaks" => num_page_breaks, "slug" => slug}, projectSlug: projectSlug}, action) do
    if num_page_breaks > 1 && action != :edit do
      Routes.resource_path(conn, action, projectSlug, slug, 1)
    else
      Routes.resource_path(conn, action, projectSlug, slug)
    end
  end


  def next_title(%ResourceContext{next_page: %{"title" => title, "num_page_breaks" => num_page_breaks}}, action) do
    if num_page_breaks > 1 && action != :edit do
      "#{title} (1/#{num_page_breaks})"
    else
      title
    end
  end

end
