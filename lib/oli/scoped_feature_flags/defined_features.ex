defmodule Oli.ScopedFeatureFlags.DefinedFeatures do
  @moduledoc """
  Centralized definition of all scoped feature flags in the OLI Torus system.

  This module defines all available feature flags using compile-time macros.
  Features defined here are validated at compile time and can be safely used
  throughout the system.

  ## Adding New Features

  To add a new feature flag:

  1. Add a `deffeature` call with appropriate metadata
  2. Ensure the feature name follows naming conventions (snake_case, alphanumeric + _ - .)
  3. Specify the correct scopes based on where the feature will be used
  4. Provide a clear, descriptive description

  ## Feature Scopes

  - `:authoring` - Feature affects authoring/project context (e.g., course creation, content editing)
  - `:delivery` - Feature affects delivery/section context (e.g., student experience, instruction)
  - `:both` - Feature affects both authoring and delivery contexts

  ## Examples

      deffeature :mcp_authoring, [:authoring], "Enable MCP authoring capabilities"
      deffeature :advanced_analytics, [:both], "Advanced analytics dashboard for both contexts"
  """

  use Oli.ScopedFeatureFlags.Features

  deffeature(
    :mcp_authoring,
    [:authoring],
    "Enable Model Context Protocol (MCP) authoring capabilities for intelligent content creation and editing"
  )

  # Test-only features for comprehensive testing
  if Mix.env() in [:test] do
    deffeature(:feature1, [:both], "Test feature for both scopes")
    deffeature(:feature2, [:both], "Second test feature for both scopes")
    deffeature(:feature3, [:both], "Third test feature for both scopes")
    deffeature(:test_feature, [:both], "General test feature")
    deffeature(:valid_feature, [:both], "Valid test feature")
    deffeature(:z_feature, [:both], "Z test feature for ordering tests")
    deffeature(:a_feature, [:both], "A test feature for ordering tests")
    deffeature(:another_feature, [:both], "Another test feature")
    deffeature(:m_feature, [:both], "M test feature for ordering tests")
    deffeature(:test_delivery_feature, [:delivery], "Test feature for delivery scope only")
  end
end
