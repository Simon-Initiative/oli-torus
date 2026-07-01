defmodule Oli.Delivery.InstructorCustomizations.ActivityExclusion do
  @moduledoc """
  A section- and page-scoped instructor exclusion for a delivery activity target.

  Exclusions are active while the row exists. Restoring a target deletes its row.
  Resource ids intentionally do not use foreign keys so stale exclusions remain
  harmless when authored content changes.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Delivery.Sections.Section

  @kinds [:embedded_activity, :bank_selection, :bank_candidate]
  @target_fields [:selection_id, :kind, :excluded_resource_id]

  schema "section_page_activity_exclusions" do
    belongs_to :section, Section

    field :page_resource_id, :integer
    field :selection_id, :string
    field :kind, Ecto.Enum, values: @kinds
    field :excluded_resource_id, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(exclusion, section_id, page_resource_id, attrs)
      when is_integer(section_id) and is_integer(page_resource_id) do
    exclusion
    |> cast(attrs, @target_fields)
    |> put_change(:section_id, section_id)
    |> put_change(:page_resource_id, page_resource_id)
    |> validate_required([:section_id, :page_resource_id, :kind])
    |> validate_kind_shape()
    |> assoc_constraint(:section)
    |> check_constraint(:kind,
      name: :section_page_activity_exclusions_kind_shape_check,
      message: "does not match the required fields for its exclusion kind"
    )
    |> unique_constraints()
  end

  def kinds, do: @kinds

  defp validate_kind_shape(changeset) do
    case get_field(changeset, :kind) do
      :embedded_activity ->
        changeset
        |> validate_required([:excluded_resource_id])
        |> validate_absent(:selection_id)

      :bank_selection ->
        changeset
        |> validate_required([:selection_id])
        |> validate_absent(:excluded_resource_id)

      :bank_candidate ->
        validate_required(changeset, [:selection_id, :excluded_resource_id])

      _ ->
        changeset
    end
  end

  defp validate_absent(changeset, field) do
    case get_field(changeset, field) do
      nil -> changeset
      _ -> add_error(changeset, field, "must be empty for this exclusion kind")
    end
  end

  defp unique_constraints(changeset) do
    changeset
    |> unique_constraint(:excluded_resource_id,
      name: :section_page_activity_exclusions_embedded_activity_unique_idx
    )
    |> unique_constraint(:selection_id,
      name: :section_page_activity_exclusions_bank_selection_unique_idx
    )
    |> unique_constraint(:excluded_resource_id,
      name: :section_page_activity_exclusions_bank_candidate_unique_idx
    )
  end
end
