defmodule OliWeb.Delivery.Student.CertificateLive do
  use OliWeb, :live_view

  alias Oli.Delivery.GrantedCertificates
  alias OliWeb.Icons

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    granted_certificate =
      GrantedCertificates.get_granted_certificate_by_guid(params["certificate_guid"]) || %{}

    {:ok,
     socket
     |> assign(:granted_certificate, granted_certificate)
     |> assign(
       :show_certificate?,
       Map.get(granted_certificate, :user_id) == socket.assigns.current_user.id
     )
     |> assign(active_tab: :index)}
  end

  @impl Phoenix.LiveView
  def render(%{show_certificate?: false} = assigns) do
    ~H"""
    <div class="p-10">
      <.back_button section_slug={@section.slug} />
    </div>
    <div class="flex flex-col justify-center items-center p-10">
      <h3>The requested certificate does not exist or belongs to another student</h3>
    </div>
    """
  end

  def render(%{show_certificate?: true, granted_certificate: %{url: nil}} = assigns) do
    ~H"""
    <div class="p-10">
      <.back_button section_slug={@section.slug} />
    </div>
    <div class="flex flex-col justify-center items-center p-10">
      <h3>The requested certificate is being created. Please revisit the page in some minutes</h3>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="p-10">
      <.back_button section_slug={@section.slug} />
    </div>
    <div class="flex flex-col justify-center items-center p-10">
      <embed src={@granted_certificate.url} type="application/pdf" style="width: 66vw; height: 66vh;">
      </embed>
      <p class="text-blue-400 mt-4">
        Certificate ID: <span class="font-semibold">{@granted_certificate.guid}</span>
      </p>
    </div>
    """
  end

  attr :section_slug, :string, required: true

  def back_button(assigns) do
    ~H"""
    <.link navigate={~p"/sections/#{@section_slug}"}>
      <Icons.left_arrow class="hover:opacity-100 hover:scale-105 fill-[#9D9D9D]" />
    </.link>
    """
  end
end
