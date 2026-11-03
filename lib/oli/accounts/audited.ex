defmodule Oli.Accounts.Audited do
  @moduledoc """
  Application boundary for audited account commands.

  Internal mutation and replay modules are not exported to callers.
  """

  use Boundary, top_level?: true, exports: []
end
