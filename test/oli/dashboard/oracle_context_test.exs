defmodule Oli.Dashboard.OracleContextTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.OracleContext

  describe "new/1" do
    test "builds immutable context with normalized scope" do
      assert {:ok, context} =
               OracleContext.new(%{
                 dashboard_context_type: :section,
                 dashboard_context_id: 123,
                 user_id: 456,
                 scope: %{container_type: :container, container_id: 789},
                 request_id: "req-1"
               })

      assert context.dashboard_context_type == :section
      assert context.dashboard_context_id == 123
      assert context.user_id == 456
      assert context.scope.container_type == :container
      assert context.scope.container_id == 789
      assert context.request_id == "req-1"
    end

    test "rejects unknown fields deterministically" do
      assert {:error, {:invalid_oracle_context, {:unknown_fields, [":extra"]}}} =
               OracleContext.new(%{
                 dashboard_context_type: :section,
                 dashboard_context_id: 1,
                 user_id: 2,
                 extra: :field
               })
    end

    test "rejects invalid ids" do
      assert {:error, {:invalid_oracle_context, {:invalid_positive_integer, :user_id, "abc"}}} =
               OracleContext.new(%{
                 dashboard_context_type: :section,
                 dashboard_context_id: 1,
                 user_id: "abc"
               })
    end
  end

  describe "with_scope/2 and to_metadata/1" do
    test "replaces scope and serializes metadata" do
      {:ok, context} =
        OracleContext.new(%{
          dashboard_context_type: :section,
          dashboard_context_id: 10,
          user_id: 20,
          request_id: "req-2"
        })

      updated =
        OracleContext.with_scope(context, %{container_type: :container, container_id: 30})

      metadata = OracleContext.to_metadata(updated)

      assert metadata.dashboard_context_type == :section
      assert metadata.dashboard_context_id == 10
      assert metadata.user_id == 20
      assert metadata.scope == {:container, 30}
      assert metadata.request_id == "req-2"
    end
  end
end
