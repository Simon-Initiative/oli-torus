defmodule Oli.Delivery.SecureAssessmentDependenciesTest do
  use Oli.DataCase, async: false
  import Oli.Factory
  import Mox
  alias Oli.Delivery.SecureAssessments.{Dependencies, Review}
  alias Oli.Delivery.SecureAssessments, as: Policy
  alias Oli.Delivery.ExtrinsicState
  setup :verify_on_exit!

  setup do
    previous = Application.get_env(:oli, :blob_storage)

    Application.put_env(
      :oli,
      :blob_storage,
      Keyword.put(previous || [], :use_deprecated_api, true)
    )

    on_exit(fn -> Application.put_env(:oli, :blob_storage, previous) end)

    user =
      insert(:user, state: %{"calculator" => %{"value" => 42}, "private" => %{"secret" => "no"}})

    section = insert(:section)

    revision =
      insert(:revision,
        graded: true,
        content: %{"custom" => %{"everApps" => [%{"id" => "calculator"}]}}
      )

    sr =
      insert(:section_resource,
        section: section,
        resource_id: revision.resource_id,
        secure_delivery: true,
        review_submission: :allow,
        feedback_mode: :disallow
      )

    access = insert(:resource_access, user: user, section: section, resource: revision.resource)
    attempt = insert(:resource_attempt, resource_access: access, revision: revision)
    activity = insert(:activity_attempt, resource_attempt: attempt)
    %{user: user, section: section, sr: sr, attempt: attempt, activity: activity}
  end

  test "manifest snapshot is attempt-owned, stable and namespace bounded", c do
    guid = c.attempt.attempt_guid
    assert {:ok, %{"calculator" => %{"value" => 42}}} = Dependencies.read_shared(guid, c.user)
    assert {:error, :dependency_not_allowed} = Dependencies.read_shared(guid, c.user, ["private"])
    assert {:error, :not_found} = Dependencies.read_shared(guid, insert(:user))
    assert {:ok, _} = ExtrinsicState.upsert_global(c.user.id, %{"calculator" => %{"value" => 99}})
    assert {:ok, %{"calculator" => %{"value" => 42}}} = Dependencies.read_shared(guid, c.user)

    assert {:ok, %{"calculator" => %{"value" => 7}}} =
             Dependencies.write_shared(guid, c.user, %{"calculator" => %{"value" => 7}})

    assert {:ok, %{"calculator" => %{"value" => 99}}} =
             ExtrinsicState.read_global(c.user.id, MapSet.new(["calculator"]))

    assert Dependencies.page_state(c.attempt, %{}) == %{"app.calculator.value" => 7}
    assert {:ok, _} = ExtrinsicState.upsert_attempt(guid, %{"__secure_shared" => %{}})
    assert {:ok, _} = ExtrinsicState.delete_attempt(guid, MapSet.new(["__secure_shared"]))
    assert Dependencies.page_state(c.attempt, %{}) == %{"app.calculator.value" => 7}
  end

  test "snapshot preserves shared fields when saved attempt data overrides one key", c do
    {:ok, _} =
      ExtrinsicState.upsert_global(c.user.id, %{"calculator" => %{"value" => 42, "units" => "cm"}})

    {:ok, _} =
      ExtrinsicState.upsert_attempt(c.attempt.attempt_guid, %{"app.calculator.value" => 7})

    assert {:ok, %{"calculator" => %{"value" => 7, "units" => "cm"}}} =
             Dependencies.read_shared(c.attempt.attempt_guid, c.user)
  end

  test "both adaptive renderers use feedback-safe, confined initial props", c do
    params = %{
      sectionSlug: c.section.slug,
      pageSlug: "assessment",
      reviewMode: true,
      content: %{"backUrl" => "/other-course"},
      resourceAttemptState: %{"session.tutorialScore" => 12345},
      overviewURL: "/course",
      isInstructor: true,
      screenIdleTimeOutInSeconds: 1800
    }

    settings = %Oli.Delivery.Settings.Combined{feedback_mode: :disallow}

    secure = %{
      scope: %Oli.Delivery.SecureAssessments.Scope{
        section_id: c.section.id,
        resource_id: c.sr.resource_id
      }
    }

    props =
      OliWeb.SecureAssessmentPresentation.adaptive_params(
        params,
        secure,
        true,
        c.attempt,
        settings
      )

    assert props.secureDelivery
    assert props.assessmentState
    assert props.content == %{}
    assert props.resourceAttemptState == %{}
    assert props.overviewURL == nil
    assert props.nextPageURL == nil
    assert props.screenIdleTimeOutInSeconds == 0
    refute props.isInstructor

    ordinary =
      OliWeb.SecureAssessmentPresentation.adaptive_params(params, nil, true, c.attempt, settings)

    refute ordinary.secureDelivery
    assert ordinary.overviewURL == "/course"
    assert ordinary.resourceAttemptState == %{}
  end

  test "review never seeds from global data or accepts updates", c do
    attempt = c.attempt |> Ecto.Changeset.change(lifecycle_state: :evaluated) |> Repo.update!()
    assert {:ok, %{}} = Dependencies.read_shared(attempt.attempt_guid, c.user)
    assert Repo.reload!(attempt).state == attempt.state

    assert {:error, :review_not_allowed} =
             Dependencies.write_shared(attempt.attempt_guid, c.user, %{"calculator" => %{}})
  end

  test "blob provider snapshots nonempty inputs and fails closed on storage outage", c do
    Application.put_env(:oli, :blob_storage, use_deprecated_api: false, bucket_name: "test")

    expect(Oli.Test.MockAws, :request, 2, fn op ->
      body =
        case String.ends_with?(op.path, "/calculator") do
          true -> ~s({"value":42,"units":"cm"})
          false -> ~s({"app.calculator.value":7})
        end

      {:ok, %{status_code: 200, body: body}}
    end)

    assert {:ok, %{"calculator" => %{"value" => 7, "units" => "cm"}}} =
             Dependencies.read_shared(c.attempt.attempt_guid, c.user)

    other =
      insert(:resource_attempt,
        resource_access: c.attempt.resource_access,
        revision: c.attempt.revision
      )

    expect(Oli.Test.MockAws, :request, fn _ -> {:error, {:http_error, 503, "unavailable"}} end)

    assert {:error, :dependency_unavailable} =
             Dependencies.read_shared(other.attempt_guid, c.user)

    refute Map.has_key?(Repo.reload!(other).state || %{}, "__secure_shared")
  end

  test "model resolution uses actual pinned membership, not an arbitrary current revision", c do
    assert {:ok, _, [activity]} =
             Policy.resolve_models(c.attempt.attempt_guid, [c.activity.resource_id])

    assert activity.revision.id == c.activity.revision_id

    assert {:error, :not_found} =
             Policy.resolve_models(c.attempt.attempt_guid, [insert(:resource).id])
  end

  test "filtered finalized reads enforce review policy and preserve hidden-feedback responses",
       c do
    c.attempt |> Ecto.Changeset.change(lifecycle_state: :evaluated) |> Repo.update!()
    {:ok, targets} = Policy.resolve_attempts(:activity, [c.activity.attempt_guid])
    assert :ok = Policy.authorize_batch(nil, c.user.id, :filtered_dependency_read, targets)
    assert Review.visibility([c.activity.attempt_guid]) == %{c.activity.attempt_guid => false}
    now = DateTime.utc_now()
    response = %{"score" => "a student-entered property"}

    assert %{score: nil, feedback: nil, response: ^response, date: ^now} =
             Review.project(%{score: 1, feedback: "answer", response: response, date: now}, false)

    assert Review.page_state(
             %{
               "session.tutorialScore" => 99,
               "session.currentQuestionScore" => 12,
               "session.visitTimestamps.screen" => 1,
               "app.calculator.value" => 7
             },
             false
           ) ==
             %{"session.visitTimestamps.screen" => 1, "app.calculator.value" => 7}

    c.sr |> Ecto.Changeset.change(review_submission: :disallow) |> Repo.update!()

    assert {:error, :review_not_allowed} =
             Policy.authorize_batch(nil, c.user.id, :filtered_dependency_read, targets)
  end
end
