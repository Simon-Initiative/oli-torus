defmodule Oli.Delivery.Paywall.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:code, :binary_id, autogenerate: true}

  schema "payments" do
    field :type, Ecto.Enum, values: [:direct, :deferred], default: :direct
    field :generation_date, :utc_datetime
    field :application_date, :utc_datetime
    field :amount, Money.Ecto.Map.Type

    belongs_to :section, Oli.Delivery.Sections.Section
    belongs_to :enrollment, Oli.Delivery.Sections.Enrollment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section, attrs) do
    section
    |> cast(attrs, [
      :type,
      :generation_date,
      :application_date,
      :amount,
      :section_id,
      :enrollment_id
    ])
    |> validate_required([:type, :generation_date, :application_date, :amount, :section_id])
  end

  def to_human_readable(code) do
    Base32Crockford.encode(code, partitions: 6)
  end

  def from_human_readable(human_readable_code) do
    Base32Crockford.decode(human_readable_code)
  end
end
