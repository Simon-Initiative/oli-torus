defmodule Oli.Analytics.Datasets.JobConfig do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:section_ids, {:array, :integer}, default: [])
    field(:chunk_size, :integer, default: 10_000)
    field(:event_type, :string)
    field(:event_sub_types, {:array, :string}, default: [])
    field(:ignored_student_ids, {:array, :integer}, default: [])
    field(:excluded_fields, {:array, :string}, default: [])
  end

  @doc false
  def changeset(config, attrs) do
    config
    |> cast(attrs, [
      :section_ids,
      :chunk_size,
      :event_type,
      :event_sub_types,
      :ignored_student_ids,
      :excluded_fields
    ])
    |> validate_required([:section_ids, :chunk_size, :event_type])
  end
end
