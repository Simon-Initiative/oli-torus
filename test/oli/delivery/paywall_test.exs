defmodule Oli.Delivery.PaywallTest do
  use Oli.DataCase

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Paywall.AccessSummary

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Publishing
  import Ecto.Query, warn: false

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
          timezone: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: map.institution.id,
          base_project_id: map.project.id
        })

      user1 = user_fixture() |> Repo.preload(:platform_roles)

      {:ok, section} =
        Sections.create_section(%{
          type: :enrollable,
          requires_payment: true,
          amount: Money.new(:USD, 100),
          grace_period_days: 1,
          title: "1",
          timezone: "1",
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
          timezone: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: map.institution.id,
          base_project_id: map.project.id
        })

      {:ok, product2} =
        Sections.create_section(%{
          type: :blueprint,
          requires_payment: true,
          amount: Money.new(:USD, 100),
          grace_period_days: 1,
          title: "1",
          timezone: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: map.institution.id,
          base_project_id: map.project.id
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
          timezone: "1",
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
          timezone: "1",
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
          timezone: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: map.institution.id,
          base_project_id: map.project.id
        })

      {:ok, free} =
        Sections.create_section(%{
          type: :blueprint,
          requires_payment: false,
          amount: Money.new(:USD, 100),
          grace_period_days: 1,
          title: "1",
          timezone: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: map.institution.id,
          base_project_id: map.project.id
        })

      {:ok, section} =
        Sections.create_section(%{
          type: :enrollable,
          requires_payment: true,
          amount: Money.new(:USD, 100),
          grace_period_days: 1,
          title: "1",
          timezone: "1",
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

    test "calculate_product_cost/2 correctly works when given an enrollable section", %{
      section: section
    } do
      assert {:ok, Money.new(:USD, 100)} == Paywall.calculate_product_cost(section, nil)
    end
  end
end
