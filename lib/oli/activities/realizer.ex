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
  alias Oli.Activities.Realizer.Query.Source

  def realize(%Revision{content: content}, %Source{} = source) do
    Oli.Resources.PageContent.flat_filter(content, fn %{"type" => type} ->
      type == "activity-reference"
    end)
    |> Enum.map(fn %{"activity_id" => id} -> id end)
  end
end
