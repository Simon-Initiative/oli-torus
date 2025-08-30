defmodule Oli.Delivery.Attempts.Core.LMSGradeUpdate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lms_grade_updates" do
    field(:score, :float)
    field(:out_of, :float)
    field(:type, Ecto.Enum, values: [:inline, :manual, :manual_batch], default: :inline)
    field(:result, Ecto.Enum, values: [:success, :failure, :not_synced], default: :success)
    field(:details, :string, default: nil)
    field(:attempt_number, :integer)

    belongs_to(:resource_access, Oli.Delivery.Attempts.Core.ResourceAccess)

    field :user_email, :string, virtual: true
    field :total_count, :integer, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(score, attrs) do
    score
    |> cast(attrs, [
      :score,
      :out_of,
      :type,
      :result,
      :details,
      :attempt_number,
      :resource_access_id
    ])
    |> validate_required([
      :type,
      :result,
      :attempt_number,
      :resource_access_id
    ])
  end
end
