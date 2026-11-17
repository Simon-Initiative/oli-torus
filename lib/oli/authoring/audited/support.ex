defmodule Oli.Authoring.Audited.Support do
  @moduledoc false
  # Event recording shared by the private modules of `Oli.Authoring.Audited`.

  alias Oli.Auditing

  @doc "Builds the event from `proposal` and inserts it in the current transaction."
  def record(context, proposal) do
    with {:ok, changeset} <- Auditing.build(context, proposal),
         {:ok, _event} <- Auditing.insert(changeset) do
      :ok
    end
  end
end
