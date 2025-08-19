defmodule Oli.Delivery.Sections.ProgressScoringSettings do
  @moduledoc """
  Embedded schema for progress scoring configuration within a section.

  Configures how student progress through course content is calculated and
  synchronized to the LMS gradebook as a scored item.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :enabled, :boolean, default: false
    field :sync_mode, Ecto.Enum, values: [:automatic, :manual], default: :manual
    field :hierarchy_type, Ecto.Enum, values: [:units, :modules]
    field :container_ids, {:array, :integer}, default: []
    field :out_of, :float, default: 100.0
    field :include_zero_progress, :boolean, default: false
    field :last_sync_at, :utc_datetime
  end

  @doc """
  Creates a changeset for progress scoring settings.
  """
  def changeset(settings \\ %__MODULE__{}, attrs) do
    settings
    |> cast(attrs, [
      :enabled,
      :sync_mode,
      :hierarchy_type,
      :container_ids,
      :out_of,
      :include_zero_progress,
      :last_sync_at
    ])
    |> validate_required([:enabled, :sync_mode, :out_of, :include_zero_progress])
    |> validate_number(:out_of, greater_than: 0)
    |> validate_hierarchy_selection()
    |> validate_container_selection()
  end

  @doc """
  Creates a changeset for enabling progress scoring with required fields.
  """
  def enable_changeset(settings \\ %__MODULE__{}, attrs) do
    settings
    |> changeset(attrs)
    |> validate_required([:hierarchy_type])
    |> validate_length(:container_ids, min: 1, message: "at least one container must be selected")
  end

  @doc """
  Creates a changeset for disabling progress scoring.
  """
  def disable_changeset(settings \\ %__MODULE__{}, attrs \\ %{}) do
    attrs = Map.put(attrs, :enabled, false)
    changeset(settings, attrs)
  end

  # Private validation functions

  defp validate_hierarchy_selection(changeset) do
    enabled = get_change(changeset, :enabled) || get_field(changeset, :enabled)

    hierarchy_type =
      get_change(changeset, :hierarchy_type) || get_field(changeset, :hierarchy_type)

    if enabled && is_nil(hierarchy_type) do
      add_error(changeset, :hierarchy_type, "must be selected when progress scoring is enabled")
    else
      changeset
    end
  end

  defp validate_container_selection(changeset) do
    enabled = get_change(changeset, :enabled) || get_field(changeset, :enabled)
    container_ids = get_change(changeset, :container_ids) || get_field(changeset, :container_ids)

    if enabled && (is_nil(container_ids) || Enum.empty?(container_ids)) do
      add_error(
        changeset,
        :container_ids,
        "at least one container must be selected when progress scoring is enabled"
      )
    else
      changeset
    end
  end
end
