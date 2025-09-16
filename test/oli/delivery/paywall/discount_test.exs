defmodule Oli.Delivery.Paywall.DiscountTest do
  use Oli.DataCase, async: true

  alias Oli.Delivery.Paywall.Discount

  import Oli.Factory

  describe "Discount changeset validations" do
    setup do
      institution = insert(:institution)
      {:ok, institution: institution}
    end

    test "valid percentage discount", %{institution: institution} do
      attrs = %{
        type: :percentage,
        percentage: 10.0,
        institution_id: institution.id
      }

      changeset = Discount.changeset(%Discount{}, attrs)
      assert changeset.valid?
    end

    test "percentage discount fails if percentage is missing", %{institution: institution} do
      attrs = %{
        type: :percentage,
        institution_id: institution.id
      }

      changeset = Discount.changeset(%Discount{}, attrs)
      refute changeset.valid?
      assert %{percentage: ["can't be blank"]} = errors_on(changeset)
    end

    test "percentage discount fails if percentage is out of range", %{institution: institution} do
      attrs = %{
        type: :percentage,
        percentage: 0.05,
        institution_id: institution.id
      }

      changeset = Discount.changeset(%Discount{}, attrs)
      refute changeset.valid?
      assert %{percentage: ["must be greater than or equal to 0.1"]} = errors_on(changeset)
    end

    test "valid fixed amount discount", %{institution: institution} do
      attrs = %{
        type: :fixed_amount,
        amount: Money.new(20, "USD"),
        institution_id: institution.id
      }

      changeset = Discount.changeset(%Discount{}, attrs)
      assert changeset.valid?
    end

    test "fixed amount discount fails if amount is missing", %{institution: institution} do
      attrs = %{
        type: :fixed_amount,
        institution_id: institution.id
      }

      changeset = Discount.changeset(%Discount{}, attrs)
      refute changeset.valid?
      assert %{amount: ["can't be blank"]} = errors_on(changeset)
    end

    test "fixed amount discount fails if amount is too small", %{institution: institution} do
      attrs = %{
        type: :fixed_amount,
        amount: Money.new(0.5, "USD"),
        institution_id: institution.id
      }

      changeset = Discount.changeset(%Discount{}, attrs)
      refute changeset.valid?
      assert %{amount: ["is invalid"]} = errors_on(changeset)
    end

    test "bypass_paywall disables type-specific validations", %{institution: institution} do
      attrs = %{
        bypass_paywall: true,
        institution_id: institution.id
      }

      changeset = Discount.changeset(%Discount{}, attrs)
      assert changeset.valid?
    end

    test "requires institution_id" do
      attrs = %{
        type: :percentage,
        percentage: 10.0
      }

      changeset = Discount.changeset(%Discount{}, attrs)
      refute changeset.valid?
      assert %{institution_id: ["can't be blank"]} = errors_on(changeset)
    end
  end
end
