defmodule Oli.Repo.Migrations.GenerateSectionSlugs do
  use Ecto.Migration
  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections.Section
  alias Oli.Utils.Slug

  def change do
    # nothing to do
  end

  def up do
    # populate all section slugs that are null
    sections = Oli.Repo.all(
      from s in "sections",
      where: is_nil(s.slug),
      select: %{id: s.id, title: s.title}
    )

    Enum.each(sections, fn %{id: id, title: title} ->
      section = from s in "sections", where: s.id == ^id
      Oli.Repo.update_all section, set: [slug: Slug.generate("sections", title)]
    end)

    flush()

    # populate all section lti_1p3_deployment_ids that are null.
    #
    # We do our best here to automate this process since the information we need is missing,
    # however it may be the case that the latest deployment is not the correct deployment
    # for a section, in which case the database record will have to be updated manually.
    # This migration script assumes that the case of multiple deployments is minimal compared
    # to the most common case of an institution only having a single registration with a single deployment
    sections_deployments = Oli.Repo.all(
      from s in "sections",
      where: is_nil(s.lti_1p3_deployment_id),
      join: i in "institutions", on: i.id == s.institution_id,
      join: r in "lti_1p3_registrations", on: i.id == r.institution_id,
      join: d in "lti_1p3_deployments", on: r.id == d.registration_id,
      select: %{id: s.id, deployment_id: d.id}
    )

    sections_deployments
    # dedupe sections, keeping section with latest deployment_id
    |> Enum.reduce(%{}, fn s, acc -> Map.put(s.id, s.deployment_id) end)
    # persist
    |> Enum.each(fn {id, deployment_id} ->
      section = from s in "sections", where: s.id == ^id
      Oli.Repo.update_all section, set: [lti_1p3_deployment_id: deployment_id]
    end)
  end

end
