defmodule OliWeb.Sections.EditView do
  use OliWeb, :live_view

  alias Oli.Branding
  alias OliWeb.Sections.StartEnd
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionCache
  alias OliWeb.Common.{Breadcrumb, FormatDateTime, CustomLabelsForm}
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

  alias Oli.Branding.CustomLabels
  alias Oli.Institutions

  defp set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Edit Section Details",
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
            nil -> CustomLabels.default_map()
            val -> Map.from_struct(val)
          end

        base_project = Oli.Authoring.Course.get_project!(section.base_project_id)

        {:ok,
         assign(socket,
           brands: available_brands,
           institutions: available_institutions,
           changeset: Sections.change_section(section),
           is_admin: type == :admin,
           breadcrumbs: set_breadcrumbs(type, section),
           section: section,
           labels: labels,
           base_project: base_project
         )}
    end
  end

  attr(:breadcrumbs, :any)
  attr(:title, :string, default: "Edit Section Details")
  attr(:section, :any, default: nil)
  attr(:changeset, :any)
  attr(:is_admin, :boolean)
  attr(:brands, :list)
  attr(:labels, :map, default: CustomLabels.default_map())
  attr(:base_project, :any)

  def render(assigns) do
    assigns = assign(assigns, form: to_form(assigns.changeset))

    ~H"""
    <title><%= @title %></title>
    <.form as={:section} for={@form} phx-change="validate" phx-submit="save" autocomplete="off">
      <Groups.render>
        <Group.render label="Settings" description="Manage the course section settings">
          <MainDetails.render
            form={@form}
            disabled={false}
            is_admin={@is_admin}
            brands={@brands}
            institutions={@institutions}
            project_slug={@base_project.slug}
            ctx={@ctx}
          />
        </Group.render>
        <Group.render
          label="Schedule"
          description="Edit the start and end dates for scheduling purposes"
        >
          <StartEnd.render form={@form} disabled={false} is_admin={@is_admin} ctx={@ctx} />
        </Group.render>
        <%= if @section.open_and_free do %>
          <OpenFreeSettings.render is_admin={@is_admin} form={@form} disabled={false} ctx={@ctx} />
        <% else %>
          <LtiSettings.render section={@section} />
        <% end %>
        <PaywallSettings.render form={@form} disabled={!@is_admin} />
        <ContentSettings.render form={@form} />
      </Groups.render>
    </.form>
    <Groups.render>
      <Group.render label="Labels" description="Custom labels">
        <CustomLabelsForm.render labels={@labels} save="save_labels" />
      </Group.render>
    </Groups.render>
    """
  end

  def handle_event("validate", %{"section" => params}, socket) do
    params =
      params
      |> can_change_payment?(socket.assigns.is_admin)
      |> convert_dates(socket.assigns.ctx)

    {:noreply, assign(socket, changeset: Sections.change_section(socket.assigns.section, params))}
  end

  def handle_event("save", %{"section" => params}, socket) do
    params =
      params
      |> can_change_payment?(socket.assigns.is_admin)
      |> convert_dates(socket.assigns.ctx)
      |> decode_welcome_title()

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
        # we need to update the order container labels on the cache
        SectionCache.clear(section.slug, [:ordered_container_labels])

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

  def handle_event("welcome_title_change", %{"values" => welcome_title}, socket) do
    changeset =
      Ecto.Changeset.put_change(socket.assigns.changeset, :welcome_title, %{
        "type" => "p",
        "children" => welcome_title
      })

    {:noreply, assign(socket, changeset: changeset)}
  end

  defp convert_dates(params, ctx) do
    utc_start_date = FormatDateTime.datestring_to_utc_datetime(params["start_date"], ctx)
    utc_end_date = FormatDateTime.datestring_to_utc_datetime(params["end_date"], ctx)

    params
    |> Map.put("start_date", utc_start_date)
    |> Map.put("end_date", utc_end_date)
  end

  # A user can make paywall edits only if they are logged in as an admin user
  defp can_change_payment?(params, is_admin?) do
    case is_admin? do
      true -> params
      false -> Map.delete(params, "requires_payment")
    end
  end

  defp decode_welcome_title(%{"welcome_title" => nil} = project_params), do: project_params

  defp decode_welcome_title(%{"welcome_title" => ""} = project_params),
    do: %{project_params | "welcome_title" => nil}

  defp decode_welcome_title(project_params),
    do: Map.update(project_params, "welcome_title", nil, &Poison.decode!(&1))
end
