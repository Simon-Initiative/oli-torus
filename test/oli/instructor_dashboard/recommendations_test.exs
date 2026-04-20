defmodule Oli.InstructorDashboard.RecommendationsTest do
  use Oli.DataCase

  import Ecto.Query
  import ExUnit.CaptureLog
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Dashboard.OracleContext
  alias Oli.Dashboard.Cache
  alias Oli.Dashboard.Cache.InProcessStore
  alias Oli.Dashboard.RevisitCache
  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.Delivery.Sections
  alias Oli.InstructorDashboard.Recommendations
  alias Oli.Resources.ResourceType

  @lifecycle_event [:oli, :instructor_dashboard, :recommendation, :lifecycle, :stop]
  @section_attrs %{
    context_id: "context_id",
    end_date: ~U[2010-05-17 00:00:00.000000Z],
    open_and_free: true,
    registration_open: true,
    requires_enrollment: true,
    start_date: ~U[2010-04-17 00:00:00.000000Z],
    title: "some title"
  }

  setup do
    map = Seeder.base_project_with_resource2()

    {:ok, section} =
      @section_attrs
      |> Map.put(:base_project_id, map.project.id)
      |> Map.put(:institution_id, map.institution.id)
      |> Oli.Delivery.Sections.create_section()

    user = insert(:user)
    Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])

    {:ok, context} =
      OracleContext.new(%{
        dashboard_context_type: :section,
        dashboard_context_id: section.id,
        user_id: user.id,
        scope: %{container_type: :course, container_id: nil}
      })

    {:ok, %{section: section, user: user, context: context}}
  end

  test "creates and reuses an implicit recommendation within 24 hours", %{
    context: context,
    section: section
  } do
    Process.put(:recommendations_test_pid, self())

    snapshot_bundle = snapshot_bundle_fixture(section.id)

    assert {:ok, first} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_ok/3
             )

    assert first.state == :ready
    assert first.generation_mode == :implicit
    assert first.metadata.prompt_version == "recommendation_prompt_v1"
    assert_received :recommendation_generate_called

    assert {:ok, second} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_ok/3
             )

    assert second.id == first.id
    refute_received :recommendation_generate_called
  end

  test "creates a newer recommendation for explicit regeneration", %{
    context: context,
    section: section,
    user: user
  } do
    Process.put(:recommendations_test_pid, self())
    snapshot_bundle = snapshot_bundle_fixture(section.id)

    assert {:ok, first} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_ok/3
             )

    assert {:ok, regenerated} =
             Recommendations.regenerate_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_ok/3
             )

    assert regenerated.id != first.id
    assert regenerated.generation_mode == :explicit_regen

    latest = Recommendations.latest_instance(section.id, context.scope)
    assert latest.id == regenerated.id
    assert latest.generated_by_user_id == user.id
  end

  test "uses section-level prompt template when caller does not pass prompt_template", %{
    context: context,
    section: section
  } do
    marker = "ARG_TEST_001"

    {:ok, _section} =
      Sections.update_section(section, %{
        instructor_recommendation_prompt_template:
          "Always start your final recommendation with: [#{marker}]"
      })

    snapshot_bundle = snapshot_bundle_fixture(section.id)
    parent = self()

    execution_fun = fn _request_ctx, messages, _service_config ->
      system_prompt =
        messages
        |> Enum.find(%{}, fn message -> Map.get(message, :role) == :system end)
        |> Map.get(:content, "")

      send(parent, {:recommendation_system_prompt, system_prompt})
      {:ok, "[#{marker}] Test recommendation"}
    end

    assert {:ok, recommendation} =
             Recommendations.regenerate_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: execution_fun
             )

    assert recommendation.message =~ "[#{marker}]"
    assert_receive {:recommendation_system_prompt, system_prompt}
    assert system_prompt =~ "[#{marker}]"
  end

  test "persists original_prompt and execution metadata for generated recommendations", %{
    context: context,
    section: section
  } do
    Process.put(:recommendations_test_pid, self())
    snapshot_bundle = snapshot_bundle_fixture(section.id)

    assert {:ok, recommendation} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_with_metadata/3
             )

    latest = Recommendations.latest_instance(section.id, context.scope)

    assert recommendation.metadata.model == "gpt-4.1"
    assert recommendation.metadata.provider == "openai"
    assert recommendation.metadata.registered_model_id == 12
    assert recommendation.metadata.service_config_id == 7
    assert recommendation.metadata.provider_usage == %{tokens: 123}

    assert %{"messages" => [system_message, user_message]} = latest.original_prompt
    assert system_message["role"] == "system"
    assert user_message["role"] == "user"
    assert user_message["content"] =~ "Prompt version: recommendation_prompt_v1"
  end

  test "reuses an in-flight generating instance for the same scope", %{
    context: context,
    section: section
  } do
    parent = self()
    block_ref = make_ref()
    snapshot_bundle = snapshot_bundle_fixture(section.id)

    execution_fun = fn _request_ctx, _messages, _service_config ->
      send(parent, {:recommendation_execution_started, self(), block_ref})

      receive do
        {:allow_execution, ^block_ref} ->
          {:ok, "Review Quiz 1 performance now."}
      end
    end

    task =
      Task.async(fn ->
        Recommendations.get_recommendation(context,
          snapshot_bundle: snapshot_bundle,
          execution_fun: execution_fun
        )
      end)

    assert_receive {:recommendation_execution_started, execution_pid, ^block_ref}

    assert {:ok, in_flight} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: fn _, _, _ -> flunk("should not start a duplicate generation") end
             )

    assert in_flight.state == :generating
    assert in_flight.generation_mode == :implicit

    send(execution_pid, {:allow_execution, block_ref})

    assert {:ok, completed} = Task.await(task)
    assert completed.state == :ready
    assert completed.id == in_flight.id
  end

  test "expires a stale generating instance and starts a fresh implicit generation", %{
    context: context,
    section: section
  } do
    Process.put(:recommendations_test_pid, self())
    snapshot_bundle = snapshot_bundle_fixture(section.id)

    {:ok, generating} =
      %Oli.InstructorDashboard.Recommendations.RecommendationInstance{}
      |> Oli.InstructorDashboard.Recommendations.RecommendationInstance.changeset(%{
        section_id: section.id,
        container_type: :course,
        generation_mode: :implicit,
        state: :generating,
        message: nil,
        prompt_version: "recommendation_prompt_v1",
        prompt_snapshot: %{}
      })
      |> Repo.insert()

    stale_inserted_at = DateTime.add(DateTime.utc_now(), -301, :second)

    from(
      ri in Oli.InstructorDashboard.Recommendations.RecommendationInstance,
      where: ri.id == ^generating.id
    )
    |> Repo.update_all(set: [inserted_at: stale_inserted_at, updated_at: stale_inserted_at])

    assert {:ok, fresh} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_ok/3
             )

    expired =
      Repo.get!(Oli.InstructorDashboard.Recommendations.RecommendationInstance, generating.id)

    assert expired.state == :expired
    assert fresh.state == :ready
    assert fresh.id != generating.id
  end

  test "persists deterministic no-signal payloads without calling completions", %{
    context: context,
    section: section
  } do
    Process.put(:recommendations_test_pid, self())
    snapshot_bundle = no_signal_snapshot_bundle_fixture(section.id)

    assert {:ok, recommendation} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_ok/3
             )

    assert recommendation.state == :no_signal
    assert recommendation.message =~ "there isn't enough student data"
    assert recommendation.metadata.fallback_reason == :no_signal
    refute_received :recommendation_generate_called
  end

  test "persists fallback payloads when provider execution fails", %{
    context: context,
    section: section
  } do
    Process.put(:recommendations_test_pid, self())
    snapshot_bundle = snapshot_bundle_fixture(section.id)

    assert {:ok, recommendation} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_fail/3
             )

    assert recommendation.state == :fallback
    assert recommendation.metadata.fallback_reason == :provider_failure

    latest = Recommendations.latest_instance(section.id, context.scope)
    assert latest.state == :fallback
  end

  test "submits thumbs feedback idempotently and exposes it in subsequent reads", %{
    context: context,
    section: section
  } do
    Process.put(:recommendations_test_pid, self())
    snapshot_bundle = snapshot_bundle_fixture(section.id)

    assert {:ok, recommendation} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_ok/3
             )

    assert {:ok, feedback} =
             Recommendations.submit_feedback(context, recommendation.id, %{
               feedback_type: :thumbs_up
             })

    assert feedback.feedback_type == :thumbs_up

    assert {:ok, same_feedback} =
             Recommendations.submit_feedback(context, recommendation.id, %{
               "feedback_type" => "thumbs_up"
             })

    assert same_feedback.id == feedback.id

    assert {:ok, reread} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_ok/3
             )

    assert reread.id == recommendation.id

    assert reread.feedback_summary == %{
             sentiment_submitted?: true,
             sentiment: :thumbs_up,
             additional_feedback_submitted?: false
           }
  end

  test "exposes persisted additional feedback state in subsequent reads", %{
    context: context,
    section: section
  } do
    Process.put(:recommendations_test_pid, self())
    snapshot_bundle = snapshot_bundle_fixture(section.id)

    assert {:ok, recommendation} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_ok/3
             )

    assert {:ok, _feedback} =
             Recommendations.submit_feedback(context, recommendation.id, %{
               feedback_type: :thumbs_up
             })

    assert {:ok, _feedback} =
             Recommendations.submit_feedback(context, recommendation.id, %{
               feedback_type: :additional_text,
               feedback_text: "Needs more concrete next steps."
             })

    assert {:ok, reread} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_ok/3
             )

    assert reread.feedback_summary == %{
             sentiment_submitted?: true,
             sentiment: :thumbs_up,
             additional_feedback_submitted?: true
           }
  end

  test "enrich_feedback_for_viewer/2 is nil-safe" do
    assert Recommendations.enrich_feedback_for_viewer(nil, 1) == nil
  end

  test "rejects conflicting duplicate thumbs submissions for the same recommendation", %{
    context: context,
    section: section
  } do
    Process.put(:recommendations_test_pid, self())
    snapshot_bundle = snapshot_bundle_fixture(section.id)

    assert {:ok, recommendation} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_ok/3
             )

    assert {:ok, _feedback} =
             Recommendations.submit_feedback(context, recommendation.id, %{
               feedback_type: :thumbs_up
             })

    assert {:error, {:sentiment_already_submitted, :thumbs_up}} =
             Recommendations.submit_feedback(context, recommendation.id, %{
               feedback_type: :thumbs_down
             })
  end

  test "rejects snapshot-backed recommendation generation for users without instructor access", %{
    section: section
  } do
    outsider = insert(:user)

    {:ok, outsider_context} =
      OracleContext.new(%{
        dashboard_context_type: :section,
        dashboard_context_id: section.id,
        user_id: outsider.id,
        scope: %{container_type: :course, container_id: nil}
      })

    assert {:error, {:unauthorized_scope, :section_access_denied}} =
             Recommendations.get_recommendation(outsider_context)
  end

  test "rejects feedback submissions for users without instructor access", %{
    context: context,
    section: section
  } do
    Process.put(:recommendations_test_pid, self())
    snapshot_bundle = snapshot_bundle_fixture(section.id)
    outsider = insert(:user)

    {:ok, outsider_context} =
      OracleContext.new(%{
        dashboard_context_type: :section,
        dashboard_context_id: section.id,
        user_id: outsider.id,
        scope: %{container_type: :course, container_id: nil}
      })

    assert {:ok, recommendation} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_ok/3
             )

    assert {:error, :section_access_denied} =
             Recommendations.submit_feedback(outsider_context, recommendation.id, %{
               feedback_type: :thumbs_up
             })
  end

  test "submits additional feedback and keeps success semantics when Slack fails", %{
    context: context
  } do
    Process.put(:recommendations_test_pid, self())
    snapshot_bundle = snapshot_bundle_fixture(context.dashboard_context_id)

    assert {:ok, recommendation} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_ok/3
             )

    assert {:ok, _thumbs} =
             Recommendations.submit_feedback(context, recommendation.id, %{
               feedback_type: :thumbs_up
             })

    parent = self()

    assert capture_log(fn ->
             assert {:ok, feedback} =
                      Recommendations.submit_additional_feedback(
                        context,
                        recommendation.id,
                        "This is too generic.",
                        slack_fun: fn payload ->
                          send(parent, {:slack_payload, payload})
                          {:error, :timeout}
                        end
                      )

             assert feedback.feedback_type == :additional_text
           end) =~ "Failed to send recommendation feedback to Slack"

    assert_receive {:slack_payload, payload}
    assert inspect(payload) =~ "A new custom feedback has been captured."
    refute inspect(payload) =~ "This is too generic."
    refute inspect(payload) =~ "Recommendation ID"
    refute inspect(payload) =~ Integer.to_string(recommendation.id)

    feedback_rows =
      from(rf in Oli.InstructorDashboard.Recommendations.RecommendationFeedback,
        where:
          rf.recommendation_instance_id == ^recommendation.id and rf.user_id == ^context.user_id
      )
      |> Repo.all()

    assert Enum.any?(feedback_rows, &(&1.feedback_type == :additional_text))
  end

  test "rejects blank additional feedback at the recommendations boundary", %{context: context} do
    Process.put(:recommendations_test_pid, self())
    snapshot_bundle = snapshot_bundle_fixture(context.dashboard_context_id)

    assert {:ok, recommendation} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_ok/3
             )

    assert {:error, :invalid_feedback} =
             Recommendations.submit_additional_feedback(context, recommendation.id, "   ")
  end

  test "explicit regeneration refreshes in-process and revisit cache payloads", %{
    context: context,
    section: section
  } do
    Process.put(:recommendations_test_pid, self())
    snapshot_bundle = snapshot_bundle_fixture(section.id)
    inprocess_store = start_supervised!({InProcessStore, enrollment_count: 100})
    revisit_cache = start_supervised!({RevisitCache, []})

    cache_opts = [
      inprocess_store: inprocess_store,
      revisit_cache: revisit_cache,
      revisit_eligible: true,
      key_meta: %{oracle_version: 1, data_version: 1}
    ]

    assert {:ok, implicit} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_ok/3
             )

    assert {:ok, regenerated} =
             Recommendations.regenerate_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_alt/3,
               inprocess_store: inprocess_store,
               revisit_cache: revisit_cache
             )

    assert regenerated.id != implicit.id
    assert regenerated.message =~ "Quiz 1 immediately"

    assert {:ok, required_lookup} =
             Cache.lookup_required(
               context,
               context.scope,
               [:oracle_instructor_recommendation],
               cache_opts
             )

    assert required_lookup.hits.oracle_instructor_recommendation.id == regenerated.id

    assert {:ok, revisit_lookup} =
             Cache.lookup_revisit(
               context.user_id,
               context,
               context.scope,
               [:oracle_instructor_recommendation],
               cache_opts
             )

    assert revisit_lookup.hits.oracle_instructor_recommendation.id == regenerated.id
  end

  test "explicit regeneration still succeeds when cache refresh paths are unavailable", %{
    context: context,
    section: section
  } do
    Process.put(:recommendations_test_pid, self())
    snapshot_bundle = snapshot_bundle_fixture(section.id)
    inprocess_store = start_supervised!({InProcessStore, enrollment_count: 100})
    revisit_cache = start_supervised!({RevisitCache, []})

    Process.exit(inprocess_store, :kill)
    Process.exit(revisit_cache, :kill)

    assert {:ok, recommendation} =
             Recommendations.regenerate_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_alt/3,
               inprocess_store: inprocess_store,
               revisit_cache: revisit_cache
             )

    assert recommendation.generation_mode == :explicit_regen

    latest = Recommendations.latest_instance(section.id, context.scope)
    assert latest.id == recommendation.id
    assert latest.message =~ "Quiz 1 immediately"
  end

  test "emits sanitized lifecycle telemetry for generation, reuse, and feedback submission", %{
    context: context,
    section: section
  } do
    Process.put(:recommendations_test_pid, self())
    snapshot_bundle = snapshot_bundle_fixture(section.id)
    handler = attach_telemetry([@lifecycle_event])

    assert {:ok, recommendation} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_ok/3
             )

    assert_receive {:telemetry_event, @lifecycle_event, %{count: 1, duration_ms: started_ms},
                    started_meta}

    assert is_integer(started_ms)
    assert started_meta.action == :implicit_generate
    assert started_meta.outcome == :started

    assert_receive {:telemetry_event, @lifecycle_event, %{count: 1, duration_ms: duration_ms},
                    generate_meta}

    assert is_integer(duration_ms)
    assert duration_ms >= 0
    assert generate_meta.action == :implicit_generate
    assert generate_meta.outcome == :generated
    assert generate_meta.rate_limit == :miss
    assert generate_meta.container_type == :course
    assert generate_meta.cache_refresh == :skipped
    refute Map.has_key?(generate_meta, :user_id)
    refute Map.has_key?(generate_meta, :section_id)
    refute Map.has_key?(generate_meta, :container_id)
    refute Map.has_key?(generate_meta, :message)

    assert {:ok, _same_recommendation} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_ok/3
             )

    assert_receive {:telemetry_event, @lifecycle_event, %{count: 1, duration_ms: reuse_ms},
                    reuse_meta}

    assert is_integer(reuse_ms)
    assert reuse_meta.action == :implicit_read
    assert reuse_meta.outcome == :reused
    assert reuse_meta.rate_limit == :hit
    assert reuse_meta.cache_refresh == :skipped

    assert {:ok, _feedback} =
             Recommendations.submit_feedback(context, recommendation.id, %{
               "feedback_type" => "thumbs_up"
             })

    assert_receive {:telemetry_event, @lifecycle_event, %{count: 1, duration_ms: feedback_ms},
                    feedback_meta}

    assert is_integer(feedback_ms)
    assert feedback_meta.action == :feedback_submit
    assert feedback_meta.outcome == :accepted
    assert feedback_meta.feedback_type == :thumbs_up
    refute Map.has_key?(feedback_meta, :user_id)
    refute Map.has_key?(feedback_meta, :section_id)
    refute Map.has_key?(feedback_meta, :container_id)
    refute Map.has_key?(feedback_meta, :prompt_snapshot)

    :telemetry.detach(handler)
  end

  test "emits fallback lifecycle telemetry without raw provider or prompt content", %{
    context: context,
    section: section
  } do
    Process.put(:recommendations_test_pid, self())
    snapshot_bundle = snapshot_bundle_fixture(section.id)
    handler = attach_telemetry([@lifecycle_event])

    assert {:ok, _recommendation} =
             Recommendations.get_recommendation(context,
               snapshot_bundle: snapshot_bundle,
               execution_fun: &__MODULE__.execution_fail/3
             )

    assert_receive {:telemetry_event, @lifecycle_event, %{count: 1, duration_ms: started_ms},
                    started_meta}

    assert is_integer(started_ms)
    assert started_meta.action == :implicit_generate
    assert started_meta.outcome == :started

    assert_receive {:telemetry_event, @lifecycle_event, %{count: 1, duration_ms: duration_ms},
                    metadata}

    assert is_integer(duration_ms)
    assert metadata.action == :implicit_generate
    assert metadata.outcome == :fallback
    assert metadata.fallback_reason == :provider_failure
    assert metadata.cache_refresh == :skipped
    refute Map.has_key?(metadata, :provider_response)
    refute Map.has_key?(metadata, :prompt_snapshot)
    refute Map.has_key?(metadata, :message)

    :telemetry.detach(handler)
  end

  defp snapshot_bundle_fixture(section_id) do
    %{snapshot: snapshot_fixture(section_id)}
  end

  defp no_signal_snapshot_bundle_fixture(section_id) do
    %{snapshot: no_signal_snapshot_fixture(section_id)}
  end

  defp snapshot_fixture(section_id) do
    {:ok, snapshot} =
      Contract.new_snapshot(%{
        request_token: "token-recommendations-#{section_id}",
        context: %{
          dashboard_context_type: :section,
          dashboard_context_id: section_id,
          user_id: 88,
          scope: %{container_type: :course, container_id: nil}
        },
        metadata: %{timezone: "UTC"},
        oracles: %{
          oracle_instructor_progress_bins: %{
            total_students: 10,
            by_resource_bins: %{
              777 => %{0 => 1, 100 => 9},
              42 => %{0 => 2, 100 => 8}
            }
          },
          oracle_instructor_scope_resources: %{
            course_title: "Intro to Testing",
            scope_label: "Entire Course",
            items: [
              %{
                resource_id: 777,
                resource_type_id: ResourceType.id_for_container(),
                title: "Module 7"
              },
              %{
                resource_id: 42,
                resource_type_id: ResourceType.id_for_page(),
                title: "Quiz 1",
                context_label: "Module 1"
              }
            ]
          },
          oracle_instructor_progress_proficiency: [
            %{student_id: 1, progress_pct: 25.0, proficiency_pct: 30.0},
            %{student_id: 2, progress_pct: 88.0, proficiency_pct: 91.0}
          ],
          oracle_instructor_student_info: [
            %{
              student_id: 1,
              email: "ada@example.edu",
              given_name: "Ada",
              family_name: "Lovelace",
              last_interaction_at: ~U[2026-03-12 00:00:00Z]
            },
            %{
              student_id: 2,
              email: "grace@example.edu",
              given_name: "Grace",
              family_name: "Hopper",
              last_interaction_at: ~U[2026-03-15 00:00:00Z]
            }
          ],
          oracle_instructor_grades: %{
            grades: [
              %{
                page_id: 42,
                title: "Quiz 1",
                mean: 72.5,
                histogram: %{"70-80" => 1},
                completed_count: 8,
                total_students: 10
              }
            ]
          }
        },
        oracle_statuses: %{
          oracle_instructor_progress_bins: %{status: :ready},
          oracle_instructor_scope_resources: %{status: :ready},
          oracle_instructor_progress_proficiency: %{status: :ready},
          oracle_instructor_student_info: %{status: :ready},
          oracle_instructor_grades: %{status: :ready}
        }
      })

    snapshot
  end

  defp no_signal_snapshot_fixture(section_id) do
    {:ok, snapshot} =
      Contract.new_snapshot(%{
        request_token: "token-recommendations-no-signal-#{section_id}",
        context: %{
          dashboard_context_type: :section,
          dashboard_context_id: section_id,
          user_id: 88,
          scope: %{container_type: :course, container_id: nil}
        },
        metadata: %{timezone: "UTC"},
        oracles: %{
          oracle_instructor_progress_bins: %{total_students: 0, by_resource_bins: %{}},
          oracle_instructor_scope_resources: %{
            course_title: "Intro to Testing",
            scope_label: "Entire Course",
            items: []
          },
          oracle_instructor_progress_proficiency: [],
          oracle_instructor_student_info: [],
          oracle_instructor_grades: %{grades: []}
        },
        oracle_statuses: %{
          oracle_instructor_progress_bins: %{status: :ready},
          oracle_instructor_scope_resources: %{status: :ready},
          oracle_instructor_progress_proficiency: %{status: :ready},
          oracle_instructor_student_info: %{status: :ready},
          oracle_instructor_grades: %{status: :ready}
        }
      })

    snapshot
  end

  def execution_ok(_request_ctx, _messages, _service_config) do
    send(Process.get(:recommendations_test_pid), :recommendation_generate_called)

    {:ok,
     "Inference: Students are progressing unevenly through the scoped content; review Quiz 1 and reinforce the linked concepts."}
  end

  def execution_fail(_request_ctx, _messages, _service_config) do
    send(Process.get(:recommendations_test_pid), :recommendation_generate_called)
    {:error, {:http_error, 500}}
  end

  def execution_alt(_request_ctx, _messages, _service_config) do
    send(Process.get(:recommendations_test_pid), :recommendation_generate_called)

    {:ok,
     "Inference: Assessment performance in Quiz 1 is lagging behind progress through the scoped content; review Quiz 1 immediately and reinforce the related concepts."}
  end

  def execution_with_metadata(_request_ctx, _messages, _service_config) do
    send(Process.get(:recommendations_test_pid), :recommendation_generate_called)

    {:ok,
     %{
       content:
         "Inference: Students are progressing unevenly through the scoped content; review Quiz 1 and reinforce the linked concepts.",
       metadata: %{
         model: "gpt-4.1",
         provider: "openai",
         registered_model_id: 12,
         service_config_id: 7,
         provider_usage: %{tokens: 123}
       }
     }}
  end

  defp attach_telemetry(events) do
    handler_id = "recommendations-telemetry-test-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach_many(
        handler_id,
        events,
        fn event_name, measurements, metadata, _config ->
          send(parent, {:telemetry_event, event_name, measurements, metadata})
        end,
        %{}
      )

    handler_id
  end
end
