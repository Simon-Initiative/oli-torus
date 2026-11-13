defmodule Oli.Auditing.SecretMarkersTest do
  use Oli.DataCase

  import ExUnit.CaptureLog
  import Oli.Factory

  alias Oli.Auditing
  alias Oli.Auditing.{Changes, Context, EventCatalog}

  @marker "s3cr3t-marker-7f1c"

  setup do
    instructor = insert(:user)
    %{context: Context.for_actor(instructor, source: :ui)}
  end

  test "a secret field change stores only the redaction marker", %{context: context} do
    changes =
      Changes.diff(
        %{password: nil, max_attempts: 1},
        %{password: @marker, max_attempts: 2},
        EventCatalog.contract!(:student_exception_updated).change_fields
      )

    assert {:ok, changeset} =
             Auditing.build(context, proposal(changes, %{}))

    assert {:ok, event} = Auditing.insert(changeset)

    %{rows: [[row]]} =
      Repo.query!("SELECT row_to_json(e)::text FROM audit_log_events e WHERE id = $1", [event.id])

    refute row =~ @marker
    refute event.search_text =~ @marker
  end

  test "a secret outside a secret field is rejected without echoing it", %{context: context} do
    changes = %{"max_attempts" => %{"operation" => "set", "after" => 2, "token" => @marker}}

    log =
      capture_log(fn ->
        assert {:error, changeset} = Auditing.build(context, proposal(changes, %{}))
        refute inspect(errors_on(changeset)) =~ @marker

        assert {:error, error} = Auditing.insert(changeset)
        refute inspect(error) =~ @marker
      end)

    refute log =~ @marker
    assert Repo.aggregate(Oli.Auditing.LogEvent, :count) == 0
  end

  defp proposal(changes, details) do
    %{
      event_type: :student_exception_updated,
      entity:
        {:student_exception, Oli.Auditing.EntityId.compose(section: 1, resource: 2, user: 3), %{}},
      affected: {:user, 3},
      scope: %{section_id: 1, resource_id: 2},
      changes: changes,
      details: details,
      event_key: "student_exception:1:2:3:updated"
    }
  end
end
