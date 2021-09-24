defmodule Oli.Repo.Migrations.AdvancedSection do
  use Ecto.Migration
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Resources.Numbering
  alias Oli.Utils

  def up do
    section_publication_ids_map =
      from(s in "sections",
        select: {s.id, s.publication_id}
      )
      |> Repo.all()
      |> Enum.reduce(%{}, fn {s_id, p_id}, acc ->
        Map.put(acc, s_id, p_id)
      end)

    change()

    flush()

    # create section resources for every existing section
    from(s in "sections",
      select: s.id
    )
    |> Repo.all()
    |> Enum.each(fn section_id ->
      publication_id = section_publication_ids_map[section_id]
      migrate_section_resources(section_id, publication_id)
    end)

    # default section description to the base project description
    from(s in "sections",
      join: proj in "projects",
      on: proj.id == s.base_project_id,
      update: [set: [description: proj.description]]
    )
    |> Repo.update_all([])
  end

  def change do
    create table(:delivery_policies) do
      add(:assessment_scoring_model, :string)
      add(:assessment_late_submit_policy, :string)
      add(:assessment_grace_period_sec, :integer)
      add(:assessment_time_limit_sec, :integer)
      add(:assessment_feedback_mode, :string)
      add(:assessment_review_answers_policy, :string)
      add(:assessment_num_attempts, :integer)
      add(:section_id, references(:sections))

      timestamps()
    end

    create table(:section_resources) do
      add(:numbering_index, :integer)
      add(:numbering_level, :integer)
      add(:children, {:array, :id}, default: [])
      add(:slug, :string)
      add(:resource_id, :integer)
      add(:project_id, references(:projects))
      add(:section_id, references(:sections))
      add(:delivery_policy_id, references(:delivery_policies))

      timestamps()
    end

    create table(:user_groups) do
      add(:name, :string)
      add(:section_id, references(:sections))
      add(:delivery_policy_id, references(:delivery_policies))

      timestamps()
    end

    create table(:sections_projects_publications, primary_key: false) do
      add(:section_id, references(:sections))
      add(:project_id, references(:projects))
      add(:publication_id, references(:publications))

      timestamps()
    end

    create table(:user_group_users, primary_key: false) do
      add(:user_group_id, references(:user_groups))
      add(:user_id, references(:users))

      timestamps()
    end

    alter table(:sections) do
      modify(:start_date, :utc_datetime, from: :date)
      modify(:end_date, :utc_datetime, from: :date)
      remove(:publication_id, references(:projects))
      add(:invite_token, :string)
      add(:passcode, :string)
      add(:description, :text)
      add(:root_section_resource_id, references(:section_resources))
      add(:delivery_policy_id, references(:delivery_policies))
    end

    rename(table(:sections), :time_zone, to: :timezone)
    rename(table(:sections), :project_id, to: :base_project_id)
  end

  # Migrates all section resources. Based off the implementation in Sections.create_section_resources
  # but doesn't use schemas and wont change with the codebase
  defp migrate_section_resources(
         section_id,
         publication_id
       ) do
    {root_resource_id, project_id} =
      from(p in "publications",
        where: p.id == ^publication_id,
        limit: 1,
        select: {p.root_resource_id, p.project_id}
      )
      |> Repo.all()
      |> Enum.at(0)

    revisions_by_resource_id =
      get_published_revisions(publication_id)
      |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.resource_id, r) end)

    numberings = Numbering.init_numbering_tracker()
    level = 0
    processed_ids = []

    {root_section_resource_id, _numberings, processed_ids} =
      create_section_resource(
        section_id,
        project_id,
        revisions_by_resource_id,
        processed_ids,
        revisions_by_resource_id[root_resource_id],
        level,
        numberings
      )

    processed_ids = [root_resource_id | processed_ids]

    # create any remaining section resources which are not in the hierarchy
    revisions_by_resource_id
    |> Enum.filter(fn {id, _rev} -> id not in processed_ids end)
    |> Enum.map(fn {_id, revision} ->
      inserted_updated_at = now()

      [
        slug: Utils.Slug.generate(:section_resources, revision.title),
        resource_id: revision.resource_id,
        project_id: project_id,
        section_id: section_id,
        inserted_at: inserted_updated_at,
        updated_at: inserted_updated_at
      ]
    end)
    |> then(&Repo.insert_all("section_resources", &1))

    from(s in "sections",
      where: s.id == ^section_id,
      select: s.id
    )
    |> Repo.update_all(
      set: [root_section_resource_id: root_section_resource_id, updated_at: now()]
    )
    |> then(fn {_, results} -> Enum.at(results, 0) end)
    |> then(fn section_id ->
      # create a section project publication association
      Repo.insert_all("sections_projects_publications", [
        %{
          section_id: section_id,
          project_id: project_id,
          publication_id: publication_id,
          inserted_at: now(),
          updated_at: now()
        }
      ])
    end)
  end

  defp create_section_resource(
         section_id,
         project_id,
         revisions_by_resource_id,
         processed_ids,
         revision,
         level,
         numberings
       ) do
    {numbering_index, numberings} = Numbering.next_index(numberings, level, revision)

    {children, numberings, processed_ids} =
      Enum.reduce(
        revision.children,
        {[], numberings, processed_ids},
        fn resource_id, {children_ids, numberings, processed_ids} ->
          {id, numberings, processed_ids} =
            create_section_resource(
              section_id,
              project_id,
              revisions_by_resource_id,
              processed_ids,
              revisions_by_resource_id[resource_id],
              level + 1,
              numberings
            )

          {[id | children_ids], numberings, [resource_id | processed_ids]}
        end
      )
      # it's more efficient to append to list using [id | children_ids] and
      # then reverse than to concat on every reduce call using ++
      |> then(fn {children, numberings, processed_ids} ->
        {Enum.reverse(children), numberings, processed_ids}
      end)

    %{id: section_resource_id} =
      Oli.Repo.insert_all(
        "section_resources",
        [
          %{
            numbering_index: numbering_index,
            numbering_level: level,
            children: children,
            slug: Utils.Slug.generate(:section_resources, revision.title),
            resource_id: revision.resource_id,
            project_id: project_id,
            section_id: section_id,
            inserted_at: now(),
            updated_at: now()
          }
        ],
        returning: [:id]
      )
      |> then(fn {_, results} -> Enum.at(results, 0) end)

    {section_resource_id, numberings, processed_ids}
  end

  defp now() do
    DateTime.utc_now() |> DateTime.truncate(:second)
  end

  defp get_published_revisions(publication_id) do
    from(p in "published_resources",
      join: r in "revisions",
      on: r.id == p.revision_id,
      where: p.publication_id == ^publication_id,
      select: %{
        resource_id: r.resource_id,
        resource_type_id: r.resource_type_id,
        title: r.title,
        children: r.children
      }
    )
    |> Repo.all()
  end
end
