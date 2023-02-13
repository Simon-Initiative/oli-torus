defmodule Oli.Delivery.Metrics do

  import Ecto.Query, warn: false

  alias Oli.Repo

  alias Oli.Delivery.Sections.ContainedPage
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Attempts.Core.{ResourceAccess, ResourceAttempt, ActivityAttempt}

  def progress_for(section_id, container_id, user_id) do

    # For all contained pages for this container
    # join through the SR record to get to the activity_count
    # join through the resource access and count the

    Repo.all(
      from(a in ResourceAccess,
        left_join: ra in ResourceAttempt,
        on: a.id == ra.resource_access_id,
        join: s in Section,
        on: a.section_id == s.id,
        where: a.user_id == ^user_id and s.slug == ^section_slug,
        group_by: a.id,
        select: a,
        select_merge: %{
          resource_attempts_count: count(ra.id)
        }
      )
    )

    # divide all by total contained page count

    query =
      ContainedPage
      |> join(:left, [cp], sr in SectionResource, on: cp.page_id == sr.id)
      |> join(:left, [cp, sr], ra in ResourceAccess,
        on: ra.resource_id == sr.resource_id and ra.user_id == ^user_id)
      |> join(:left, [cp, sr, ra], attempt in ResourceAttempt,
        on: ra.id == attempt.resource_id and ra.user_id == ^user_id)
      |> where(^filter_by_text)
      |> where(^filter_by_role)
      |> where([e, _], e.section_id == ^section_id)
      |> limit(^limit)
      |> offset(^offset)
      |> group_by([e, u, p], [e.id, u.id, p.id])
      |> select([_, u], u)
      |> select_merge([e, _, p], %{
        total_count: fragment("count(*) OVER()"),
        enrollment_date: e.inserted_at,
        payment_date: p.application_date,
        payment_id: p.id
      })

    query =
      case field do
        :enrollment_date -> order_by(query, [e, _, _], {^direction, e.inserted_at})
        :payment_date -> order_by(query, [_, _, p], {^direction, p.application_date})
        :payment_id -> order_by(query, [_, _, p], {^direction, p.id})
        _ -> order_by(query, [_, u, _], {^direction, field(u, ^field)})
      end

    Repo.all(query)


  end




end
