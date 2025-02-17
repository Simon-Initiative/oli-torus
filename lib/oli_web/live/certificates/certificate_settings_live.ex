defmodule OliWeb.Certificates.CertificatesSettingsLive do
  use OliWeb, :live_view

  alias Oli.Delivery.Certificates
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Repo.Paging
  alias Oli.Repo.Sorting
  alias Oli.Publishing.DeliveryResolver
  alias OliWeb.Certificates.CertificatesIssuedTableModel
  alias OliWeb.Certificates.Components.CertificatesIssuedTab
  alias OliWeb.Certificates.Components.DesignTab
  alias OliWeb.Certificates.Components.ThresholdsTab
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Common.Params
  alias OliWeb.Sections.Mount

  on_mount OliWeb.LiveSessionPlugs.SetCtx
  on_mount OliWeb.LiveSessionPlugs.SetRouteName
  on_mount OliWeb.LiveSessionPlugs.SetUri

  def mount(params, session, socket) do
    slug = params["product_id"] || params["section_slug"]
    socket = assigns_for(socket, :page)

    case Mount.for(slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {_, _, section} ->
        certificate = Certificates.get_certificate_by(%{section_id: section.id})

        socket
        |> assign(section: section)
        |> assign(section_changeset: Section.changeset(section))
        |> assign(certificate: certificate)
    end
    |> ok_wrapper()
  end

  def handle_params(params, url, socket) do
    %{host: host, path: path} = URI.parse(url)

    route_info = Phoenix.Router.route_info(OliWeb.Router, "GET", path, host)

    %{section: section, ctx: ctx} = socket.assigns
    params = decode_params(params)

    socket =
      socket
      |> assign(params: params)
      |> assign(active_tab: params["active_tab"])
      |> assign(read_only: route_info[:access] == :read_only)
      |> assign(graded_pages: [])
      |> assign(table_model: CertificatesIssuedTableModel.new(ctx, [], section.slug))
      |> assigns_for(:breadcrumbs)

    case connected?(socket) do
      true -> assigns_for(socket, :tabs)
      false -> socket
    end
    |> noreply_wrapper()
  end

  defp assigns_for(socket, :breadcrumbs) do
    %{assigns: %{route_name: route_name, section: section}} = socket

    case route_name do
      :workspaces ->
        project = socket.assigns.project
        socket |> assign(breadcrumbs: breadcrumbs(:workspaces, project.slug, section.slug))

      route_name when route_name in [:authoring, :delivery] ->
        socket |> assign(breadcrumbs: breadcrumbs(:authoring, nil, section.slug))
    end
  end

  defp assigns_for(socket, :page) do
    case socket.assigns[:project] do
      # authoring
      nil ->
        socket

      # workspaces - assigns needed to display the left-bottom side menu
      project ->
        socket
        |> assign(resource_slug: project.slug)
        |> assign(resource_title: project.title)
        |> assign(active_workspace: :course_author)
        |> assign(active_view: :products)
    end
    |> assign(title: "Manage Certificate Settings")
    |> assign(current_path: "/")
  end

  defp assigns_for(socket, :thresholds) do
    section_slug = socket.assigns.section.slug

    socket
    |> assign(graded_pages: section_graded_pages(section_slug))
  end

  defp assigns_for(socket, :credentials_issued) do
    params = socket.assigns.params
    params = CertificatesIssuedTab.decode_params(params)

    paging = %Paging{limit: params["limit"], offset: params["offset"]}
    sorting = %Sorting{direction: params["direction"], field: params["sort_by"]}
    text_search = params["text_search"]

    section_id = socket.assigns.section.id

    granted_certificates =
      Certificates.browse_granted_certificates(paging, sorting, text_search, section_id)

    table_model = socket.assigns[:table_model]
    table_model = %{table_model | rows: granted_certificates, sort_order: params["direction"]}

    socket
    |> assign(table_model: table_model)
    |> assign(params: params)
  end

  defp assigns_for(socket, :tabs) do
    uri = socket.assigns[:uri]
    socket = assign(socket, current_path: extract_path(uri))

    active_tab = socket.assigns.params["active_tab"]

    case active_tab do
      :thresholds -> assigns_for(socket, :thresholds)
      :design -> socket
      :credentials_issued -> assigns_for(socket, :credentials_issued)
    end
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto mt-10 mb-20">
      <div class="w-full flex-col justify-start items-start gap-[30px] inline-flex mb-5">
        <div role="title" class="self-stretch text-2xl font-normal">
          Certificate Settings
        </div>
        <.form
          :if={!@read_only}
          for={@section_changeset}
          phx-change="toggle_certificate"
          class="self-stretch justify-start items-center gap-3 inline-flex"
        >
          <input
            type="checkbox"
            class="form-check-input w-5 h-5 p-0.5"
            id="enable_certificates_checkbox"
            name="certificate_enabled"
            checked={Ecto.Changeset.get_field(@section_changeset, :certificate_enabled)}
          />
          <div class="grow shrink basis-0 text-base font-medium">
            Enable certificate capabilities for this product
          </div>
        </.form>
        <.tabs
          active_tab={@active_tab}
          current_path={@current_path}
          certificate_enabled={@section.certificate_enabled}
        />
      </div>

      <div :if={@section.certificate_enabled}>
        <%= render_tab(assigns) %>
      </div>
    </div>
    """
  end

  defp render_tab(%{params: %{"active_tab" => :credentials_issued}} = assigns) do
    ~H"""
    <.live_component
      module={CertificatesIssuedTab}
      id="certificates_issued_component"
      params={@params}
      section_slug={@section.slug}
      table_model={@table_model}
      ctx={@ctx}
      route_name={@route_name}
      project={if @route_name == :workspaces, do: @project, else: nil}
    />
    """
  end

  defp render_tab(%{params: %{"active_tab" => :design}} = assigns) do
    ~H"""
    <.live_component
      module={DesignTab}
      id="design_component"
      section={@section}
      certificate={@certificate}
      active_tab={@active_tab}
    />
    """
  end

  defp render_tab(assigns) do
    ~H"""
    <.live_component
      module={ThresholdsTab}
      id="thresholds_component"
      section={@section}
      certificate={@certificate}
      active_tab={@active_tab}
      graded_pages={@graded_pages}
      read_only={@read_only}
    />
    """
  end

  defp tabs(assigns) do
    ~H"""
    <div :if={@certificate_enabled} id="certificate_settings_tabs" class="flex mt-7 mb-3 gap-20">
      <div class="justify-start">
        <.tab_link
          is_tab_active={@active_tab == :thresholds}
          current_path={@current_path}
          active_tab={:thresholds}
        >
          Thresholds
        </.tab_link>
      </div>
      <div class="justify-center items-center inline-flex">
        <.tab_link
          is_tab_active={@active_tab == :design}
          current_path={@current_path}
          active_tab={:design}
        >
          Design
        </.tab_link>
      </div>
      <div class="justify-end items-center inline-flex">
        <.tab_link
          is_tab_active={@active_tab == :credentials_issued}
          current_path={@current_path}
          active_tab={:credentials_issued}
        >
          Credentials Issued
        </.tab_link>
      </div>
    </div>
    """
  end

  slot :inner_block, required: true
  attr :current_path, :string
  attr :is_tab_active, :boolean
  attr :active_tab, :atom

  defp tab_link(assigns) do
    ~H"""
    <.link
      class={[
        "text-base font-bold hover:text-[#0165da] dark:hover:text-[#0165da]",
        if(@is_tab_active,
          do: "underline text-[#0165da]",
          else: "text-black dark:text-white no-underline hover:no-underline"
        )
      ]}
      patch={@current_path <> "?active_tab=#{@active_tab}"}
    >
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  def handle_event("toggle_certificate", params, socket) do
    certificate_enabled = params["certificate_enabled"] == "on"

    case Sections.update_section(socket.assigns.section, %{
           certificate_enabled: certificate_enabled
         }) do
      {:ok, section} ->
        {:noreply,
         assign(socket, section: section, section_changeset: Section.changeset(section))}

      {:error, changeset} ->
        {:noreply, assign(socket, section_changeset: changeset)}
    end
  end

  def handle_info({:put_flash, [type, message]}, socket) do
    {:noreply,
     socket
     |> clear_flash()
     |> put_flash(type, message)}
  end

  defp breadcrumbs(:authoring, _project_slug, section_slug) do
    [
      Breadcrumb.new(%{
        full_title: "Manage Section",
        link: ~p"/authoring/products/#{section_slug}"
      }),
      Breadcrumb.new(%{full_title: "Manage Certificate Settings"})
    ]
  end

  defp breadcrumbs(:workspaces, project_slug, section_slug) do
    [
      Breadcrumb.new(%{
        full_title: "Product Overview",
        link: ~p"/workspaces/course_author/#{project_slug}/products/#{section_slug}"
      }),
      Breadcrumb.new(%{full_title: "Manage Certificate Settings"})
    ]
  end

  defp decode_params(params) do
    active_tabs = [:thresholds, :design, :credentials_issued]
    active_tab = Params.get_atom_param(params, "active_tab", active_tabs, :thresholds)

    Map.put(params, "active_tab", active_tab)
  end

  defp section_graded_pages(section_slug) do
    section_slug
    |> DeliveryResolver.graded_pages_revisions_and_section_resources()
    |> Enum.map(&(&1 |> elem(0) |> Map.take([:resource_id, :title])))
  end

  defp extract_path(uri) do
    uri
    |> URI.parse()
    |> Map.get(:path)
  end
end
