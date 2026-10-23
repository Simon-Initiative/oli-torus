defmodule OliWeb.ManualGrading.TableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.Utils
  alias Phoenix.LiveView.JS

  @doc """
  The manual scoring table. `table_params` are the URL params the student links carry to the
  scoring page, so its Previous/Next queue is this table's current filtered and sorted result.
  """
  def new(attempts, activity_types_map, ctx, section_slug, table_params) do
    SortableTableModel.new(
      rows: attempts,
      column_specs: [
        %ColumnSpec{
          name: :user,
          label: "Student",
          render_fn: &__MODULE__.render_student/3
        },
        %ColumnSpec{
          name: :activity_title,
          label: "Activity"
        },
        %ColumnSpec{
          name: :attempt_number,
          label: "Activity Attempt"
        },
        %ColumnSpec{
          name: :page_title,
          label: "Page"
        },
        %ColumnSpec{
          name: :resource_attempt_number,
          label: "Page Attempt"
        },
        date_submitted_spec(),
        %ColumnSpec{
          name: :activity_type_id,
          label: "Activity Type",
          render_fn: &__MODULE__.render_activity_type/3
        },
        %ColumnSpec{
          name: :graded,
          label: "Purpose",
          render_fn: &__MODULE__.render_purpose/3
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{
        activity_types_map: activity_types_map,
        ctx: ctx,
        section_slug: section_slug,
        table_params: table_params
      }
    )
  end

  def date_submitted_spec() do
    %ColumnSpec{
      name: :date_submitted,
      label: "Date Submitted",
      render_fn: &OliWeb.Common.Table.Common.render_date/3
    }
  end

  # The link's empty `phx-click` keeps the row's own click from also firing: one navigation.
  def render_student(%{section_slug: section_slug, table_params: table_params} = assigns, row, _) do
    name = Utils.name(row.user)

    assigns =
      Map.merge(assigns, %{
        name: name,
        href: scoring_path(section_slug, row.id, table_params),
        label: "Score submission: #{name}, #{row.activity_title}, attempt #{row.attempt_number}"
      })

    ~H"""
    <.link
      href={@href}
      aria-label={@label}
      phx-click={%JS{}}
      class="font-medium text-Text-text-link hover:underline"
    >
      {@name}
    </.link>
    """
  end

  def render_purpose(_, row, _) do
    if row.graded do
      "Scored"
    else
      "Practice"
    end
  end

  def render_activity_type(%{activity_types_map: activity_types_map}, row, _) do
    Map.get(activity_types_map, row.activity_type_id).title
  end

  defp scoring_path(section_slug, id, table_params) when table_params == %{},
    do: ~p"/sections/#{section_slug}/scoring/#{id}"

  defp scoring_path(section_slug, id, table_params),
    do: ~p"/sections/#{section_slug}/scoring/#{id}?#{table_params}"
end
