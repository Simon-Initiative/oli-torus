defmodule Oli.InstructorDashboard.StudentSupportParameterSettings do
  @moduledoc """
  Section-scoped persisted parameters for the Student Support tile.

  Each row stores the active support grouping settings for one section. Draft
  modal state and projection output are intentionally kept outside this schema.

  Threshold field suffixes encode the fixed comparison operator: `lt` means
  less than, `gt` means greater than, `lte` means less than or equal, and `gte`
  means greater than or equal.

  Field roles:

  - `section_id` owns the settings at section scope so every instructor in the
    section sees the same configuration.
  - `inactivity_days` controls the active/inactive flag and counts. It does not
    affect performance bucket membership.
  - `struggling_progress_low_lt` defines the low-progress boundary for the
    Struggling bucket.
  - `struggling_progress_high_gt` and `excelling_progress_gte` share one
    persisted high-progress boundary. The shared value defines both the
    high-progress Struggling boundary and the minimum progress boundary for
    Excelling.
  - `struggling_proficiency_lte` defines the maximum proficiency boundary for
    the Struggling bucket.
  - `excelling_proficiency_gte` defines the minimum proficiency boundary for
    the Excelling bucket.

  On Track and Not enough information do not have persisted thresholds. On
  Track is derived from remaining students with enough data, while Not enough
  information is derived when required progress or proficiency data is missing.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Delivery.Sections.Section

  @allowed_inactivity_days [7, 14, 30, 90]
  @threshold_fields [
    :struggling_progress_low_lt,
    :struggling_progress_high_gt,
    :struggling_proficiency_lte,
    :excelling_progress_gte,
    :excelling_proficiency_gte
  ]
  @settings_fields [:inactivity_days | @threshold_fields]

  @type t :: %__MODULE__{
          id: integer() | nil,
          section_id: integer() | nil,
          section: Section.t() | Ecto.Association.NotLoaded.t() | nil,
          inactivity_days: integer(),
          struggling_progress_low_lt: integer(),
          struggling_progress_high_gt: integer(),
          struggling_proficiency_lte: integer(),
          excelling_progress_gte: integer(),
          excelling_proficiency_gte: integer(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "student_support_parameter_settings" do
    belongs_to :section, Section

    field :inactivity_days, :integer, default: 7
    field :struggling_progress_low_lt, :integer, default: 40
    field :struggling_progress_high_gt, :integer, default: 80
    field :struggling_proficiency_lte, :integer, default: 40
    field :excelling_progress_gte, :integer, default: 80
    field :excelling_proficiency_gte, :integer, default: 80

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(settings, attrs) do
    settings
    |> cast(attrs, @settings_fields)
    |> validate_required(@settings_fields)
    |> validate_inclusion(:inactivity_days, @allowed_inactivity_days)
    |> validate_threshold_ranges()
    |> validate_threshold_order()
    |> check_constraints()
  end

  @doc false
  def changeset_for_section(settings, section_id, attrs) when is_integer(section_id) do
    settings
    |> changeset(attrs)
    |> put_change(:section_id, section_id)
    |> validate_required([:section_id])
    |> assoc_constraint(:section)
    |> unique_constraint(:section_id,
      name: :student_support_parameter_settings_section_id_index
    )
  end

  def settings_fields, do: @settings_fields

  def threshold_fields, do: @threshold_fields

  defp check_constraints(changeset) do
    changeset
    |> check_constraint(:inactivity_days,
      name: :student_support_parameter_settings_inactivity_days_check,
      message: "must be 7, 14, 30, or 90"
    )
    |> check_constraint(:excelling_progress_gte,
      name: :student_support_parameter_settings_progress_order_check,
      message: "must match struggling high progress threshold"
    )
    |> check_constraint(:excelling_proficiency_gte,
      name: :student_support_parameter_settings_proficiency_order_check,
      message: "must be greater than struggling proficiency threshold"
    )
  end

  defp validate_threshold_ranges(changeset) do
    Enum.reduce(@threshold_fields, changeset, fn field, changeset ->
      validate_number(changeset, field,
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: 100
      )
    end)
  end

  defp validate_threshold_order(changeset) do
    changeset
    |> validate_progress_order()
    |> validate_proficiency_order()
  end

  defp validate_progress_order(changeset) do
    low = get_field(changeset, :struggling_progress_low_lt)
    high = get_field(changeset, :struggling_progress_high_gt)
    excelling = get_field(changeset, :excelling_progress_gte)

    changeset
    |> validate_threshold_relation(
      :struggling_progress_high_gt,
      low,
      high,
      &</2,
      "must be greater than struggling low progress threshold"
    )
    |> validate_threshold_relation(
      :excelling_progress_gte,
      low,
      excelling,
      &</2,
      "must be greater than struggling low progress threshold"
    )
    |> validate_threshold_relation(
      :excelling_progress_gte,
      excelling,
      high,
      &==/2,
      "must match struggling high progress threshold"
    )
  end

  defp validate_proficiency_order(changeset) do
    struggling = get_field(changeset, :struggling_proficiency_lte)
    excelling = get_field(changeset, :excelling_proficiency_gte)

    validate_threshold_relation(
      changeset,
      :excelling_proficiency_gte,
      struggling,
      excelling,
      &</2,
      "must be greater than struggling proficiency threshold"
    )
  end

  defp validate_threshold_relation(changeset, _field, nil, _right, _comparison, _message),
    do: changeset

  defp validate_threshold_relation(changeset, _field, _left, nil, _comparison, _message),
    do: changeset

  defp validate_threshold_relation(changeset, field, left, right, comparison, message) do
    if comparison.(left, right) do
      changeset
    else
      add_error(changeset, field, message)
    end
  end
end
