defmodule Oli.Accounts.Audited do
  @moduledoc """
  Application boundary for audited account commands.

  Internal mutation and replay modules are not exported to callers.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export Mutations or Replay.
  use Boundary, top_level?: true, exports: []
end
