defmodule OliWeb.Delivery.RebuildFullHierarchyWorker do
  @moduledoc """
  This worker is used to rebuild the full hierarchy of a section in an async way,
  since the process can take a long time.
  """
  use Oban.Worker,
    queue: :rebuild_full_hierarchy,
    max_attempts: 2

  alias Oli.Delivery.Sections

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"section_slug" => section_slug} = _args}) do
    Sections.get_section_by_slug(section_slug)
    |> Sections.rebuild_full_hierarchy()
  end
end
