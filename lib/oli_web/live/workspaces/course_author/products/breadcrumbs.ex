defmodule OliWeb.Workspaces.CourseAuthor.Products.Breadcrumbs do
  use OliWeb, :verified_routes

  alias OliWeb.Common.Breadcrumb

  def product_overview(project_slug, product_slug), do:
    [
      Breadcrumb.new(%{
        full_title: "Product Overview",
        link: ~p"/workspaces/course_author/#{project_slug}/products/#{product_slug}"
      })
    ]
end
