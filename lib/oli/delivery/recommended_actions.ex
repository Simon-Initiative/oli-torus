defmodule Oli.Delivery.RecommendedActions do
  import Ecto.Query, warn: false

  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Attempts.Core.ResourceAccess

  alias Oli.Delivery.Sections.{
    Section,
    SectionResource,
    SectionResourceDepot,
    SectionsProjectsPublications
  }

  alias Oli.Delivery.Attempts.Core.ActivityAttempt
  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.Publishing.PublishedResource

  defp section_resource_query() do
    SectionResource
    |> join(:inner, [sr], s in Section, on: sr.section_id == s.id)
    |> join(:inner, [sr, s], spp in SectionsProjectsPublications,
      on: spp.section_id == s.id and spp.project_id == sr.project_id
    )
    |> join(:inner, [sr, _, spp], pr in PublishedResource,
      on: pr.publication_id == spp.publication_id and pr.resource_id == sr.resource_id
    )
  end

  def section_has_scheduled_resources?(section_id) do
    SectionResourceDepot.has_scheduled_resources?(section_id)
  end

  def section_scoring_pending_activities_count(section_id) do
    from(aa in ActivityAttempt,
      join: ra in ResourceAttempt,
      on: aa.resource_attempt_id == ra.id,
      join: r_acc in ResourceAccess,
      on: ra.resource_access_id == r_acc.id,
      where: aa.lifecycle_state == :submitted and r_acc.section_id == ^section_id,
      select: count(aa.id)
    )
    |> Repo.one()
  end

  def section_approval_pending_posts_count(section_id) do
    Oli.Resources.Collaboration.Post
    |> where([p], p.section_id == ^section_id and p.status == :submitted)
    |> select([p], count(p.id))
    |> Repo.one()
  end

  def section_has_pending_updates?(section_id),
    do:
      Oli.Delivery.Sections.check_for_available_publication_updates(
        %Oli.Delivery.Sections.Section{id: section_id}
      )
      |> Map.keys()
      |> length()
      |> Kernel.>(0)

  def section_has_due_soon_activities?(section_id) do
    section_resource_query()
    |> join(:inner, [sr, _, _, pr], rev in Revision, on: rev.id == pr.revision_id)
    |> where(
      [sr, s, _, _, rev],
      sr.section_id == ^section_id and
        rev.graded == true and
        sr.scheduling_type == :due_by and
        fragment(
          "now() < ? and ? < now() + interval '24 hours'",
          sr.end_date,
          sr.end_date
        )
    )
    |> select([sr], sr)
    |> limit(1)
    |> Repo.one()
    |> is_nil()
    |> Kernel.!()
  end
end
