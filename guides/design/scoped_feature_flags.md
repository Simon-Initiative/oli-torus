# Scoped Feature Flags

## Overview

The Scoped Feature Flags system provides resource-specific feature toggles that can be enabled or disabled on a per-project or per-section basis. Unlike global system feature flags, scoped feature flags allow fine-grained control over features for specific authoring projects or delivery sections.

## Key Features

### Resource Scoping
- **Project-scoped features**: Enable/disable features for specific authoring projects
- **Section-scoped features**: Enable/disable features for specific course delivery sections
- **Mutual exclusivity**: Each feature flag instance belongs to either a project OR section, never both

### Compile-time Safety
- Features must be pre-defined using the `deffeature/3` macro
- Compile-time validation ensures only defined features can be used (when using atoms)
- Runtime validation for dynamic feature names

### Context-aware Definitions
Features are defined with scope constraints:
- `:authoring` - Can only be used with projects
- `:delivery` - Can only be used with sections  
- `:both` - Can be used with both projects and sections

### Audit Integration
All feature flag changes are automatically logged with:
- Actor identification (who made the change)
- Resource information (which project/section)
- Timestamp and action type
- Full audit trail for compliance

### Efficient Storage
Uses record presence/absence logic:
- **Enabled**: Record exists in database
- **Disabled**: No record exists
- No redundant boolean fields, optimized for storage and performance

## Developer Usage

### 1. Define Features

Add feature definitions in `lib/oli/scoped_feature_flags/defined_features.ex`:

```elixir
defmodule Oli.ScopedFeatureFlags.DefinedFeatures do
  use Oli.ScopedFeatureFlags.Features

  # Project-only feature
  deffeature :enhanced_editor, [:authoring], 
    "Advanced content editor with AI assistance"
  
  # Section-only feature  
  deffeature :adaptive_learning, [:delivery],
    "Personalized learning path adaptation"
    
  # Universal feature
  deffeature :collaboration_tools, [:both],
    "Real-time collaborative editing and review"
end
```

### 2. Check Feature Status

```elixir
alias Oli.ScopedFeatureFlags

# Check if feature is enabled for a project
if ScopedFeatureFlags.enabled?(:enhanced_editor, project) do
  # Feature-specific logic
end

# Check if feature is enabled for a section  
if ScopedFeatureFlags.enabled?(:adaptive_learning, section) do
  # Feature-specific logic
end

# Batch check multiple features
if ScopedFeatureFlags.batch_enabled?([:feature1, :feature2], project) do
  # All features are enabled
end
```

### 3. Enable/Disable Features

```elixir
# Enable feature (creates database record)
{:ok, _state} = ScopedFeatureFlags.enable_feature(:enhanced_editor, project, current_author)

# Disable feature (deletes database record)  
{:ok, _deleted} = ScopedFeatureFlags.disable_feature(:enhanced_editor, project, current_author)

# Batch operations
feature_settings = [
  {:enhanced_editor, true},
  {:collaboration_tools, false}
]
{:ok, _results} = ScopedFeatureFlags.set_features_atomically(feature_settings, project, current_author)
```

### 4. Admin Interface Integration

Features are automatically available in the admin interface at `/admin/features`:

- System administrators can toggle scoped features for any project/section
- Resource selection dropdowns for easy management
- All changes are automatically audited
- Real-time UI updates using Phoenix LiveView

### 5. Query Available Features

```elixir
# List all defined features with metadata
ScopedFeatureFlags.list_defined_features()
# Returns: [%{name: :enhanced_editor, scopes: [:authoring], description: "..."}, ...]

# Get features enabled for a resource
ScopedFeatureFlags.list_enabled_features(project)
# Returns: [:enhanced_editor, :collaboration_tools]
```

## AI/Agent Usage

For agentic AI coders, the system provides:

### Compile-time Validation
```elixir
# This will raise compile error if :undefined_feature is not defined
ScopedFeatureFlags.enabled?(:undefined_feature, project)
```

### Runtime Validation
```elixir
# Dynamic feature names are validated at runtime
feature_name = "user_provided_feature"
case ScopedFeatureFlags.enabled?(feature_name, project) do
  true -> # Feature enabled
  false -> # Feature disabled or undefined
end
```

### Error Handling
```elixir
case ScopedFeatureFlags.enable_feature(:some_feature, project, author) do
  {:ok, flag_state} -> 
    # Success
  {:error, %{feature_name: ["Feature 'some_feature' is not defined"]}} ->
    # Undefined feature error
  {:error, %{base: ["Feature 'some_feature' cannot be used in authoring context"]}} ->
    # Scope validation error
end
```

## Architecture Notes

### Database Schema
- **Table**: `scoped_feature_flag_states`
- **Fields**: `feature_name`, `project_id`, `section_id`, `inserted_at`, `updated_at`
- **Constraints**: Unique on `(feature_name, project_id)` and `(feature_name, section_id)`
- **Logic**: Record presence = enabled, absence = disabled

### Performance Considerations
- Efficient queries using existence checks
- Batch operations for multiple features
- Minimal database footprint (no boolean fields)
- Indexed unique constraints for fast lookups

### Integration Points
- **Contexts**: `Oli.ScopedFeatureFlags` (main API)
- **Schema**: `Oli.ScopedFeatureFlags.ScopedFeatureFlagState`  
- **Definitions**: `Oli.ScopedFeatureFlags.DefinedFeatures`
- **Admin UI**: `/admin/features` (Phoenix LiveView)
- **Auditing**: Automatic integration with `Oli.Auditing`

This system provides a robust, scalable foundation for feature management across the OLI Torus platform while maintaining safety, auditability, and performance.