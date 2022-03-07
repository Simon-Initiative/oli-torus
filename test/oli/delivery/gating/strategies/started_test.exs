defmodule Oli.Delivery.Gating.ConditionTypes.StartedTest do
  use Oli.DataCase
  alias Oli.Delivery.Gating.ConditionTypes.ConditionContext
  alias Oli.Delivery.Attempts.Core

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

  describe "started condition type" do
    alias Oli.Delivery.Gating
    alias Oli.Delivery.Gating.ConditionTypes.Started

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
          type: :started,
          data: %{
            resource_id: resource2.id
          },
          resource_id: resource.id,
          section_id: section.id
        })

      assert {false, _} = Started.evaluate(gating_condition, context)
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
          type: :started,
          data: %{
            resource_id: resource2.id
          },
          resource_id: resource.id,
          section_id: section.id
        })

      assert {false, _} = Started.evaluate(gating_condition, context)
    end

    test "evaluate/2 returns true when one resource attempt exists", %{
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
          type: :started,
          data: %{
            resource_id: resource2.id
          },
          resource_id: resource.id,
          section_id: section.id
        })

      assert {true, _} = Started.evaluate(gating_condition, context)
    end

    test "evaluate/2 returns false when one resource attempt exists for a different user only", %{
      page1: resource,
      section_1: section,
      user_a: user,
      user_b: user_b,
      page2: resource2,
      revision2: revision2
    } do
      context = ConditionContext.init(user, section)

      Core.track_access(resource2.id, section.id, user.id)

      ra = Core.track_access(resource2.id, section.id, user_b.id)
      insert_resource_attempt(ra, revision2.id, %{})

      {:ok, gating_condition} =
        Gating.create_gating_condition(%{
          type: :started,
          data: %{
            resource_id: resource2.id
          },
          resource_id: resource.id,
          section_id: section.id
        })

      assert {false, _} = Started.evaluate(gating_condition, context)
    end
  end
end
