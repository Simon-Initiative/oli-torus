defmodule OliWeb.Workspaces.CourseAuthor.Certificates.CertificateSettingsLive do
  use OliWeb, :live_view

  alias OliWeb.Sections.Mount
  alias OliWeb.Common.Breadcrumb

  @title "Manage Certificate Settings"

  def mount(%{"project_id" => project_slug, "product_id" => product_slug}, session, socket) do
    case Mount.for(product_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {_, _, product} ->
        {:ok,
         assign(socket,
           title: @title,
           header_title: @title,
           product: product,
           breadcrumbs: breadcrumbs(project_slug, product_slug)
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="px-[30px] py-[50px]">
      <.live_component
        module={OliWeb.Certificates.CertificateSettingsComponent}
        id="certificate_settings_component"
        product={@product}
      />
    </div>
    """
  end

  defp breadcrumbs(project_slug, product_slug) do
    [
      Breadcrumb.new(%{
        full_title: "Product Overview",
        link: ~p"/workspaces/course_author/#{project_slug}/products/#{product_slug}"
      }),
      Breadcrumb.new(%{full_title: @title})
    ]
  end
end
