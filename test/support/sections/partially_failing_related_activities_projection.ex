defmodule Oli.Test.Sections.PartiallyFailingRelatedActivitiesProjection do
  @moduledoc false

  import Ecto.Query

  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Repo

  def persist(section, _opts \\ []) do
    Repo.update_all(
      from(sr in SectionResource, where: sr.section_id == ^section.id),
      set: [related_activities: [-1]]
    )

    {:error, :forced_projection_failure_after_write}
  end
end
