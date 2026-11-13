defmodule Oli.Interactives.DeliveryTest do
  use Oli.DataCase
  import Oli.Factory
  import Phoenix.ConnTest

  alias Oli.Delivery.Attempts.Core
  alias Oli.Interactives.Delivery
  @endpoint OliWeb.Endpoint

  setup do
    user = insert(:user)
    section = insert(:section)
    insert(:enrollment, user: user, section: section)
    type = Oli.Activities.get_registration_by_slug("oli_interactive")

    model = %{
      "authoring" => %{
        "parts" =>
          Enum.map(["measure", "explain"], fn id ->
            %{"id" => id, "responses" => [], "hints" => [], "scoringStrategy" => "average"}
          end)
      }
    }

    activity =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_activity(),
        activity_type_id: type.id,
        content: model,
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average")
      )

    page =
      insert(:revision,
        graded: false,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        content: %{
          "model" => [%{"type" => "activity-reference", "activity_id" => activity.resource_id}]
        }
      )

    insert(:section_resource,
      section: section,
      resource_id: page.resource_id,
      scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
      batch_scoring: false
    )

    access = insert(:resource_access, user: user, section: section, resource: page.resource)

    page_attempt =
      insert(:resource_attempt, resource_access: access, revision: page, lifecycle_state: :active)

    attempt =
      insert(:activity_attempt,
        revision: activity,
        resource: activity.resource,
        resource_attempt: page_attempt,
        lifecycle_state: :active
      )

    for id <- ["measure", "explain"] do
      insert(:part_attempt,
        activity_attempt: attempt,
        part_id: id,
        attempt_number: 1,
        lifecycle_state: :active
      )
    end

    %{user: user, section: section, attempt: attempt, page_attempt: page_attempt}
  end

  defp call(c, method, params \\ %{}) do
    Delivery.execute(c.user.id, c.section.slug, c.attempt.attempt_guid, %{
      "version" => 1,
      "method" => method,
      "params" => params
    })
  end

  test "activity and enrollment state persist independently and preserve other keys", c do
    assert {:ok, nil} = call(c, "attempt.get", %{"key" => "progress"})

    assert {:ok, %{"step" => 2}} =
             call(c, "attempt.set", %{"key" => "progress", "value" => %{"step" => 2}})

    assert {:ok, 3} = call(c, "attempt.set", %{"key" => "other", "value" => 3})
    assert {:ok, %{"step" => 2}} = call(c, "attempt.get", %{"key" => "progress"})
    assert {:ok, nil} = call(c, "section.get", %{"key" => "progress"})
    assert {:ok, true} = call(c, "section.set", %{"key" => "completedLab", "value" => true})
    assert Repo.reload!(c.attempt).state == %{"progress" => %{"step" => 2}, "other" => 3}
    assert Repo.reload!(c.page_attempt).state == %{}

    assert Oli.Delivery.Sections.get_enrollment(c.section.slug, c.user.id).state == %{
             "completedLab" => true
           }
  end

  test "finalization preserves retries and waits for explicit overall completion", c do
    assert {:error, :incomplete_parts} = call(c, "activity.finalize")

    assert {:error, :unknown_part} =
             call(c, "parts.finalize", %{"partId" => "bad", "response" => 1, "correct" => true})

    assert {:ok, %{status: :active}} =
             call(c, "parts.finalize", %{
               "partId" => "measure",
               "response" => %{"value" => 7},
               "correct" => false
             })

    assert {:ok, %{status: :active, parts: parts}} =
             call(c, "parts.finalize", %{
               "partId" => "measure",
               "response" => %{"value" => 4},
               "correct" => true
             })

    assert Enum.find(parts, &(&1.id == "measure")).attemptNumber == 2

    attempts =
      Repo.all(
        from p in Core.PartAttempt,
          where: p.activity_attempt_id == ^c.attempt.id and p.part_id == "measure",
          order_by: p.attempt_number
      )

    assert Enum.map(attempts, & &1.score) == [0.0, 1.0]
    assert hd(attempts).response["input"] == %{"value" => 7}

    assert {:ok, _} =
             call(c, "parts.finalize", %{
               "partId" => "explain",
               "response" => "because",
               "correct" => false
             })

    assert {:ok, %{status: :evaluated, score: 0.5, outOf: 1.0, readOnly: true}} =
             call(c, "activity.finalize")

    assert {:ok, %{status: :evaluated}} = call(c, "activity.finalize")

    assert {:error, :read_only} =
             call(c, "parts.finalize", %{
               "partId" => "measure",
               "response" => 8,
               "correct" => true
             })
  end

  test "an owned attempt in an enrollment-optional section connects and persists state", c do
    enrollment = Oli.Delivery.Sections.get_enrollment(c.section.slug, c.user.id)
    Repo.delete!(enrollment)

    path =
      "/api/v1/state/course/#{c.section.slug}/activity_attempt/#{c.attempt.attempt_guid}/interactive"

    conn = build_conn() |> log_in_user(c.user)

    # Enrollment remains required for ordinary sections.
    section = c.section |> Ecto.Changeset.change(requires_enrollment: true) |> Repo.update!()
    assert %{"error" => %{"code" => "not_found"}} = conn |> get(path) |> json_response(404)
    section |> Ecto.Changeset.change(requires_enrollment: false) |> Repo.update!()

    assert %{"result" => %{"version" => 1, "readOnly" => false}} =
             conn |> get(path) |> json_response(200)

    assert {:ok, %{"step" => 2}} =
             call(c, "attempt.set", %{"key" => "progress", "value" => %{"step" => 2}})

    assert {:ok, 2} = call(c, "section.set", %{"key" => "shared", "value" => 2})
    assert {:ok, 2} = call(c, "section.get", %{"key" => "shared"})
  end

  test "authenticated transport rejects other owners and stale attempts", c do
    path =
      "/api/v1/state/course/#{c.section.slug}/activity_attempt/#{c.attempt.attempt_guid}/interactive"

    conn = build_conn() |> log_in_user(c.user)

    assert %{"result" => %{"version" => 1, "readOnly" => false}} =
             conn |> post(path, %{"version" => 1, "method" => "context"}) |> json_response(200)

    assert %{"result" => %{"version" => 1, "readOnly" => false}} =
             conn |> get(path) |> json_response(200)

    assert {:ok, %{"step" => 2}} =
             call(c, "attempt.set", %{"key" => "progress", "value" => %{"step" => 2}})

    assert %{"result" => %{"step" => 2}} =
             conn
             |> get(path, %{"method" => "attempt.get", "key" => "progress"})
             |> json_response(200)

    assert %{"error" => %{"code" => "read_only"}} =
             conn |> get(path, %{"method" => "activity.finalize"}) |> json_response(405)

    assert Repo.get!(Oli.Delivery.Attempts.Core.ActivityAttempt, c.attempt.id).lifecycle_state ==
             :active

    stranger = insert(:user)

    assert {:error, :not_found} =
             Delivery.execute(stranger.id, c.section.slug, c.attempt.attempt_guid, %{
               "version" => 1,
               "method" => "context"
             })

    assert {:error, :not_found} =
             Delivery.execute(c.user.id, "another-section", c.attempt.attempt_guid, %{
               "version" => 1,
               "method" => "context"
             })

    insert(:activity_attempt,
      revision: c.attempt.revision,
      resource: c.attempt.resource,
      resource_attempt: c.page_attempt,
      attempt_number: c.attempt.attempt_number + 1
    )

    assert {:error, :read_only} = call(c, "attempt.set", %{"key" => "progress", "value" => 3})
  end
end
