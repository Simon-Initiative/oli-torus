defmodule Oli.Delivery.PaywallTest do
  use Oli.DataCase

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Paywall
  alias Oli.Publishing
  import Ecto.Query, warn: false

  describe "cost calculations" do
    setup do
      map = Seeder.base_project_with_resource2()

      {:ok, _} = Publishing.publish_project(map.project, "some changes")

      # Create a product using the initial publication
      {:ok, paid} =
        Sections.create_section(%{
          type: :blueprint,
          requires_payment: true,
          amount: Money.new(:USD, 100),
          title: "1",
          timezone: "1",
          registration_open: true,
          context_id: "1",
          institution_id: map.institution.id,
          base_project_id: map.project.id
        })

      {:ok, free} =
        Sections.create_section(%{
          type: :blueprint,
          requires_payment: false,
          amount: Money.new(:USD, 100),
          title: "1",
          timezone: "1",
          registration_open: true,
          context_id: "1",
          institution_id: map.institution.id,
          base_project_id: map.project.id
        })

      %{institution: map.institution, free: free, paid: paid}
    end

    test "calculate_product_cost/2 correctly works when no discounts present", %{
      free: free,
      paid: paid,
      institution: institution
    } do
      assert {:ok, Money.new(:USD, 0)} == Paywall.calculate_product_cost(free, institution)
      assert {:ok, Money.new(:USD, 100)} == Paywall.calculate_product_cost(paid, institution)
    end

    test "calculate_product_cost/2 correctly applies fixed amount discounts",
         %{
           paid: paid,
           institution: institution
         } do
      {:ok, _} =
        Paywall.create_discount(%{
          institution_id: institution.id,
          section_id: nil,
          type: :fixed_amount,
          percentage: 0,
          amount: Money.new(:USD, 90)
        })

      assert {:ok, Money.new(:USD, 90)} == Paywall.calculate_product_cost(paid, institution)

      Paywall.create_discount(%{
        institution_id: institution.id,
        section_id: paid.id,
        type: :fixed_amount,
        percentage: 0,
        amount: Money.new(:USD, 80)
      })

      assert {:ok, Money.new(:USD, 80)} == Paywall.calculate_product_cost(paid, institution)
    end

    test "calculate_product_cost/2 correctly applies percentage discounts",
         %{
           paid: paid,
           institution: institution
         } do
      {:ok, _} =
        Paywall.create_discount(%{
          institution_id: institution.id,
          section_id: nil,
          type: :percentage,
          percentage: 0.5,
          amount: Money.new(:USD, 90)
        })

      assert {:ok, Money.new(:USD, "50.0")} == Paywall.calculate_product_cost(paid, institution)

      Paywall.create_discount(%{
        institution_id: institution.id,
        section_id: paid.id,
        type: :percentage,
        percentage: 0.2,
        amount: Money.new(:USD, 80)
      })

      assert {:ok, Money.new(:USD, "20.0")} == Paywall.calculate_product_cost(paid, institution)
    end

    test "calculate_product_cost/2 correctly works when no institution present", %{
      free: free,
      paid: paid
    } do
      assert {:ok, Money.new(:USD, 0)} == Paywall.calculate_product_cost(free, nil)
      assert {:ok, Money.new(:USD, 100)} == Paywall.calculate_product_cost(paid, nil)
    end
  end
end
