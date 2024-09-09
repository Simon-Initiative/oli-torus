defmodule Oli.Delivery.Updates.Worker do
  @moduledoc """
  An Oban driven update worker
  """
  use Oban.Worker, queue: :updates, max_attempts: 3

  alias Oli.Delivery.Sections.Updates

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"section_slug" => section_slug, "publication_id" => publication_id}
      }) do
    perform_now(section_slug, publication_id)
  end

  def perform_now(section_slug, publication_id) do
    section = Oli.Delivery.Sections.get_section_by_slug(section_slug)

    Updates.apply_publication_update(
      section,
      publication_id
    )
  end
end
