defmodule Oli.Dashboard.ScopeTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Scope

  describe "new/1" do
    test "defaults to course scope" do
      assert {:ok, %Scope{container_type: :course, container_id: nil}} = Scope.new(%{})
    end

    test "normalizes container scope from type and id fields" do
      assert {:ok, %Scope{container_type: :container, container_id: 42}} =
               Scope.new(%{container_type: "container", container_id: "42"})
    end

    test "accepts selector tuple syntax" do
      assert {:ok, %Scope{container_type: :container, container_id: 7}} =
               Scope.new(%{container: {:container, 7}})
    end

    test "returns deterministic error for unknown fields" do
      assert {:error, {:invalid_scope, {:unknown_fields, [":unexpected"]}}} =
               Scope.new(%{unexpected: :value})
    end

    test "returns deterministic error for unsupported container type" do
      assert {:error, {:invalid_scope, {:unsupported_container_type, "unit"}}} =
               Scope.new(%{container_type: "unit"})
    end

    test "returns deterministic error for invalid container id" do
      assert {:error, {:invalid_scope, {:invalid_container_id, "abc"}}} =
               Scope.new(%{container_type: :container, container_id: "abc"})
    end
  end

  describe "helpers" do
    test "normalize/1 always clears container id for course scope" do
      normalized = Scope.normalize(%Scope{container_type: :course, container_id: 999})

      assert normalized == %Scope{container_type: :course, container_id: nil}
    end

    test "container_key/1 and course_scope?/1 reflect canonical scope" do
      {:ok, course_scope} = Scope.new(%{})
      {:ok, container_scope} = Scope.new(%{container_type: :container, container_id: 17})

      assert Scope.container_key(course_scope) == {:course, nil}
      assert Scope.container_key(container_scope) == {:container, 17}
      assert Scope.course_scope?(course_scope)
      refute Scope.course_scope?(container_scope)
    end
  end
end
