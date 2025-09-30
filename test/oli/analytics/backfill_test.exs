defmodule Oli.Analytics.BackfillTest do
  use Oli.DataCase, async: true
  use Oban.Testing, repo: Oli.Repo

  import Oli.Utils.Seeder.AccountsFixtures

  alias Oli.Accounts.SystemRole
  alias Oli.Analytics.Backfill
  alias Oli.Analytics.Backfill.BackfillRun

  describe "schedule_backfill/2" do
    test "creates a run and enqueues a worker job" do
      admin =
        author_fixture(%{
          system_role_id: SystemRole.role_id().system_admin
        })

      attrs = %{
        "s3_pattern" => "s3://example-bucket/**/*.jsonl",
        "target_table" => "analytics.raw_events",
        "format" => "JSONAsString",
        "dry_run" => true
      }

      assert {:ok, %BackfillRun{} = run} = Backfill.schedule_backfill(attrs, admin)
      assert run.initiated_by_id == admin.id
      assert run.status == :pending
      assert run.target_table == "analytics.raw_events"

      assert_enqueued(
        worker: Oli.Analytics.Backfill.Worker,
        args: %{"run_id" => run.id}
      )
    end

    test "returns changeset errors when attributes are invalid" do
      assert {:error, %Ecto.Changeset{} = changeset} = Backfill.schedule_backfill(%{}, nil)
      assert %{s3_pattern: ["can't be blank"], target_table: ["can't be blank"]} = errors_on(changeset)
    end
  end
end
