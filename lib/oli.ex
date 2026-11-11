defmodule Oli do
  # Incoming legacy calls stay unrestricted. Never disable outgoing checks: they keep
  # the internals of audited boundaries private.
  use Boundary,
    deps: [
      Oli.Accounts.Audited,
      Oli.Groups.Audited,
      Oli.Institutions.Audited,
      Oli.Inventories.Audited,
      Oli.Lti.Audited
    ],
    check: [in: false]

  @moduledoc """
  Oli keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
end
