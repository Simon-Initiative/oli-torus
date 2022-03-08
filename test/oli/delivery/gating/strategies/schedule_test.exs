defmodule Oli.Delivery.Gating.ConditionTypes.ScheduleTest do
  use Oli.DataCase
  alias Oli.Delivery.Gating.ConditionTypes.ConditionContext

  describe "schedule condition type" do
    alias Oli.Delivery.Gating
    alias Oli.Delivery.Gating.ConditionTypes.Schedule

    setup do
      Seeder.base_project_with_resource4()
      |> Seeder.add_users_to_section(:section_1, [:user_a])
    end

    test "evaluate/2 returns true when current time is inside of the scheduled window", %{
      page1: resource,
      section_1: section,
      user_a: user
    } do
      today = DateTime.utc_now()
      yesterday = today |> DateTime.add(-(24 * 60), :second)
      tomorrow = today |> DateTime.add(24 * 60, :second)

      context = ConditionContext.init(user, section)

      {:ok, gating_condition} =
        Gating.create_gating_condition(%{
          type: :schedule,
          data: %{
            start_datetime: yesterday,
            end_datetime: tomorrow
          },
          resource_id: resource.id,
          section_id: section.id
        })

      assert {true, _} = Schedule.evaluate(gating_condition, context)
    end

    test "evaluate/2 returns false when current time is before the scheduled window", %{
      page1: resource,
      section_1: section,
      user_a: user
    } do
      today = DateTime.utc_now()
      tomorrow = today |> DateTime.add(24 * 60, :second)
      two_days_from_now = today |> DateTime.add(2 * 24 * 60, :second)

      context = ConditionContext.init(user, section)

      {:ok, gating_condition} =
        Gating.create_gating_condition(%{
          type: :schedule,
          data: %{
            start_datetime: tomorrow,
            end_datetime: two_days_from_now
          },
          resource_id: resource.id,
          section_id: section.id
        })

      assert {false, _} = Schedule.evaluate(gating_condition, context)

      yesterday = today |> DateTime.add(-(24 * 60), :second)
      two_days_before_now = today |> DateTime.add(-(2 * 24 * 60), :second)

      {:ok, gating_condition} =
        Gating.create_gating_condition(%{
          type: :schedule,
          data: %{
            start_datetime: two_days_before_now,
            end_datetime: yesterday
          },
          resource_id: resource.id,
          section_id: section.id
        })

      assert {false, _} = Schedule.evaluate(gating_condition, context)
    end

    test "evaluate/2 returns false when current time is after the scheduled window", %{
      page1: resource,
      section_1: section,
      user_a: user
    } do
      today = DateTime.utc_now()
      yesterday = today |> DateTime.add(-(24 * 60), :second)
      two_days_before_now = today |> DateTime.add(-(2 * 24 * 60), :second)

      context = ConditionContext.init(user, section)

      {:ok, gating_condition} =
        Gating.create_gating_condition(%{
          type: :schedule,
          data: %{
            start_datetime: two_days_before_now,
            end_datetime: yesterday
          },
          resource_id: resource.id,
          section_id: section.id
        })

      assert {false, _} = Schedule.evaluate(gating_condition, context)
    end

    test "evaluate/2 handles nil values for start and/or end datetimes", %{
      page1: resource,
      section_1: section,
      user_a: user
    } do
      today = DateTime.utc_now()
      yesterday = today |> DateTime.add(-(24 * 60), :second)
      tomorrow = today |> DateTime.add(24 * 60, :second)

      context = ConditionContext.init(user, section)

      # both values nil returns true
      {:ok, gating_condition} =
        Gating.create_gating_condition(%{
          type: :schedule,
          data: %{},
          resource_id: resource.id,
          section_id: section.id
        })

      assert {true, _} = Schedule.evaluate(gating_condition, context)

      # end_datetime nil and after start_datetime returns true
      {:ok, gating_condition} =
        Gating.create_gating_condition(%{
          type: :schedule,
          data: %{
            start_datetime: yesterday
          },
          resource_id: resource.id,
          section_id: section.id
        })

      assert {true, _} = Schedule.evaluate(gating_condition, context)

      # end_datetime nil and before start_datetime returns false
      {:ok, gating_condition} =
        Gating.create_gating_condition(%{
          type: :schedule,
          data: %{
            start_datetime: tomorrow
          },
          resource_id: resource.id,
          section_id: section.id
        })

      assert {false, _} = Schedule.evaluate(gating_condition, context)

      # start_datetime nil and before end_datetime returns true
      {:ok, gating_condition} =
        Gating.create_gating_condition(%{
          type: :schedule,
          data: %{
            end_datetime: tomorrow
          },
          resource_id: resource.id,
          section_id: section.id
        })

      assert {true, _} = Schedule.evaluate(gating_condition, context)

      # start_datetime nil and after end_datetime returns false
      {:ok, gating_condition} =
        Gating.create_gating_condition(%{
          type: :schedule,
          data: %{
            end_datetime: yesterday
          },
          resource_id: resource.id,
          section_id: section.id
        })

      assert {false, _} = Schedule.evaluate(gating_condition, context)
    end
  end
end
