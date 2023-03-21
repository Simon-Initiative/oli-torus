defmodule OliWeb.Delivery.Sections.EnrollmentsTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Utils
  use Surface.LiveComponent

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end

  def new(users, section, context) do
    column_specs = [
      %ColumnSpec{
        name: :name,
        label: "STUDENT NAME",
        render_fn: &__MODULE__.render_name_column/3
      },
      %ColumnSpec{
        name: :last_interaction,
        label: "LAST INTERACTED",
        render_fn: &__MODULE__.stub_last_interacted/3
      },
      %ColumnSpec{
        name: :progress,
        label: "COURSE PROGRESS"
      },
      %ColumnSpec{
        name: :overall_mastery,
        label: "OVERALL COURSE MASTERY",
        render_fn: &__MODULE__.stub_overall_mastery/3
      },
      %ColumnSpec{
        name: :engagement,
        label: "COURSE ENGAGEMENT",
        render_fn: &__MODULE__.stub_engagement/3
      }
    ]

    # column_specs =
    #   if section.requires_payment do
    #     base_columns ++
    #       [
    #         %ColumnSpec{
    #           name: :payment_date,
    #           label: "Paid On",
    #           render_fn: &OliWeb.Common.Table.Common.render_date/3
    #         }
    #       ]
    #   else
    #     base_columns
    #   end

    SortableTableModel.new(
      rows: users,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{
        context: context,
        section_slug: section.slug
      }
    )
  end

  def render_name_column(
        assigns,
        %{
          id: id,
          name: name,
          given_name: given_name,
          family_name: family_name
        },
        _
      ) do
    ~F"""
    <div class="flex items-center ml-10">
      <div class="rounded-full w-2 h-2 bg-red-500"></div>
      <a class="ml-6" href={Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentView, assigns.section_slug, id)}>
        {Utils.name(name, given_name, family_name)}
      </a>
    </div>
    """
  end

  def render_unenroll_column(assigns, user, _) do
    ~F"""
    <button class="btn btn-outline-danger" phx-click="unenroll" phx-value-id={user.id}>
      Unenroll
    </button>
    """
  end

  def stub_last_interacted(assigns, _user, _) do
    random_datetime = DateTime.utc_now() |> DateTime.add(-Enum.random(1..365), :day)
    assigns = Map.merge(assigns, %{last_interacted_stub: random_datetime})

    ~F"""
      {Timex.format!(@last_interacted_stub, "{Mshort}. {0D}, {YYYY} - {h12}:{m} {AM}")}
    """
  end

  def stub_overall_mastery(assigns, _user, _) do
    ~F"""
       {random_stub()}
    """
  end

  def stub_engagement(assigns, _user, _) do
    ~F"""
      {random_stub()}
    """
  end

  defp random_stub(), do: Enum.random(["Low", "Medium", "High", "Not enough data"])
end
