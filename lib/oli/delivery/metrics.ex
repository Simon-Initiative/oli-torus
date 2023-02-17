defmodule Oli.Delivery.Metrics do

  import Ecto.Query, warn: false

  alias Oli.Repo

  alias Oli.Delivery.Sections.ContainedPage
  alias Oli.Delivery.Attempts.Core.{ResourceAccess}

  @doc """
  Calculate the progress for a specific student, in all pages of a
  specific container.

  Ommitting the container_id (or specifying nil) calculates progress
  across the entire course section.

  This query leverages the `contained_pages` relation, which is always an
  up to date view of the structure of a course section. This allows this
  query to take into account structural chagnes as the result of course
  remix. The `contained_pages` relation is rebuilt after every remix.
  """
  def progress_for(section_id, user_id, container_id \\ nil) do

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



end
