defmodule OliWeb.Admin.Institutions.InstitutionsTableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}
  alias OliWeb.Common.FormatDateTime
  alias OliWeb.Router.Helpers, as: Routes

  def new(institutions, ctx) do
    default_td_class = "!border-r border-Table-table-border"
    default_th_class = "!border-r border-Table-table-border"

    column_specs = [
      %ColumnSpec{
        name: :name,
        label: "Name",
        render_fn: &__MODULE__.render_name_column/3,
        th_class: default_th_class,
        td_class: default_td_class
      },
      %ColumnSpec{
        name: :country_code,
        label: "Country Code",
        th_class: default_th_class,
        td_class: default_td_class
      },
      %ColumnSpec{
        name: :institution_email,
        label: "Email",
        th_class: default_th_class,
        td_class: default_td_class
      },
      %ColumnSpec{
        name: :type,
        label: "Type",
        render_fn: &__MODULE__.render_type_column/3,
        sort_fn: &__MODULE__.sort_type_column/2,
        th_class: default_th_class,
        td_class: default_td_class
      },
      %ColumnSpec{
        name: :inserted_at,
        label: "Date Created",
        render_fn: &__MODULE__.render_date_column/3,
        sort_fn: &Common.sort_date/2,
        th_class: default_th_class,
        td_class: default_td_class
      },
      %ColumnSpec{
        name: :institution_url,
        label: "URL",
        th_class: default_th_class,
        td_class: default_td_class
      },
      %ColumnSpec{
        name: :actions,
        label: "Settings",
        render_fn: &__MODULE__.render_actions_column/3,
        sortable: false,
        th_class: default_th_class,
        td_class: "text-nowrap " <> default_td_class
      }
    ]

    sort_by_spec = Enum.find(column_specs, fn spec -> spec.name == :name end)

    SortableTableModel.new(
      rows: institutions,
      column_specs: column_specs,
      event_suffix: "_institutions",
      id_field: [:id],
      sort_by_spec: sort_by_spec,
      sort_order: :asc,
      data: %{
        ctx: ctx
      }
    )
  end

  def render_name_column(assigns, institution, _) do
    assigns = Map.merge(assigns, %{institution: institution})

    ~H"""
    <.link navigate={
      Routes.live_path(
        OliWeb.Endpoint,
        OliWeb.Admin.Institutions.SectionsAndStudentsView,
        @institution.id,
        :sections
      )
    }>
      {@institution.name}
    </.link>
    """
  end

  def render_type_column(assigns, institution, _) do
    type = get_institution_type(institution)
    assigns = Map.merge(assigns, %{type: type})

    ~H"""
    <div
      data-active="False"
      data-hover="False"
      data-muted="False"
      data-type="Dropdown"
      class={[
        "px-2 py-1 rounded-[999px] shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] inline-flex justify-center items-center gap-2 overflow-hidden",
        (@type == "LMS" && "bg-Fill-Accent-fill-accent-teal text-Text-text-accent-teal") ||
          "bg-Fill-Accent-fill-accent-orange text-Text-text-accent-orange"
      ]}
    >
      <div class="flex justify-center text-sm font-semibold items-center gap-2">
        {@type}
      </div>
    </div>
    """
  end

  def sort_type_column(sort_order, _spec) do
    {fn institution ->
       type = get_institution_type(institution)
       # Convert to sortable value: "Direct" = 0, "LMS" = 1
       if type == "LMS", do: 1, else: 0
     end, sort_order}
  end

  defp get_institution_type(institution) do
    if Ecto.assoc_loaded?(institution.deployments) && length(institution.deployments) > 0 do
      "LMS"
    else
      "Direct"
    end
  end

  def render_date_column(assigns, institution, _) do
    # Use :minutes precision to get format like "November 15, 2024 3:03 PM"
    opts = [ctx: assigns.ctx, show_timezone: false, precision: :minutes]
    FormatDateTime.date(Map.get(institution, :inserted_at), opts)
  end

  def render_actions_column(assigns, institution, _) do
    assigns = Map.merge(assigns, %{institution: institution})

    ~H"""
    <.link
      navigate={Routes.institution_path(OliWeb.Endpoint, :show, @institution)}
      class="w-28 px-6 py-2 rounded-md shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] outline outline-1 outline-offset-[-1px] outline-Border-border-bold/50 inline-flex items-center gap-2 overflow-hidden text-center justify-center text-Specialty-Tokens-Text-text-button-secondary text-sm font-semibold font-['Open_Sans'] leading-4"
    >
      Details
    </.link>
    """
  end
end
