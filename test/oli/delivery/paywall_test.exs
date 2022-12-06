defmodule Oli.Delivery.PaywallTest do
  use Oli.DataCase

  import Ecto.Query, warn: false
  import Oli.Factory

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.{Sections, Paywall}
  alias Oli.Delivery.Paywall.{AccessSummary, Discount}
  alias Oli.Publishing

  def last_week() do
    {:ok, datetime} = DateTime.now("Etc/UTC")
    DateTime.add(datetime, -(60 * 60 * 24 * 7), :second)
  end

  def hours_ago(hours) do
    {:ok, datetime} = DateTime.now("Etc/UTC")
    DateTime.add(datetime, -(60 * 60 * hours), :second)
  end

  describe "summarize_access" do
    setup do
      map = Seeder.base_project_with_resource2()

      {:ok, _} = Publishing.publish_project(map.project, "some changes")

      # Create a product using the initial publication
      {:ok, product} =
        Sections.create_section(%{
          type: :blueprint,
          requires_payment: true,
          amount: Money.new(:USD, 100),
          grace_period_days: 1,
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: map.institution.id,
          base_project_id: map.project.id,
          publisher_id: map.project.publisher_id
        })

      user1 = user_fixture() |> Repo.preload(:platform_roles)

      {:ok, section} =
        Sections.create_section(%{
          type: :enrollable,
          requires_payment: true,
          amount: Money.new(:USD, 100),
          grace_period_days: 1,
          title: "1",
          registration_open: true,
          has_grace_period: false,
          context_id: UUID.uuid4(),
          start_date: DateTime.add(DateTime.utc_now(), -5),
          end_date: DateTime.add(DateTime.utc_now(), 5),
          institution_id: map.institution.id,
          base_project_id: map.project.id,
          blueprint_id: product.id
        })

      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, codes1} = Paywall.create_payment_codes(product.slug, 10)

      %{
        product: product,
        section: section,
        map: map,
        user1: user1,
        codes1: codes1
      }
    end

    test "summarize_access/2 fails then succeeds after user pays", %{
      section: section,
      user1: user,
      codes1: codes
    } do
      refute Paywall.summarize_access(user, section).available
      assert {:ok, _} = Paywall.redeem_code(hd(codes) |> to_human(), user, section.slug)
      assert Paywall.summarize_access(user, section).available
    end

    test "summarize_access/2 succeeds during grace period", %{
      section: section,
      user1: user,
      codes1: codes
    } do
      {:ok, section} =
        Sections.update_section(section, %{
          has_grace_period: true,
          grace_period_days: 6
        })

      summary = Paywall.summarize_access(user, section)
      assert summary.available
      assert summary.reason == :within_grace_period

      assert {:ok, _} = Paywall.redeem_code(hd(codes) |> to_human(), user, section.slug)
      summary = Paywall.summarize_access(user, section)
      assert summary.available
      assert summary.reason == :paid
    end

    test "summarize_access/2 fails after grace period expires", %{
      section: section,
      user1: user
    } do
      {:ok, section} =
        Sections.update_section(section, %{
          has_grace_period: true,
          grace_period_days: 2
        })

      summary = Paywall.summarize_access(user, section)
      assert summary.available
      assert summary.reason == :within_grace_period

      {:ok, section} =
        Sections.update_section(section, %{
          start_date: last_week()
        })

      summary = Paywall.summarize_access(user, section)
      refute summary.available
      assert summary.reason == :not_paid
    end

    test "summarize_access/2 calculates grace period remaining correctly", %{
      section: section,
      user1: user
    } do
      {:ok, section} =
        Sections.update_section(section, %{
          has_grace_period: true,
          grace_period_days: 1,
          start_date: hours_ago(1)
        })

      summary = Paywall.summarize_access(user, section)
      assert summary.available
      assert summary.reason == :within_grace_period
      days = summary.grace_period_remaining |> AccessSummary.as_days()
      assert days > 0 and days < 1

      {:ok, section} =
        Sections.update_section(section, %{
          has_grace_period: true,
          grace_period_days: 2,
          start_date: hours_ago(1)
        })

      summary = Paywall.summarize_access(user, section)
      assert summary.available
      assert summary.reason == :within_grace_period
      days = summary.grace_period_remaining |> AccessSummary.as_days()
      assert days > 1.0 and days < 2.0

    end

    test "summarize_access/2 suceeds during grace period, strategy relative to student enrollment",
         %{
           section: section,
           user1: user
         } do
      {:ok, section} =
        Sections.update_section(section, %{
          has_grace_period: true,
          grace_period_days: 2,
          grace_period_strategy: :relative_to_student,
          start_date: last_week()
        })

      summary = Paywall.summarize_access(user, section)
      assert summary.available
      assert summary.reason == :within_grace_period

    end

  end

  describe "redeeming codes" do
    setup do
      map = Seeder.base_project_with_resource2()

      {:ok, _} = Publishing.publish_project(map.project, "some changes")

      # Create a product using the initial publication
      {:ok, product} =
        Sections.create_section(%{
          type: :blueprint,
          requires_payment: true,
          amount: Money.new(:USD, 100),
          grace_period_days: 1,
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: map.institution.id,
          base_project_id: map.project.id,
          publisher_id: map.project.publisher_id
        })

      {:ok, product2} =
        Sections.create_section(%{
          type: :blueprint,
          requires_payment: true,
          amount: Money.new(:USD, 100),
          grace_period_days: 1,
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: map.institution.id,
          base_project_id: map.project.id,
          publisher_id: map.project.publisher_id
        })

      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()

      {:ok, section} =
        Sections.create_section(%{
          type: :enrollable,
          requires_payment: true,
          amount: Money.new(:USD, 100),
          grace_period_days: 1,
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          start_date: DateTime.add(DateTime.utc_now(), -5),
          end_date: DateTime.add(DateTime.utc_now(), 5),
          institution_id: map.institution.id,
          base_project_id: map.project.id,
          blueprint_id: product.id
        })

      {:ok, section2} =
        Sections.create_section(%{
          type: :enrollable,
          requires_payment: true,
          amount: Money.new(:USD, 100),
          grace_period_days: 1,
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          start_date: DateTime.add(DateTime.utc_now(), -5),
          end_date: DateTime.add(DateTime.utc_now(), 5),
          institution_id: map.institution.id,
          base_project_id: map.project.id,
          blueprint_id: product2.id
        })

      Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user3.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, codes1} = Paywall.create_payment_codes(product.slug, 10)
      {:ok, codes2} = Paywall.create_payment_codes(product2.slug, 10)

      %{
        product: product,
        section: section,
        map: map,
        user1: user1,
        user2: user2,
        user3: user3,
        section2: section2,
        codes1: codes1,
        codes2: codes2
      }
    end

    test "redeem_code/3 fails when student is not enrolled", %{
      section: section,
      codes1: codes1,
      user2: user2
    } do
      assert {:error, {:not_enrolled}} ==
               Paywall.redeem_code(hd(codes1) |> to_human(), user2, section.slug)
    end

    test "redeem_code/3 fails when code applies to another product", %{
      section: section,
      codes2: codes,
      user1: user
    } do
      assert {:error, {:invalid_code}} ==
               Paywall.redeem_code(hd(codes) |> to_human(), user, section.slug)
    end

    test "redeem_code/3 fails when section does not exist", %{
      codes2: codes,
      user1: user
    } do
      assert {:error, {:unknown_section}} ==
               Paywall.redeem_code(hd(codes) |> to_human(), user, "this does not exist")
    end

    test "redeem_code/3 fails when code does not exist", %{
      section: section,
      user1: user
    } do
      assert {:error, {:invalid_code}} ==
               Paywall.redeem_code("MADE_UP", user, section.slug)
    end

    test "redeem_code/3 succeeds", %{
      section: section,
      user1: user,
      codes1: codes
    } do
      assert {:ok, _} = Paywall.redeem_code(hd(codes) |> to_human(), user, section.slug)
    end

    test "redeem_code/3 fails after it has been redeemed once", %{
      section: section,
      user1: user,
      user3: user3,
      codes1: codes
    } do
      assert {:ok, _} = Paywall.redeem_code(hd(codes) |> to_human(), user, section.slug)

      assert {:error, {:invalid_code}} =
               Paywall.redeem_code(hd(codes) |> to_human(), user3, section.slug)
    end

    test "redeem_code/3 fails if a student has already paid", %{
      section: section,
      user1: user,
      codes1: codes
    } do
      assert {:ok, _} = Paywall.redeem_code(hd(codes) |> to_human(), user, section.slug)

      assert {:error, {:already_paid}} =
               Paywall.redeem_code(Enum.at(codes, 3) |> to_human(), user, section.slug)
    end
  end

  def to_human(payment) do
    Oli.Delivery.Paywall.Payment.to_human_readable(payment.code)
  end

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
          grace_period_days: 1,
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: map.institution.id,
          base_project_id: map.project.id,
          publisher_id: map.project.publisher_id
        })

      {:ok, free} =
        Sections.create_section(%{
          type: :blueprint,
          requires_payment: false,
          amount: Money.new(:USD, 100),
          grace_period_days: 1,
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: map.institution.id,
          base_project_id: map.project.id,
          publisher_id: map.project.publisher_id
        })

      {:ok, section} =
        Sections.create_section(%{
          type: :enrollable,
          requires_payment: true,
          amount: Money.new(:USD, 100),
          grace_period_days: 1,
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          start_date: DateTime.add(DateTime.utc_now(), -5),
          end_date: DateTime.add(DateTime.utc_now(), 5),
          institution_id: map.institution.id,
          base_project_id: map.project.id,
          blueprint_id: nil
        })

      %{institution: map.institution, free: free, paid: paid, section: section}
    end

    test "section_cost_from_product/2 correctly works when no discounts present", %{
      free: free,
      paid: paid,
      institution: institution
    } do
      assert {:ok, Money.new(:USD, 0)} == Paywall.section_cost_from_product(free, institution)
      assert {:ok, Money.new(:USD, 100)} == Paywall.section_cost_from_product(paid, institution)
    end

    test "section_cost_from_product/2 correctly applies fixed amount discounts",
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

      assert {:ok, Money.new(:USD, 90)} == Paywall.section_cost_from_product(paid, institution)

      Paywall.create_discount(%{
        institution_id: institution.id,
        section_id: paid.id,
        type: :fixed_amount,
        percentage: 0,
        amount: Money.new(:USD, 80)
      })

      assert {:ok, Money.new(:USD, 80)} == Paywall.section_cost_from_product(paid, institution)
    end

    percentage_discounts = [
      %{discount: 50, expected: 50},
      %{discount: 20, expected: 80},
      %{discount: 19, expected: 81},
      %{discount: 12.45, expected: 88},
      %{discount: 12.55, expected: 87},
      %{discount: 90, expected: 10},
      %{discount: 3, expected: 97}
    ]

    for %{discount: discount, expected: expected_amount} <- percentage_discounts do
      @discount discount
      @expected_amount expected_amount

      # amount from paid is #Money<:USD, 100>
      test "section_cost_from_product/2 correctly applies percentage discount for #{discount}",
          %{
            paid: paid,
            institution: institution
          } do
        {:ok, _} =
          Paywall.create_discount(%{
            institution_id: institution.id,
            section_id: nil,
            type: :percentage,
            percentage: @discount,
            amount: Money.new(:USD, @expected_amount)
          })

        assert {:ok, Money.new(:USD, @expected_amount)} == Paywall.section_cost_from_product(paid, institution)
      end
    end

    test "section_cost_from_product/2 doesn't apply institution-specific discount to other institutions", %{
      institution: institution_a,
      paid: paid
    } do
      Paywall.create_discount(%{
        institution_id: institution_a.id,
        section_id: nil,
        type: :fixed_amount,
        percentage: 0,
        amount: Money.new(:USD, 90)
      })

      assert {:ok, Money.new(:USD, 90)} == Paywall.section_cost_from_product(paid, institution_a)

      institution_b = insert(:institution)
      assert {:ok, Money.new(:USD, 100)} == Paywall.section_cost_from_product(paid, institution_b)
    end

    test "section_cost_from_product/2 correctly works when no institution present", %{
      free: free,
      paid: paid
    } do
      assert {:ok, Money.new(:USD, 0)} == Paywall.section_cost_from_product(free, nil)
      assert {:ok, Money.new(:USD, 100)} == Paywall.section_cost_from_product(paid, nil)
    end

    test "section_cost_from_product/2 correctly works when given an enrollable section", %{
      section: section
    } do
      assert {:ok, Money.new(:USD, 100)} == Paywall.section_cost_from_product(section, nil)
    end
  end

  describe "discount" do
    test "create_discount/1 with valid data creates a discount" do
      params = params_with_assocs(:discount)

      assert {:ok, %Discount{} = discount} = Paywall.create_discount(params)
      assert discount.type == params.type
      assert discount.percentage == params.percentage
      refute discount.amount
    end

    test "create_discount/1 with invalid percentage returns error changeset" do
      institution = insert(:institution)
      params = %{
        institution_id: institution.id,
        section_id: nil,
        type: :percentage,
        amount: nil,
        percentage: 120.0
      }

      assert {:error, changeset} = Paywall.create_discount(params)
      {error, _} = changeset.errors[:percentage]
      refute changeset.valid?
      assert error =~ "must be less than or equal to %{number}"

      assert {:error, changeset} = Paywall.create_discount(Map.merge(params, %{percentage: -1}))
      {error, _} = changeset.errors[:percentage]
      refute changeset.valid?
      assert error =~ "must be greater than or equal to %{number}"
    end

    test "create_discount/1 for existing product/institution returns error changeset" do
      institution = insert(:institution)
      product = insert(:section, type: :blueprint)
      insert(:discount, institution: institution, section: product)
      params = %{
        institution_id: institution.id,
        section_id: product.id,
        type: :percentage,
        amount: Money.new(:USD, 10),
        percentage: 10.0
      }

      assert {:error, changeset} = Paywall.create_discount(params)
      {error, _} = changeset.errors[:section_id]

      refute changeset.valid?
      assert error =~ "has already been taken"
    end

    test "get_discount_by!/1 returns a discount when exists one for the section and the institution" do
      discount = insert(:discount)

      returned_discount = Paywall.get_discount_by!(%{
        section_id: discount.section_id,
        institution_id: discount.institution_id
      })

      assert discount.id == returned_discount.id
      assert discount.type == returned_discount.type
    end

    test "get_discount_by!/1 returns nil if the discount does not exist" do
      refute Paywall.get_discount_by!(%{id: 123})
    end

    test "get_discount_by!/1 raises if returns more than one result" do
      discount = insert(:discount)
      insert(:discount, section: discount.section)

      assert_raise Ecto.MultipleResultsError,
                  ~r/^expected at most one result but got 2 in query/,
                  fn -> Paywall.get_discount_by!(%{section_id: discount.section_id}) end
    end

    test "get_institution_wide_discount!/1 returns a discount when exists one for the institution" do
      discount = insert(:discount, section: nil)

      returned_discount = Paywall.get_institution_wide_discount!(discount.institution_id)

      assert discount.id == returned_discount.id
      assert discount.type == returned_discount.type
    end

    test "get_institution_wide_discount!/1 returns nil if a discount does not exist for the institution" do
      refute Paywall.get_institution_wide_discount!(123)
    end

    test "get_institution_wide_discount!/1 raises if returns more than one result" do
      discount = insert(:discount, section: nil)
      insert(:discount, institution: discount.institution, section: nil)

      assert_raise Ecto.MultipleResultsError,
                  ~r/^expected at most one result but got 2 in query/,
                  fn -> Paywall.get_institution_wide_discount!(discount.institution_id) end
    end

    test "get_product_discounts/1 returns empty if a discount does not exist for the product" do
      assert [] == Paywall.get_product_discounts(123)
    end

    test "get_product_discounts/1 returns the discounts associated with one product" do
      %Discount{id: first_discount_id} = first_discount = insert(:discount)
      %Discount{id: second_discount_id} = insert(:discount, section: first_discount.section, percentage: 90)

      assert [%Discount{id: ^first_discount_id}, %Discount{id: ^second_discount_id}]
        = Paywall.get_product_discounts(first_discount.section.id) |> Enum.sort_by(& &1.percentage)
    end

    test "update_discount/2 updates the discount successfully" do
      discount = insert(:discount)

      {:ok, updated_discount} = Paywall.update_discount(discount, %{percentage: 99.0})

      assert discount.id == updated_discount.id
      assert updated_discount.percentage == 99.0
    end

    test "update_discount/2 does not update the discount when there is an invalid field" do
      amount_discount = insert(:discount)

      {:error, changeset} = Paywall.update_discount(amount_discount, %{type: :fixed_amount, amount: nil})
      {error, _} = changeset.errors[:amount]

      refute changeset.valid?
      assert error =~ "can't be blank"

      percentage_discount = insert(:discount)

      {:error, changeset} = Paywall.update_discount(percentage_discount, %{type: :percentage, percentage: nil})
      {error, _} = changeset.errors[:percentage]

      refute changeset.valid?
      assert error =~ "can't be blank"
    end

    test "delete_discount/1 deletes the discount" do
      discount = insert(:discount)

      assert {:ok, _deleted_discount} = Paywall.delete_discount(discount)
      refute Paywall.get_discount_by!(%{id: discount.id})
    end

    test "change_discount/1 returns a discount changeset" do
      discount = insert(:discount)
      assert %Ecto.Changeset{} = Paywall.change_discount(discount)
    end

    test "create_or_update_discount/1 creates a discount" do
      params = params_with_assocs(:discount)

      assert {:ok, %Discount{} = discount} = Paywall.create_or_update_discount(params)
      assert discount.type == params.type
      assert discount.percentage == params.percentage
      refute discount.amount
    end

    test "create_or_update_discount/1 updates an existing discount" do
      discount = insert(:discount)
      params = %{
        institution_id: discount.institution_id,
        section_id: discount.section_id,
        type: :fixed_amount,
        amount: Money.new(:USD, 25),
        percentage: nil
      }

      assert {:ok, %Discount{} = updated_discount} = Paywall.create_or_update_discount(params)
      assert updated_discount.id == discount.id
      assert updated_discount.type == :fixed_amount
      assert updated_discount.amount == Money.new(:USD, 25)
      refute updated_discount.percentage
    end

    test "create_or_update_discount/1 updates an existing discount (only institution)" do
      discount = insert(:discount, section: nil)
      params = %{
        institution_id: discount.institution_id,
        section_id: nil,
        type: :fixed_amount,
        amount: Money.new(:USD, 25),
        percentage: nil
      }

      assert {:ok, %Discount{} = updated_discount} = Paywall.create_or_update_discount(params)
      assert updated_discount.id == discount.id
      assert updated_discount.type == :fixed_amount
      assert updated_discount.amount == Money.new(:USD, 25)
      refute updated_discount.percentage
    end

    test "create_or_update_discount/1 returns error if no institution is specified" do
      params = %{
        institution_id: nil,
        section_id: nil,
        type: :fixed_amount,
        amount: Money.new(:USD, 25),
        percentage: nil
      }

      {:error, changeset} = Paywall.create_or_update_discount(params)
      {error, _} = changeset.errors[:institution_id]

      refute changeset.valid?
      assert error =~ "can't be blank"
    end
  end

  describe "payments codes" do
    setup do
      product =
        insert(:section, %{
          type: :blueprint
        })

      %{
        product: product
      }
    end

    test "get an amount of payment codes for a specific product", %{product: product} do
      insert(:payment, section: product, code: 123_456_789)
      insert(:payment, section: product, code: 987_654_321)

      codes = Paywall.list_payments_by_count(product.slug, 2)
      assert length(codes) == 2
    end

    test "request more payment codes than the total number of existing payment codes, returns the amount of total existing payment codes",
         %{
           product: product
         } do
      insert(:payment, section: product, code: 123_456_789)
      insert(:payment, section: product, code: 987_654_321)

      codes = Paywall.list_payments_by_count(product.slug, 3)
      assert length(codes) == 2
    end

    test "request less payment codes than the total number of existing payment codes, returns the amount of total existing payment codes",
         %{
           product: product
         } do
      insert(:payment, section: product, code: 123_456_789)
      insert(:payment, section: product, code: 987_654_321)

      codes = Paywall.list_payments_by_count(product.slug, 1)
      assert length(codes) == 1
    end
  end
end
