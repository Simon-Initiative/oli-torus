defmodule OliWeb.Sections.EditView do
  use OliWeb, :live_view

  alias Oli.Auditing.Context
  alias Oli.Branding
  alias Oli.Authoring.Course.Project
  alias OliWeb.Sections.StartEnd
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Audited, as: SectionsAudited
  alias Oli.Delivery.Sections.Section
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

  on_mount OliWeb.LiveSessionPlugs.SetRouteName

  defp set_breadcrumbs(_type, %{type: :blueprint} = section, socket) do
    route_name = socket.assigns[:route_name]
    project = socket.assigns[:project]

    overview_link = Breadcrumb.product_overview_link(section, route_name, project)

    page_link =
      case {route_name, project} do
        {:workspaces, %Project{slug: project_slug}} ->
          ~p"/workspaces/course_author/#{project_slug}/products/#{section.slug}/edit"

        _ ->
          ~p"/authoring/products/#{section.slug}/edit"
      end

    [
      Breadcrumb.new(%{full_title: "Template Overview", link: overview_link}),
      Breadcrumb.new(%{full_title: "Edit Template Details", link: page_link})
    ]
  end

  defp set_breadcrumbs(type, section, _socket) do
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

  def mount(%{"section_slug" => section_slug}, _session, socket) do
    case Mount.for(section_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {user_type, actor, section} ->
        available_brands =
          Branding.list_brands()
          |> Enum.sort_by(& &1.name)
          |> Enum.map(fn brand -> {brand.name, brand.id} end)

        available_institutions =
          Institutions.list_institutions()
          |> Enum.sort_by(& &1.name)
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
           is_admin: user_type == :admin,
           actor: actor,
           is_blueprint: section.type == :blueprint,
           user_type: user_type,
           section: section,
           labels: labels,
           base_project: base_project
         )}
    end
  end

  def handle_params(_params, _url, socket) do
    section = socket.assigns.section
    type = socket.assigns.user_type

    {:noreply, assign(socket, breadcrumbs: set_breadcrumbs(type, section, socket))}
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
    <title>{@title}</title>
    <.form
      id="section-edit-form"
      as={:section}
      for={@form}
      phx-change="validate"
      phx-submit="save"
      autocomplete="off"
    >
      <Groups.render>
        <Group.render
          label="Settings"
          description={
            if @is_blueprint,
              do: "Manage the template settings",
              else: "Manage the course section settings"
          }
        >
          <MainDetails.render
            form={@form}
            description={@section.description}
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
        <%= if !@is_blueprint do %>
          <%= if @section.open_and_free do %>
            <OpenFreeSettings.render is_admin={@is_admin} form={@form} disabled={false} ctx={@ctx} />
          <% else %>
            <LtiSettings.render section={@section} />
          <% end %>
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
      |> decode_welcome_title()

    {:noreply, assign(socket, changeset: Sections.change_section(socket.assigns.section, params))}
  end

  def handle_event("save", %{"section" => params}, socket) do
    params =
      params
      |> can_change_payment?(socket.assigns.is_admin)
      |> convert_dates(socket.assigns.ctx)
      |> decode_welcome_title()

    save_message =
      if socket.assigns.is_blueprint, do: "Template changes saved", else: "Section changes saved"

    case SectionsAudited.update_section_settings(
           audit_context(socket),
           socket.assigns.section,
           params,
           form_fields(socket.assigns.section, socket.assigns.is_admin)
         ) do
      {:ok, section} ->
        socket = put_flash(socket, :info, save_message)

        {:noreply, assign(socket, section: section, changeset: Sections.change_section(section))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Changes could not be saved")}
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

    save_message =
      if socket.assigns.is_blueprint, do: "Template changes saved", else: "Section changes saved"

    case SectionsAudited.update_section_settings(
           audit_context(socket),
           socket.assigns.section,
           %{customizations: params},
           [:customizations]
         ) do
      {:ok, section} ->
        socket = put_flash(socket, :info, save_message)

        {:noreply,
         assign(socket,
           section: section,
           changeset: Sections.change_section(section),
           labels: params
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Labels could not be saved")}
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

  # The account `Mount` authorized for this section.
  defp audit_context(socket), do: Context.for_actor(socket.assigns.actor, source: :ui)

  # The fields the settings form renders for this section and user: payment settings only for
  # admins, open-and-free access only for open-and-free sections, and the institution only
  # when no LTI deployment sets it.
  defp form_fields(%Section{} = section, is_admin) do
    [
      :title,
      :description,
      :welcome_title,
      :encouraging_subtitle,
      :brand_id,
      :start_date,
      :end_date,
      :preferred_scheduling_time,
      :timezone,
      :display_curriculum_item_numbering
    ] ++
      institution_fields(section) ++ open_and_free_fields(section) ++ payment_fields(is_admin)
  end

  defp institution_fields(%Section{lti_1p3_deployment_id: nil}), do: [:institution_id]
  defp institution_fields(_section), do: []

  defp open_and_free_fields(%Section{type: :enrollable, open_and_free: true}),
    do: [:registration_open, :requires_enrollment, :skip_email_verification]

  defp open_and_free_fields(_section), do: []

  defp payment_fields(true), do: OliWeb.Sections.PaywallSettings.fields()
  defp payment_fields(false), do: []

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

  # A form without the welcome title (such as the content options) leaves it unchanged.
  defp decode_welcome_title(%{"welcome_title" => welcome_title} = project_params)
       when is_binary(welcome_title),
       do: %{project_params | "welcome_title" => Poison.decode!(welcome_title)}

  defp decode_welcome_title(project_params), do: project_params
end
