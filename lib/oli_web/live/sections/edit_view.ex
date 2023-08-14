defmodule OliWeb.Sections.EditView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, :live}

  alias Oli.Branding
  alias OliWeb.Sections.StartEnd
  alias Oli.Delivery.Sections
  alias OliWeb.Common.{Breadcrumb, SessionContext, FormatDateTime, CustomLabelsForm}
  alias OliWeb.Common.Properties.{Groups, Group}
  alias OliWeb.Router.Helpers, as: Routes

  alias OliWeb.Sections.{
    LtiSettings,
    MainDetails,
    Mount,
    OpenFreeSettings,
    PaywallSettings,
    ContentSettings
  }

  alias Surface.Components.Form
  alias Oli.Branding.CustomLabels
  alias Oli.Institutions

  data(breadcrumbs, :any)
  data(title, :string, default: "Edit Section Details")
  data(section, :any, default: nil)
  data(changeset, :any)
  data(is_admin, :boolean)
  data(brands, :list)
  data(labels, :map, default: Map.from_struct(CustomLabels.default()))

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

        available_institutions =
          Institutions.list_institutions()
          |> Enum.map(fn institution -> {institution.name, institution.id} end)

        labels =
          case section.customizations do
            nil -> Map.from_struct(CustomLabels.default())
            val -> Map.from_struct(val)
          end

        {:ok,
         assign(socket,
           ctx: SessionContext.init(socket, session),
           brands: available_brands,
           institutions: available_institutions,
           changeset: Sections.change_section(section),
           is_admin: type == :admin,
           breadcrumbs: set_breadcrumbs(type, section),
           section: section,
           labels: labels
         )}
    end
  end

  def render(assigns) do
    ~F"""
    <Form as={:section} for={@changeset} change="validate" submit="save" opts={autocomplete: "off"}>
      <Groups.render>
        <Group.render label="Settings" description="Manage the course section settings">
          <MainDetails
            changeset={@changeset}
            disabled={false}
            is_admin={@is_admin}
            brands={@brands}
            institutions={@institutions}
          />
        </Group.render>
        <Group.render label="Schedule" description="Edit the start and end dates for scheduling purposes">
          <StartEnd.render
            id="start_end_editing"
            changeset={@changeset}
            disabled={false}
            is_admin={@is_admin}
            ctx={@ctx}
          />
        </Group.render>

        {#if @section.open_and_free}
          <OpenFreeSettings
            id="open_and_free_settings"
            is_admin={@is_admin}
            changeset={@changeset}
            disabled={false}
            {=@ctx}
          />
        {#else}
          <LtiSettings section={@section} />
        {/if}

        <PaywallSettings changeset={@changeset} disabled={!can_change_payment?(@section, @is_admin)} />
        <ContentSettings changeset={@changeset} />
      </Groups.render>
    </Form>
    <Groups.render>
      <Group.render label="Labels" description="Custom labels">
        <CustomLabelsForm.render labels={@labels} save="save_labels" />
      </Group.render>
    </Groups.render>
    """
  end

  def handle_event("validate", %{"section" => params}, socket) do
    params = convert_dates(params, socket.assigns.ctx)
    {:noreply, assign(socket, changeset: Sections.change_section(socket.assigns.section, params))}
  end

  def handle_event("save", %{"section" => params}, socket) do
    params = convert_dates(params, socket.assigns.ctx)

    case Sections.update_section(socket.assigns.section, params) do
      {:ok, section} ->
        socket = put_flash(socket, :info, "Section changes saved")
        {:noreply, assign(socket, section: section, changeset: Sections.change_section(section))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("save_labels", params, socket) do
    socket = clear_flash(socket)

    params =
      Map.merge(%{"unit" => "Unit", "module" => "Module", "section" => "Section"}, params, fn _k,
                                                                                              v1,
                                                                                              v2 ->
        if v2 == nil || String.length(String.trim(v2)) == 0 do
          v1
        else
          v2
        end
      end)

    case Sections.update_section(socket.assigns.section, %{customizations: params}) do
      {:ok, section} ->
        socket = put_flash(socket, :info, "Section changes saved")

        {:noreply,
         assign(socket,
           section: section,
           changeset: Sections.change_section(section),
           labels: params
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp convert_dates(params, ctx) do
    utc_start_date = FormatDateTime.datestring_to_utc_datetime(params["start_date"], ctx)
    utc_end_date = FormatDateTime.datestring_to_utc_datetime(params["end_date"], ctx)

    params
    |> Map.put("start_date", utc_start_date)
    |> Map.put("end_date", utc_end_date)
  end

  # A user can make paywall edits only if they are logged in as an admin user
  defp can_change_payment?(_section, is_admin?) do
    is_admin?
  end
end
