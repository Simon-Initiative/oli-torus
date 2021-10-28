defmodule OliWeb.Sections.EditView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  alias OliWeb.Common.{Breadcrumb}
  alias OliWeb.Common.Properties.{Groups, Group}
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Sections
  alias OliWeb.Sections.{MainDetails, OpenFreeSettings, LtiSettings, PaywallSettings}
  alias Surface.Components.{Form}
  alias Oli.Branding
  alias OliWeb.Sections.Mount

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
          <OpenFreeSettings is_admin={@is_admin} changeset={@changeset} disabled={false}/>
        {#else}
          <LtiSettings section={@section}/>
        {/if}
        <PaywallSettings is_admin={@is_admin} changeset={@changeset} disabled={!can_change_payment?(@section)}/>
      </Groups>
    </Form>
    """
  end

  def handle_event("validate", %{"section" => params}, socket) do
    params = convert_dates(params)

    changeset =
      socket.assigns.section
      |> Sections.change_section(params)

    {:noreply, assign(socket, changeset: changeset)}
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

  def parse_and_convert_start_end_dates_to_utc(start_date, end_date, from_timezone) do
    section_timezone = Timex.Timezone.get(from_timezone)
    utc_timezone = Timex.Timezone.get(:utc, Timex.now())

    utc_start_date =
      case start_date do
        start_date when start_date == nil or start_date == "" or not is_binary(start_date) ->
          start_date

        start_date ->
          start_date
          |> Timex.parse!("%Y-%m-%d", :strftime)
          |> Timex.to_datetime(section_timezone)
          |> Timex.Timezone.convert(utc_timezone)
      end

    utc_end_date =
      case end_date do
        end_date when end_date == nil or end_date == "" or not is_binary(end_date) ->
          end_date

        end_date ->
          end_date
          |> Timex.parse!("%Y-%m-%d", :strftime)
          |> Timex.to_datetime(section_timezone)
          |> Timex.Timezone.convert(utc_timezone)
      end

    {utc_start_date, utc_end_date}
  end

  defp convert_dates(params) do
    {utc_start_date, utc_end_date} =
      parse_and_convert_start_end_dates_to_utc(
        params["start_date"],
        params["end_date"],
        params["timezone"]
      )

    params
    |> Map.put("start_date", utc_start_date)
    |> Map.put("end_date", utc_end_date)
  end

  defp can_change_payment?(section) do
    is_nil(section.blueprint_id)
  end
end
