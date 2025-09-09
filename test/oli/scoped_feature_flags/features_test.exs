defmodule Oli.ScopedFeatureFlags.FeaturesTest do
  use ExUnit.Case

  alias Oli.ScopedFeatureFlags.Features

  describe "feature definition macro" do
    defmodule TestFeatures do
      use Features

      deffeature(:test_feature, [:authoring], "Test feature description")
      deffeature(:another_feature, [:delivery], "Another test feature")
      deffeature(:both_feature, [:both], "Feature for both contexts")
    end

    test "all_features/0 returns all defined features" do
      features = TestFeatures.all_features()

      assert length(features) == 3

      feature_names = Enum.map(features, & &1.name)
      assert :test_feature in feature_names
      assert :another_feature in feature_names
      assert :both_feature in feature_names
    end

    test "feature_names/0 returns feature names as atoms" do
      names = TestFeatures.feature_names()

      assert :test_feature in names
      assert :another_feature in names
      assert :both_feature in names
    end

    test "feature_strings/0 returns feature names as strings" do
      strings = TestFeatures.feature_strings()

      assert "test_feature" in strings
      assert "another_feature" in strings
      assert "both_feature" in strings
    end

    test "valid_feature?/1 correctly identifies valid features" do
      assert TestFeatures.valid_feature?(:test_feature)
      assert TestFeatures.valid_feature?("test_feature")
      refute TestFeatures.valid_feature?(:undefined_feature)
      refute TestFeatures.valid_feature?("undefined_feature")
    end

    test "get_feature/1 returns feature metadata" do
      feature = TestFeatures.get_feature(:test_feature)

      assert feature.name == :test_feature
      assert feature.scopes == [:authoring]
      assert feature.description == "Test feature description"
      assert feature.string_name == "test_feature"
    end

    test "get_feature/1 returns nil for undefined feature" do
      assert TestFeatures.get_feature(:undefined) == nil
      assert TestFeatures.get_feature("undefined") == nil
    end

    test "feature_supports_scope?/2 correctly validates scopes" do
      assert TestFeatures.feature_supports_scope?(:test_feature, :authoring)
      refute TestFeatures.feature_supports_scope?(:test_feature, :delivery)

      assert TestFeatures.feature_supports_scope?(:another_feature, :delivery)
      refute TestFeatures.feature_supports_scope?(:another_feature, :authoring)

      assert TestFeatures.feature_supports_scope?(:both_feature, :authoring)
      assert TestFeatures.feature_supports_scope?(:both_feature, :delivery)
    end

    test "features_for_scope/1 returns features for specific scope" do
      authoring_features = TestFeatures.features_for_scope(:authoring)
      delivery_features = TestFeatures.features_for_scope(:delivery)

      authoring_names = Enum.map(authoring_features, & &1.name)
      delivery_names = Enum.map(delivery_features, & &1.name)

      assert :test_feature in authoring_names
      assert :both_feature in authoring_names
      refute :another_feature in authoring_names

      assert :another_feature in delivery_names
      assert :both_feature in delivery_names
      refute :test_feature in delivery_names
    end
  end

  describe "compile-time validation" do
    test "validates feature names" do
      assert_raise CompileError, ~r/Feature name must be an atom/, fn ->
        Code.eval_quoted(
          quote do
            defmodule InvalidNameType do
              use Oli.ScopedFeatureFlags.Features
              deffeature("string_name", [:authoring], "Description")
            end
          end
        )
      end
    end

    test "validates scopes" do
      assert_raise CompileError, ~r/Invalid scope/, fn ->
        Code.eval_quoted(
          quote do
            defmodule InvalidScope do
              use Oli.ScopedFeatureFlags.Features
              deffeature(:test, [:invalid_scope], "Description")
            end
          end
        )
      end
    end

    test "validates description" do
      assert_raise CompileError, ~r/Description must be a string/, fn ->
        Code.eval_quoted(
          quote do
            defmodule InvalidDescription do
              use Oli.ScopedFeatureFlags.Features
              deffeature(:test, [:authoring], :atom_description)
            end
          end
        )
      end
    end

    test "prevents duplicate feature names" do
      assert_raise CompileError, ~r/Duplicate feature names/, fn ->
        Code.eval_quoted(
          quote do
            defmodule DuplicateFeatures do
              use Oli.ScopedFeatureFlags.Features
              deffeature(:duplicate, [:authoring], "First")
              deffeature(:duplicate, [:delivery], "Second")
            end
          end
        )
      end
    end

    test "prevents conflicting scopes with :both" do
      assert_raise CompileError, ~r/Cannot use :both scope with other scopes/, fn ->
        Code.eval_quoted(
          quote do
            defmodule ConflictingScopes do
              use Oli.ScopedFeatureFlags.Features
              deffeature(:test, [:both, :authoring], "Description")
            end
          end
        )
      end
    end
  end

  describe "validation functions" do
    test "validate_feature_name!/1" do
      assert Features.validate_feature_name!(:valid_name) == :ok

      assert_raise CompileError, fn ->
        Features.validate_feature_name!("string_name")
      end

      assert_raise CompileError, fn ->
        Features.validate_feature_name!(:"")
      end

      # Note: We can't test extremely long atom names (>255 chars) because Erlang 
      # has its own atom size limits that would raise SystemLimitError before 
      # our validation runs

      assert_raise CompileError, fn ->
        Features.validate_feature_name!(:"invalid name with spaces")
      end
    end

    test "validate_scopes!/1" do
      assert Features.validate_scopes!([:authoring]) == :ok
      assert Features.validate_scopes!([:delivery]) == :ok
      assert Features.validate_scopes!([:both]) == :ok
      assert Features.validate_scopes!([:authoring, :delivery]) == :ok

      assert_raise CompileError, fn ->
        Features.validate_scopes!([])
      end

      assert_raise CompileError, fn ->
        Features.validate_scopes!([:invalid])
      end

      assert_raise CompileError, fn ->
        Features.validate_scopes!([:both, :authoring])
      end
    end

    test "validate_description!/1" do
      assert Features.validate_description!("Valid description") == :ok

      assert_raise CompileError, fn ->
        Features.validate_description!(:atom)
      end

      assert_raise CompileError, fn ->
        Features.validate_description!("")
      end

      long_description = String.duplicate("a", 501)

      assert_raise CompileError, fn ->
        Features.validate_description!(long_description)
      end
    end
  end
end
