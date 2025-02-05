defmodule OliWeb.Workspaces.CourseAuthor.Certificates.CertificateSettingsLive do
  use OliWeb, :live_view

  alias OliWeb.Sections.Mount
  alias OliWeb.Common.Breadcrumb
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Certificates

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
           product: Oli.Repo.preload(product, :certificate),
           certificate: Certificates.get_certificate_by(%{section_id: product.id}),
           project_slug: project_slug,
           breadcrumbs: breadcrumbs(project_slug, product_slug),
           graded_pages: product_graded_pages(product_slug)
         )}
    end
  end

  def handle_params(params, _uri, socket) do
    socket =
      case params["active_tab"] do
        active_tab when active_tab in ~w(thresholds design credentials_issued) ->
          assign(socket, active_tab: String.to_existing_atom(active_tab))

        _ ->
          assign(socket, active_tab: :thresholds)
      end

    {:noreply, socket}
  end

  def handle_info({:put_flash, [type, message]}, socket) do
    {:noreply,
     socket
     |> clear_flash()
     |> put_flash(type, message)}
  end

  def render(assigns) do
    ~H"""
    <div class="px-[30px] py-[50px]">
      <.live_component
        module={OliWeb.Certificates.CertificateSettingsComponent}
        id="certificate_settings_component"
        product={@product}
        certificate={@certificate}
        current_path={
          ~p"/workspaces/course_author/#{@project_slug}/products/#{@product.slug}/certificate_settings"
        }
        active_tab={@active_tab}
        graded_pages={@graded_pages}
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

  defp product_graded_pages(product_slug) do
    product_slug
    |> DeliveryResolver.graded_pages_revisions_and_section_resources()
    |> Enum.map(&(&1 |> elem(0) |> Map.take([:resource_id, :title])))
  end
end
