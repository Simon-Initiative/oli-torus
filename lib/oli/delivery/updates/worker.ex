defmodule Oli.Delivery.Updates.Worker do
  @moduledoc """
  An Oban driven update worker
  """
  use Oban.Worker, queue: :updates, max_attempts: 3

  alias Oli.Delivery.Sections

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"section_slug" => section_slug, "publication_id" => publication_id}
      }) do
    section = Sections.get_section_by_slug(section_slug)

    Sections.apply_publication_update(
      section,
      publication_id
    )
  end
end
