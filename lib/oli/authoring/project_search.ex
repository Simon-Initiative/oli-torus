defmodule Oli.Authoring.ProjectSearch do
  import Ecto.Query

  alias Oli.Authoring.Course.Project
  alias Oli.Publishing.Publication
  alias Oli.Repo

  def search(search_string) do
    search_string
    |> normalize()
    |> run()
  end

  defmacro matching_title_description_slug(search_string) do
    quote do
      fragment(
        """
        SELECT
        projects.id AS id,
        ts_rank(
          setweight(to_tsvector('english', projects.title), 'B')
            || setweight(to_tsvector('english', projects.description), 'C')
            || setweight(to_tsvector('simple', projects.slug), 'A')
            || setweight(to_tsvector('simple', projects.version), 'D'),
          plainto_tsquery(unaccent(?))
        ) AS rank
        FROM projects
        WHERE
          setweight(to_tsvector('english', projects.title), 'B')
            || setweight(to_tsvector('english', projects.description), 'C')
            || setweight(to_tsvector('simple', projects.slug), 'A')
            || setweight(to_tsvector('simple', projects.version), 'D') @@ plainto_tsquery(unaccent(?))
          OR projects.title ILIKE ?
        """,
        ^unquote(search_string),
        ^unquote(search_string),
        ^"%#{unquote(search_string)}%"
      )
    end
  end

  defp run(search_string) do
    Repo.all(
      from p in Project,
        as: :project,
        join: id_and_rank in matching_title_description_slug(search_string),
        on: id_and_rank.id == p.id,
        where: exists(from(pub in Publication, where: parent_as(:project).id == pub.project_id)),
        order_by: [desc: id_and_rank.rank],
        select: %{slug: p.slug, title: p.title, description: p.description, version: p.version}
    )
  end

  defp normalize(search_string) do
    search_string
    |> String.downcase()
    # replace newlines with a space
    |> String.replace(~r/\n/, " ")
    # replace tabs with a space
    |> String.replace(~r/\t/, " ")
    # collapse all whitespace to single space
    |> String.replace(~r/\s{2,}/, " ")
    # remove leading and trailing whitespace
    |> String.trim()
  end
end
