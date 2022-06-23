defmodule Oli.Delivery.Paywall.Discount do
  use Ecto.Schema

  import Ecto.Changeset
  import Oli.Utils

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
    |> validate_required([:type, :institution_id])
    |> validate_required_if([:percentage], &is_percentage_type?/1)
    |> validate_required_if([:amount], &is_amount_type?/1)
    |> validate_number_if(:percentage, &is_percentage_type?/1, 0, 100)
    |> unique_constraint([:section_id, :institution_id], name: :index_discount_section_institution)
    |> foreign_key_constraint(:institution_id)
  end

  defp is_percentage_type?(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true} = changeset ->
        get_field(changeset, :type) == :percentage
      _ -> false
    end
  end

  defp is_amount_type?(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true} = changeset ->
        get_field(changeset, :type) == :fixed_amount
      _ -> false
    end
  end
end
