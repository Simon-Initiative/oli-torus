defmodule OliWeb.Sections.EditView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Branding
  alias Oli.Delivery.Sections
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Common.Properties.{Groups, Group}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.{LtiSettings, MainDetails, Mount, OpenFreeSettings, PaywallSettings}
  alias Surface.Components.Form

  data breadcrumbs, :any
  data title, :string, default: "Edit Section Details"
  data section, :any, default: nil
  data changeset, :any
  data is_admin, :boolean
  data brands, :list

  defp set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Edit Section",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, session, socket) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _, section} ->
        available_brands =
          Branding.list_brands()
          |> Enum.map(fn brand -> {brand.name, brand.id} end)

        {:ok,
         assign(socket,
           delivery_breadcrumb: true,
           brands: available_brands,
           changeset: Sections.change_section(section),
           is_admin: type == :admin,
           breadcrumbs: set_breadcrumbs(type, section),
           section: section
         )}
    end
  end

  def render(assigns) do
    ~F"""
    <Form as={:section} for={@changeset} change="validate" submit="save" opts={autocomplete: "off"}>
      <Groups>
        <Group label="Settings" description="Manage the course section settings">
          <MainDetails changeset={@changeset} disabled={false}  is_admin={@is_admin} brands={@brands} />
        </Group>
        {#if @section.open_and_free}
          <OpenFreeSettings id="open_and_free_settings" is_admin={@is_admin} changeset={@changeset} disabled={false}/>
        {#else}
          <LtiSettings section={@section}/>
        {/if}
        <PaywallSettings changeset={@changeset} disabled={!can_change_payment?(@section, @is_admin)}/>
      </Groups>
    </Form>
    """
  end

  def handle_event("validate", %{"section" => params}, socket) do
    params = convert_dates(params)

    {:noreply, assign(socket, changeset: Sections.change_section(socket.assigns.section, params))}
  end

  def handle_event("save", %{"section" => params}, socket) do
    params = convert_dates(params)

    case Sections.update_section(socket.assigns.section, params) do
      {:ok, section} ->
        socket = put_flash(socket, :info, "Section changes saved")
        {:noreply, assign(socket, section: section, changeset: Sections.change_section(section))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp convert_dates(params) do
    {utc_start_date, utc_end_date} =
      Sections.parse_and_convert_start_end_dates_to_utc(
        params["start_date"],
        params["end_date"],
        params["timezone"]
      )

    params
    |> Map.put("start_date", utc_start_date)
    |> Map.put("end_date", utc_end_date)
  end

  # A user can make paywall edits only if they are logged in as an admin user
  defp can_change_payment?(_section, is_admin?) do
    is_admin?
  end
end
