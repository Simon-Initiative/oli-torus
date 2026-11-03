defmodule Oli.Accounts.Audited do
  @moduledoc """
  Application boundary for audited account commands.

  The internal mutation module is not exported to callers.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export Mutations.
  use Boundary, top_level?: true, exports: []
end
