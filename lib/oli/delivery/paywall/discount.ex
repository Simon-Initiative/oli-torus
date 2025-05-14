defmodule Oli.Delivery.Paywall.Discount do
  use Ecto.Schema

  import Ecto.Changeset
  import Oli.Utils

  schema "discounts" do
    field :type, Ecto.Enum, values: [:percentage, :fixed_amount], default: :percentage

    field :percentage, :float
    field :amount, Money.Ecto.Map.Type
    field :bypass_paywall, :boolean, default: false

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
      :bypass_paywall,
      :section_id,
      :institution_id
    ])
    # section_id is not required, leaving it nil means the discount applies to all products
    |> validate_required([:type, :institution_id])
    |> validate_required_if([:percentage], &is_percentage_type?/1)
    |> validate_required_if([:amount], &is_amount_type?/1)
    |> validate_number_if(:percentage, &is_percentage_type?/1, 0.1, 99.9)
    |> validate_amount_if(:amount, &is_amount_type?/1, 1)
    |> unique_constraint([:section_id, :institution_id],
      name: :index_discount_section_institution
    )
    |> foreign_key_constraint(:institution_id)
  end

  @doc """
  Checks if the discount type is percentage, unless bypass_paywall is enabled,
  in which case the validation is skipped.
  """
  @spec is_percentage_type?(Ecto.Changeset.t()) :: boolean()
  def is_percentage_type?(changeset) do
    if get_field(changeset, :bypass_paywall) do
      false
    else
      get_field(changeset, :type) == :percentage
    end
  end

  @doc """
  Checks if the discount type is fixed amount, unless bypass_paywall is enabled,
  in which case the validation is skipped.
  """
  @spec is_amount_type?(Ecto.Changeset.t()) :: boolean()
  def is_amount_type?(changeset) do
    if get_field(changeset, :bypass_paywall) do
      false
    else
      get_field(changeset, :type) == :fixed_amount
    end
  end

  defp validate_amount_if(changeset, field, condition, min) do
    with true <- condition.(changeset),
         amount = %Money{} <- get_field(changeset, field),
         :lt <- Money.compare(amount, Money.new(:USD, min)) do
      add_error(changeset, field, "must be greater than or equal to #{min}")
    else
      _ -> changeset
    end
  end
end
