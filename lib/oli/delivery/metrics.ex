defmodule Oli.Delivery.Metrics do

  import Ecto.Query, warn: false

  alias Oli.Repo

  alias Oli.Delivery.Sections.ContainedPage
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Attempts.Core.{ResourceAccess, ResourceAttempt, ActivityAttempt}

  def progress_for(section_id, container_id, user_id) do

    filter_by_container =
      case container_id do
        nil ->
          dynamic([cp, _], is_nil(cp.container_id))

        _ ->
          dynamic([cp, _], cp.container_id == ^container_id)
      end

    query =
      ContainedPage
      |> join(:left, [cp], ra in ResourceAccess, on: cp.page_id == ra.resource_id and cp.section_id == ra.section_id and ra.user_id == ^user_id)
      |> where([cp, ra], cp.section_id == ^section_id)
      |> where(^filter_by_container)
      |> select([cp, ra], %{
        progress:
          fragment(
            "SUM(?) / COUNT(*)",
            ra.progress
          )
      })

   Repo.one(query).progress
  end

  def set_progress(section_id, resource_id, user_id, progress) do
    from(ra in ResourceAccess,
      where: ra.section_id == ^section_id and ra.resource_,
      update: [set: [progress: ^progress]])
    |> Repo.update_all([])
  end

end
