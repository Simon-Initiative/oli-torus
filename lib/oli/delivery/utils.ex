defmodule Oli.Delivery.Utils do
  import Ecto.Changeset

  def validate_positive_money(changeset, field) do
    validate_change(changeset, field, fn _, amount ->
      case Money.compare(Money.new(0, "USD"), amount) do
        :gt -> [{field, "must be greater than or equal to zero"}]
        _ -> []
      end
    end)
  end
end
