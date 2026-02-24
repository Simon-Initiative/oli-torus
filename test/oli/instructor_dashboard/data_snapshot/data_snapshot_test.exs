defmodule Oli.InstructorDashboard.DataSnapshotTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.LiveDataCoordinator
  alias Oli.Dashboard.Oracle.Result
  alias Oli.InstructorDashboard.DataSnapshot

  defmodule StubCache do
    def lookup_required(context, scope, required_oracles, opts) do
      lookup_fun = Keyword.fetch!(opts, :lookup_fun)
      lookup_fun.(context, scope, required_oracles)
    end

    def write_oracle(_context, _scope, _oracle_key, _payload, _meta, _opts), do: :ok
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
      coordinator_module: LiveDataCoordinator,
      cache_module: StubCache
    }
  end

  describe "get_or_build/2 orchestration" do
    test "builds deterministic bundle from cache-hit path", %{
      scope_request: scope_request,
      coordinator_module: coordinator_module,
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
                 coordinator_module: coordinator_module,
                 cache_module: cache_module,
                 cache_opts: [lookup_fun: lookup_fun],
                 dependency_profile: %{
                   required: [:oracle_instructor_progress],
                   optional: [:oracle_instructor_support]
                 }
               )

      assert is_binary(bundle.request_token)
      assert bundle.snapshot.oracles.oracle_instructor_progress == %{metric: :progress}
      assert bundle.snapshot.oracle_statuses.oracle_instructor_progress.status == :ready
      assert bundle.snapshot.oracle_statuses.oracle_instructor_support.status == :unavailable
      assert bundle.projection_statuses.progress.status == :ready
      assert is_binary(bundle.parity.fingerprint)
      assert "progress" in bundle.parity.projection_keys
    end

    # @ac "AC-001"
    test "builds deterministic bundle from cache-miss plus runtime oracle results", %{
      scope_request: scope_request,
      coordinator_module: coordinator_module,
      cache_module: cache_module
    } do
      lookup_fun = fn _context, _scope, required ->
        {:ok, %{hits: %{}, misses: required, source: :none}}
      end

      runtime_results = %{
        oracle_instructor_progress:
          Result.ok(:oracle_instructor_progress, %{metric: :progress_runtime}, version: 2),
        oracle_instructor_support:
          Result.ok(:oracle_instructor_support, %{metric: :support_runtime}, version: 1)
      }

      assert {:ok, bundle} =
               DataSnapshot.get_or_build(scope_request,
                 coordinator_module: coordinator_module,
                 cache_module: cache_module,
                 cache_opts: [lookup_fun: lookup_fun],
                 dependency_profile: %{
                   required: [:oracle_instructor_progress],
                   optional: [:oracle_instructor_support]
                 },
                 runtime_results: runtime_results
               )

      assert bundle.snapshot.oracles.oracle_instructor_progress == %{metric: :progress_runtime}
      assert bundle.snapshot.oracles.oracle_instructor_support == %{metric: :support_runtime}
      assert bundle.snapshot.oracle_statuses.oracle_instructor_progress.status == :ready
      assert bundle.projection_statuses.progress.status == :ready
      assert bundle.projection_statuses.student_support.status == :ready
      assert is_binary(bundle.parity.fingerprint)
      assert "progress" in bundle.parity.projection_keys
      assert "student_support" in bundle.parity.projection_keys
    end

    test "memoize hook reuses request-scoped bundle without re-running runtime provider", %{
      scope_request: scope_request,
      coordinator_module: coordinator_module,
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
        coordinator_module: coordinator_module,
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
      assert first_bundle.parity.fingerprint == second_bundle.parity.fingerprint
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
      coordinator_module: coordinator_module,
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
                 coordinator_module: coordinator_module,
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
