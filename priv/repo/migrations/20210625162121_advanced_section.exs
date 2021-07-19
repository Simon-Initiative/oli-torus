defmodule Oli.Repo.Migrations.AdvancedSection do
  use Ecto.Migration
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing
  alias Oli.Publishing.Publication
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project

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
    from(s in Section,
      join: p in Project,
      on: p.id == s.base_project_id,
      select: {s, p}
    )
    |> Repo.all()
    |> Enum.each(fn {section, base_project} ->
      p_id = section_publication_ids_map[section.id]
      publication = Publishing.get_publication!(p_id)
      Sections.create_section_resources(section, publication)
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
      modify :start_date, :utc_datetime, from: :date
      modify :end_date, :utc_datetime, from: :date
      remove :publication_id, references(:projects)
      add(:invite_token, :string)
      add(:passcode, :string)
      add(:description, :text)
      add(:root_section_resource_id, references(:section_resources))
      add(:delivery_policy_id, references(:delivery_policies))
    end

    rename(table(:sections), :time_zone, to: :timezone)
    rename(table(:sections), :project_id, to: :base_project_id)
  end

end
