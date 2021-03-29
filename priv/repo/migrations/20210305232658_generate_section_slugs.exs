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
      from s in Section,
      where: is_nil(s.slug),
      select: s
    )

    Enum.each(sections, fn section ->
      section
      |> Section.changeset(%{})
      |> Slug.update_never("sections")
      |> Oli.Repo.update()
    end)

    flush()

    # populate all section lti_1p3_deployment_ids that are null.
    #
    # We do our best here to automate this process since the information we need is missing,
    # however it may be the case that the latest deployment is not the correct deployment
    # for a section, in which case the database record will have to be updated manually.
    # This migration script assumes that this case is minimal compared to the most common case
    # where an institution is only using a single registration with a single deployment
    sections = Oli.Repo.all(
      from s in Section,
      where: is_nil(s.lti_1p3_deployment_id),
      preload: [institution: [registrations: [:deployments]]],
      select: s
    )

    Enum.each(sections, fn section ->
      section
      |> Section.changeset(%{
        lti_1p3_deployment_id: find_latest_deployment_id(section)
      })
      |> Oli.Repo.update()
    end)
  end

  defp find_latest_deployment_id(%{institution: institution}) do
    Enum.reduce(institution.registrations, nil, fn r, _acc ->
      Enum.reduce(r.deployments, nil, fn d, _acc ->
        d.id
      end)
    end)
  end
end
