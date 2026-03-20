defmodule Oli.InstructorDashboard.DataSnapshotTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Oracle.Result
  alias Oli.InstructorDashboard.DataSnapshot

  defmodule StubCache do
    def lookup_required(context, scope, required_oracles, opts) do
      lookup_fun = Keyword.fetch!(opts, :lookup_fun)
      lookup_fun.(context, scope, required_oracles)
    end

    def write_oracle(context, scope, oracle_key, payload, meta, opts) do
      case Keyword.get(opts, :write_fun) do
        write_fun when is_function(write_fun, 6) ->
          write_fun.(context, scope, oracle_key, payload, meta, opts)

        _ ->
          :ok
      end
    end
  end

  setup do
    scope_request = %{
      context: %{
        dashboard_context_type: :section,
        dashboard_context_id: 7001,
        user_id: 91,
        scope: %{container_type: :container, container_id: 301}
      },
      scope: %{container_type: :container, container_id: 301},
      metadata: %{timezone: "UTC"}
    }

    %{
      scope_request: scope_request,
      cache_module: StubCache
    }
  end

  describe "get_or_build/2 orchestration" do
    test "builds deterministic bundle from cache-hit path", %{
      scope_request: scope_request,
      cache_module: cache_module
    } do
      lookup_fun = fn _context, _scope, _required ->
        {:ok,
         %{
           hits: %{oracle_instructor_progress: %{metric: :progress}},
           misses: [],
           source: :inprocess
         }}
      end

      assert {:ok, bundle} =
               DataSnapshot.get_or_build(scope_request,
                 cache_module: cache_module,
                 cache_opts: [lookup_fun: lookup_fun],
                 dependency_profile: %{
                   required: [:oracle_instructor_progress],
                   optional: [
                     :oracle_instructor_progress_proficiency,
                     :oracle_instructor_student_info
                   ]
                 }
               )

      assert is_binary(bundle.request_token)
      assert bundle.snapshot.oracles.oracle_instructor_progress == %{metric: :progress}
      assert bundle.snapshot.oracle_statuses.oracle_instructor_progress.status == :ready

      assert bundle.snapshot.oracle_statuses.oracle_instructor_progress_proficiency.status ==
               :unavailable

      assert bundle.snapshot.oracle_statuses.oracle_instructor_student_info.status == :unavailable

      assert bundle.projection_statuses.progress.status == :ready
    end

    # @ac "AC-001"
    test "builds deterministic bundle from cache-miss plus runtime oracle results", %{
      scope_request: scope_request,
      cache_module: cache_module
    } do
      lookup_fun = fn _context, _scope, required ->
        {:ok, %{hits: %{}, misses: required, source: :none}}
      end

      runtime_results = %{
        oracle_instructor_progress:
          Result.ok(:oracle_instructor_progress, %{metric: :progress_runtime}, version: 2),
        oracle_instructor_progress_proficiency:
          Result.ok(
            :oracle_instructor_progress_proficiency,
            [%{student_id: 101, progress_pct: 20.0, proficiency_pct: 30.0}],
            version: 1
          ),
        oracle_instructor_student_info:
          Result.ok(
            :oracle_instructor_student_info,
            [
              %{
                student_id: 101,
                email: "ada@example.edu",
                given_name: "Ada",
                family_name: "Lovelace",
                last_interaction_at: ~U[2026-03-12 00:00:00Z]
              }
            ],
            version: 1
          )
      }

      assert {:ok, bundle} =
               DataSnapshot.get_or_build(scope_request,
                 cache_module: cache_module,
                 cache_opts: [lookup_fun: lookup_fun],
                 dependency_profile: %{
                   required: [
                     :oracle_instructor_progress,
                     :oracle_instructor_progress_proficiency,
                     :oracle_instructor_student_info
                   ],
                   optional: []
                 },
                 runtime_results: runtime_results
               )

      assert bundle.snapshot.oracles.oracle_instructor_progress == %{metric: :progress_runtime}

      assert bundle.snapshot.oracles.oracle_instructor_progress_proficiency == [
               %{student_id: 101, progress_pct: 20.0, proficiency_pct: 30.0}
             ]

      assert bundle.snapshot.oracles.oracle_instructor_student_info == [
               %{
                 student_id: 101,
                 email: "ada@example.edu",
                 given_name: "Ada",
                 family_name: "Lovelace",
                 last_interaction_at: ~U[2026-03-12 00:00:00Z]
               }
             ]

      assert bundle.snapshot.oracle_statuses.oracle_instructor_progress.status == :ready
      assert bundle.projection_statuses.progress.status == :ready
      assert bundle.projection_statuses.student_support.status == :ready
    end

    test "memoize hook reuses request-scoped bundle without re-running runtime provider", %{
      scope_request: scope_request,
      cache_module: cache_module
    } do
      lookup_fun = fn _context, _scope, required ->
        {:ok, %{hits: %{}, misses: required, source: :none}}
      end

      call_counter = start_supervised!({Agent, fn -> 0 end})

      provider = fn _request_token, misses, _context, _scope ->
        Agent.update(call_counter, &(&1 + 1))

        Map.new(misses, fn key ->
          {key, Result.ok(key, %{from: :runtime})}
        end)
      end

      opts = [
        cache_module: cache_module,
        cache_opts: [lookup_fun: lookup_fun],
        dependency_profile: %{required: [:oracle_instructor_progress], optional: []},
        runtime_results_provider: provider,
        memoize: true
      ]

      assert {:ok, first_bundle} = DataSnapshot.get_or_build(scope_request, opts)
      assert {:ok, second_bundle} = DataSnapshot.get_or_build(scope_request, opts)
      assert Agent.get(call_counter, & &1) == 1
      assert first_bundle.request_token == second_bundle.request_token
    end

    test "degrades to runtime path when cache lookup fails and writes ready results back", %{
      scope_request: scope_request,
      cache_module: cache_module
    } do
      write_sink = start_supervised!({Agent, fn -> [] end})

      lookup_fun = fn _context, _scope, _required ->
        {:error, :cache_down}
      end

      write_fun = fn _context, _scope, oracle_key, payload, meta, _opts ->
        Agent.update(write_sink, fn writes ->
          [%{oracle_key: oracle_key, payload: payload, meta: meta} | writes]
        end)

        :ok
      end

      runtime_results = %{
        oracle_instructor_progress:
          Result.ok(:oracle_instructor_progress, %{metric: :runtime_progress}, version: 2),
        oracle_instructor_support: Result.error(:oracle_instructor_support, :support_timeout)
      }

      assert {:ok, bundle} =
               DataSnapshot.get_or_build(scope_request,
                 cache_module: cache_module,
                 cache_opts: [lookup_fun: lookup_fun, write_fun: write_fun],
                 dependency_profile: %{
                   required: [:oracle_instructor_progress],
                   optional: [:oracle_instructor_support]
                 },
                 runtime_results: runtime_results
               )

      assert bundle.snapshot.oracles.oracle_instructor_progress == %{metric: :runtime_progress}
      assert bundle.snapshot.oracle_statuses.oracle_instructor_support.status == :failed

      writes = Agent.get(write_sink, & &1)
      assert length(writes) == 1

      assert [%{oracle_key: :oracle_instructor_progress, payload: %{metric: :runtime_progress}}] =
               writes

      assert hd(writes).meta.oracle_version == 2
      assert hd(writes).meta.dashboard_context_id == 7001
      assert hd(writes).meta.container_type == :container
      assert hd(writes).meta.container_id == 301
    end
  end

  describe "scope/authz enforcement" do
    test "returns deterministic unauthorized error when authz fails", %{
      scope_request: scope_request
    } do
      assert {:error, {:unauthorized_scope, :forbidden}} =
               DataSnapshot.get_or_build(scope_request,
                 authorize_fun: fn _context, _scope -> false end
               )
    end

    test "rejects scope/context mismatches for tenant isolation invariants" do
      scope_request = %{
        context: %{
          dashboard_context_type: :section,
          dashboard_context_id: 7001,
          user_id: 91,
          scope: %{container_type: :container, container_id: 301}
        },
        scope: %{container_type: :container, container_id: 999}
      }

      assert {:error, {:invalid_scope_request, {:scope_context_mismatch, _}}} =
               DataSnapshot.get_or_build(scope_request)
    end
  end

  describe "get_projection/3" do
    # @ac "AC-006"
    test "returns deterministic projection tuples for ready/partial/unavailable statuses", %{
      scope_request: scope_request,
      cache_module: cache_module
    } do
      lookup_fun = fn _context, _scope, required ->
        {:ok, %{hits: %{}, misses: required, source: :none}}
      end

      runtime_results = %{
        oracle_instructor_progress:
          Result.ok(:oracle_instructor_progress, %{metric: :progress_runtime})
      }

      assert {:ok, bundle} =
               DataSnapshot.get_or_build(scope_request,
                 cache_module: cache_module,
                 cache_opts: [lookup_fun: lookup_fun],
                 dependency_profile: %{required: [:oracle_instructor_progress], optional: []},
                 runtime_results: runtime_results
               )

      assert {:ok, _projection} = DataSnapshot.get_projection(bundle, :progress)

      assert {:error, {:projection_unavailable, :summary, :partial, :dependency_unavailable}} =
               DataSnapshot.get_projection(bundle, :summary, allow_partial: false)

      assert {:error, {:projection_unavailable, :missing_capability, :unavailable, nil}} =
               DataSnapshot.get_projection(bundle, :missing_capability)
    end
  end
end
