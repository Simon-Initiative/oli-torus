defmodule Oli.ScopedFeatureFlags.RolloutsTest do
  use Oli.DataCase, async: false

  import Oli.Factory

  alias Oli.Auditing
  alias Oli.ScopedFeatureFlags.Rollouts

  @feature :canary_test_feature

  setup do
    author = insert(:author)
    project = insert(:project)
    publisher = project.publisher

    Phoenix.PubSub.subscribe(Oli.PubSub, "feature_rollouts")

    {:ok, author: author, project: project, publisher: publisher}
  end

  describe "upsert_rollout/6" do
    test "creates and updates rollout with audit + telemetry", %{author: author, project: project} do
      handler = attach_telemetry([[:torus, :feature_flag, :rollout_stage_changed]])
      project_id = project.id

      assert {:ok, rollout} =
               Rollouts.upsert_rollout(@feature, :project, project.id, :internal_only, author,
                 note: "initial"
               )

      assert rollout.stage == :internal_only
      assert_received {:stage_invalidated, "canary_test_feature", :project, ^project_id}

      events =
        Auditing.list_events(event_type: :feature_rollout_stage_changed)

      assert Enum.count(events) == 1
      assert hd(events).details["note"] == "initial"

      assert_receive {:telemetry_event, [:torus, :feature_flag, :rollout_stage_changed], _,
                      %{to_stage: :internal_only}}

      assert {:ok, rollout} =
               Rollouts.upsert_rollout(@feature, :project, project.id, :five_percent, author,
                 note: "promote"
               )

      assert rollout.stage == :five_percent
      assert_received {:stage_invalidated, "canary_test_feature", :project, ^project_id}

      assert_receive {:telemetry_event, [:torus, :feature_flag, :rollout_stage_changed], _,
                      %{to_stage: :five_percent, from_stage: :internal_only}}

      :telemetry.detach(handler)
    end

    test "delete_rollout/5 removes rollout and emits signals", %{author: author, project: project} do
      project_id = project.id

      {:ok, _} =
        Rollouts.upsert_rollout(@feature, :project, project.id, :internal_only, author)

      handler = attach_telemetry([[:torus, :feature_flag, :rollout_stage_deleted]])

      assert :ok =
               Rollouts.delete_rollout(@feature, :project, project.id, author, note: "cleanup")

      assert_received {:stage_invalidated, "canary_test_feature", :project, ^project_id}

      assert_receive {:telemetry_event, [:torus, :feature_flag, :rollout_stage_deleted], _,
                      %{stage: :internal_only}}

      events =
        Auditing.list_events(event_type: :feature_rollout_stage_deleted)

      assert Enum.count(events) == 1
      assert hd(events).details["note"] == "cleanup"

      :telemetry.detach(handler)
    end
  end

  describe "exemptions" do
    test "upsert_exemption/6 creates and updates exemptions", %{
      author: author,
      publisher: publisher
    } do
      publisher_id = publisher.id

      assert {:ok, exemption} =
               Rollouts.upsert_exemption(@feature, publisher.id, :deny, author, note: "contract")

      assert exemption.effect == :deny
      assert_received {:exemption_invalidated, "canary_test_feature", ^publisher_id}

      events =
        Auditing.list_events(event_type: :feature_rollout_exemption_upserted)

      assert Enum.count(events) == 1

      assert {:ok, exemption} =
               Rollouts.upsert_exemption(@feature, publisher.id, :force_enable, author,
                 note: "override"
               )

      assert exemption.effect == :force_enable
      assert_received {:exemption_invalidated, "canary_test_feature", ^publisher_id}
    end

    test "delete_exemption/5 removes exemption", %{
      author: author,
      publisher: publisher
    } do
      publisher_id = publisher.id

      {:ok, _} =
        Rollouts.upsert_exemption(@feature, publisher.id, :deny, author)

      handler = attach_telemetry([[:torus, :feature_flag, :rollout_exemption_deleted]])

      assert :ok = Rollouts.delete_exemption(@feature, publisher.id, author, note: "resolved")

      assert_received {:exemption_invalidated, "canary_test_feature", ^publisher_id}

      assert_receive {:telemetry_event, [:torus, :feature_flag, :rollout_exemption_deleted], _,
                      %{effect: :deny}}

      events =
        Auditing.list_events(event_type: :feature_rollout_exemption_deleted)

      assert Enum.count(events) == 1
      assert hd(events).details["note"] == "resolved"

      :telemetry.detach(handler)
    end
  end

  defp attach_telemetry(events) do
    handler_id = :"rollouts_test_#{System.unique_integer([:positive, :monotonic])}"
    parent = self()

    :telemetry.attach_many(
      handler_id,
      events,
      fn event, measurements, metadata, _ ->
        send(parent, {:telemetry_event, event, measurements, metadata})
      end,
      %{}
    )

    handler_id
  end
end
