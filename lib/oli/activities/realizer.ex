defmodule Oli.Activities.Realizer do
  @moduledoc """
  Realizes the activity instances from activity references from
  within a page.  This can simply involve resolving a revision, or
  involve fulfilling a pool, or drawing activities from a bank
  using criteria, etc.

  For now it simply resolves a revision for a specific referenced
  activity.
  """

  alias Oli.Resources.Revision

  def realize(%Revision{content: %{ "model" => model}}) do
    Enum.filter(model, fn %{"type" => type} -> type == "activity-reference" end)
    |> Enum.map(fn %{"activity_id" => id} -> id end)
  end

end
