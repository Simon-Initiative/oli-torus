defmodule Oli.Delivery.Paywall.Discount do
  use Ecto.Schema
  import Ecto.Changeset

  schema "discounts" do
    field :type, Ecto.Enum, values: [:percentage, :fixed_amount], default: :percentage

    field :percentage, :float
    field :amount, Money.Ecto.Map.Type

    belongs_to :section, Oli.Delivery.Sections.Section
    belongs_to :institution, Oli.Institutions.Institution

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section, attrs) do
    section
    |> cast(attrs, [
      :type,
      :percentage,
      :amount,
      :section_id,
      :institution_id
    ])
    # section_id is not required, leaving it nil means the discount applies to all products
    |> validate_required([:type, :percentage, :amount, :institution_id])
  end
end
