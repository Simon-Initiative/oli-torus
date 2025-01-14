defmodule Oli.Delivery.Utils do
  import Ecto.Changeset

  def validate_positive_money(changeset, field) do
    validate_change(changeset, field, fn _, amount ->
      case Money.compare(Money.new(:USD, 1), amount) do
        :gt -> [{field, "must be greater than or equal to one"}]
        _ -> []
      end
    end)
  end
end
