defmodule Oli.Delivery.Gating.ConditionTypes.ProgressTest do
  use Oli.DataCase

  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Gating
  alias Oli.Delivery.Gating.ConditionTypes.{ConditionContext, Progress}

  def insert_resource_attempt(resource_access, revision_id, attrs) do
    Core.create_resource_attempt(
      Map.merge(
        %{
          attempt_guid: UUID.uuid4(),
          attempt_number: 1,
          content: %{},
          resource_access_id: resource_access.id,
          revision_id: revision_id
        },
        attrs
      )
    )
  end

  describe "progress condition type" do
    setup do
      Seeder.base_project_with_resource4()
      |> Seeder.add_users_to_section(:section_1, [:user_a, :user_b])
    end

    test "evaluate/2 returns false when the source page has not been visited", %{
      page1: resource,
      section_1: section,
      user_a: user,
      page2: resource2
    } do
      context = ConditionContext.init(user, section)

      {:ok, gating_condition} =
        Gating.create_gating_condition(%{
          type: :progress,
          data: %{
            resource_id: resource2.id
          },
          resource_id: resource.id,
          section_id: section.id
        })

      assert {false, _} = Progress.evaluate(gating_condition, context)
    end

    test "evaluate/2 returns false when only a resource access record exists", %{
      page1: resource,
      section_1: section,
      user_a: user,
      page2: resource2
    } do
      context = ConditionContext.init(user, section)

      Core.track_access(resource2.id, section.id, user.id)

      {:ok, gating_condition} =
        Gating.create_gating_condition(%{
          type: :progress,
          data: %{
            resource_id: resource2.id
          },
          resource_id: resource.id,
          section_id: section.id
        })

      assert {false, _} = Progress.evaluate(gating_condition, context)
    end

    test "evaluate/2 returns true when one resource attempt exists and minimum progress is not set",
         %{
           page1: resource,
           section_1: section,
           user_a: user,
           page2: resource2,
           revision2: revision2
         } do
      context = ConditionContext.init(user, section)

      ra = Core.track_access(resource2.id, section.id, user.id)
      insert_resource_attempt(ra, revision2.id, %{})

      {:ok, gating_condition} =
        Gating.create_gating_condition(%{
          type: :progress,
          data: %{
            resource_id: resource2.id
          },
          resource_id: resource.id,
          section_id: section.id
        })

      assert {true, _} = Progress.evaluate(gating_condition, context)
    end

    test "evaluate/2 returns false when minimum progress is not met", %{
      page1: resource,
      section_1: section,
      user_a: user,
      page2: resource2,
      revision2: revision2
    } do
      context = ConditionContext.init(user, section)

      ra = Core.track_access(resource2.id, section.id, user.id)
      Core.update_resource_access(ra, %{progress: 0.5})

      insert_resource_attempt(ra, revision2.id, %{
        date_evaluated: DateTime.utc_now(),
        progress: 0.5
      })

      {:ok, gating_condition} =
        Gating.create_gating_condition(%{
          type: :progress,
          data: %{
            resource_id: resource2.id,
            minimum_percentage: 0.8
          },
          resource_id: resource.id,
          section_id: section.id
        })

      assert {false, _} = Progress.evaluate(gating_condition, context)
    end

    test "evaluate/2 returns true when minimum progress is met", %{
      page1: resource,
      section_1: section,
      user_a: user,
      page2: resource2,
      revision2: revision2
    } do
      context = ConditionContext.init(user, section)

      ra = Core.track_access(resource2.id, section.id, user.id)
      Core.update_resource_access(ra, %{progress: 0.7})

      insert_resource_attempt(ra, revision2.id, %{
        date_evaluated: DateTime.utc_now(),
        progress: 0.7
      })

      {:ok, gating_condition} =
        Gating.create_gating_condition(%{
          type: :finished,
          data: %{
            resource_id: resource2.id,
            minimum_percentage: 0.5
          },
          resource_id: resource.id,
          section_id: section.id
        })

      assert {true, _} = Progress.evaluate(gating_condition, context)
    end
  end
end
