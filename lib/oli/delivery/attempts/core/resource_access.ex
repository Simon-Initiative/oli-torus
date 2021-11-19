defmodule Oli.Delivery.Attempts.Core.ResourceAccess do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resource_accesses" do
    field(:access_count, :integer)
    field(:score, :float)
    field(:out_of, :float)

    field(:last_sync_score, :float)
    field(:last_sync_out_of, :float)
    field(:last_sync_type, Ecto.Enum, values: [:inline, :manual, :manual_batch], default: :inline)
    field(:last_sync_datetime, :utc_datetime)
    field(:last_sync_result, Ecto.Enum, values: [:success, :failure, :not_run], default: :not_run)
    field(:last_sync_details, :string)

    belongs_to(:user, Oli.Accounts.User)
    belongs_to(:section, Oli.Delivery.Sections.Section)
    belongs_to(:resource, Oli.Resources.Resource)
    has_many(:resource_attempts, Oli.Delivery.Attempts.Core.ResourceAttempt)

    field :resource_attempts_count, :integer, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(resource_access, attrs) do
    resource_access
    |> cast(attrs, [
      :access_count,
      :score,
      :out_of,
      :last_sync_score,
      :last_sync_out_of,
      :last_sync_type,
      :last_sync_datetime,
      :last_sync_result,
      :last_sync_details,
      :user_id,
      :section_id,
      :resource_id
    ])
    |> validate_required([:access_count, :user_id, :section_id, :resource_id])
    |> validate_score()
    |> validate_out_of()
    |> unique_constraint(:entry, name: :resource_accesses_unique_index)
  end

  def validate_score(changeset) do
    validate_change(changeset, :score, fn _, score ->
      cond do
        score < 0 -> [{:score, "must greater than or equal to zero"}]
        score > get_field(changeset, :out_of) -> [{:score, "must be less than out of value"}]
        true -> []
      end
    end)
  end

  def validate_out_of(changeset) do
    validate_change(changeset, :out_of, fn _, out_of ->
      cond do
        out_of < 0 -> [{:out_of, "must greater than or equal to zero"}]
        out_of < get_field(changeset, :score) -> [{:out_of, "must be greater than score"}]
        true -> []
      end
    end)
  end
end
