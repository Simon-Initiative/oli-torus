defmodule Oli.Delivery.Sections.Blueprint do
  alias Oli.Repo
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections
  import Ecto.Query, warn: false

  def get_active_blueprint(slug) do
    case Repo.get_by(Section, slug: slug) do
      nil -> nil
      %Section{type: :blueprint, status: :active} = section -> section
      _ -> nil
    end
  end

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
            "title" => title
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
end
