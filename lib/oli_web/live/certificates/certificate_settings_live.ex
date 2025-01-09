defmodule OliWeb.Certificates.CertificateSettingsLive do
  use OliWeb, :live_view

  alias OliWeb.Sections.Mount
  alias OliWeb.Common.Breadcrumb

  def mount(%{"product_id" => product_slug}, session, socket) do
    case Mount.for(product_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {_, _, product} ->
        {:ok,
         assign(socket,
           title: "Manage Certificate Settings",
           product: product,
           breadcrumbs: [Breadcrumb.new(%{full_title: "Manage Certificate Settings"})]
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
end
