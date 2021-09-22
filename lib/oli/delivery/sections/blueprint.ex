defmodule Oli.Delivery.Sections.Blueprint do
  alias Oli.Repo
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections
  import Ecto.Query, warn: false

  @doc """
  From a slug, retrieve a valid section blueprint.  A section is a
  valid blueprint when that section is of type :blueprint and the status
  is active.

  Returns nil when there is no matching valid blueprint for the slug.
  """
  def get_active_blueprint(slug) do
    case Repo.get_by(Section, slug: slug) do
      nil -> nil
      %Section{type: :blueprint, status: :active} = section -> section
      _ -> nil
    end
  end

  @doc """
  From a slug, retrieve a valid section blueprint.  A section is a
  valid blueprint when that section is of type :blueprint and the status
  is active.

  Returns nil when there is no matching valid blueprint for the slug.
  """
  def get_blueprint(slug) do
    case Repo.get_by(Section, slug: slug) do
      nil -> nil
      %Section{type: :blueprint} = section -> section
      _ -> nil
    end
  end

  @doc """
  Given a base project slug and a title, create a course section blueprint.

  This creates the "section" record and "section resource" records to mirror
  the current published structure of the course project hierarchy.
  """
  def create_blueprint(base_project_slug, title) do
    Repo.transaction(fn _ ->
      case Oli.Authoring.Course.get_project_by_slug(base_project_slug) do
        nil ->
          {:error, {:invalid_project}}

        project ->
          now = DateTime.utc_now()

          new_blueprint = %{
            "type" => :blueprint,
            "status" => :active,
            "base_project_id" => project.id,
            "open_and_free" => false,
            "context_id" => UUID.uuid4(),
            "start_date" => now,
            "end_date" => now,
            "title" => title,
            "requires_payment" => false,
            "registration_open" => false,
            "timezone" => "America/New_York",
            "amount" => Money.new(:USD, "25.00")
          }

          case Sections.create_section(new_blueprint) do
            {:ok, blueprint} ->
              publication =
                Oli.Publishing.get_latest_published_publication_by_slug(base_project_slug)

              case Sections.create_section_resources(blueprint, publication) do
                {:ok, section} -> section
                {:error, e} -> Repo.rollback(e)
              end

            {:error, e} ->
              Repo.rollback(e)
          end
      end
    end)
  end

  def list_for_project(%Project{id: id}) do
    query =
      from(
        s in Section,
        where: s.type == :blueprint and s.base_project_id == ^id,
        select: s,
        preload: [:base_project]
      )

    Repo.all(query)
  end

  def list() do
    query =
      from(
        s in Section,
        where: s.type == :blueprint,
        select: s,
        preload: [:base_project]
      )

    Repo.all(query)
  end
end
