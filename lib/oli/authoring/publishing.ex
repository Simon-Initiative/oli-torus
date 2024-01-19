defmodule Oli.Authoring.Publishing do
  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections.Section
  alias Oli.Repo

  def find_instructors_enrolled_in(section) do
    lookup_instructors_enrolled_in(section)
    |> Repo.all()
  end

  def find_oldest_enrolled_instructor(section) do
    from(_ in lookup_instructors_enrolled_in(section), limit: 1)
    |> Repo.one()
  end

  defp lookup_instructors_enrolled_in(section) do
    from(s in Section,
      join: e in assoc(s, :enrollments),
      join: u in assoc(e, :user),
      where: s.id == ^section.id,
      where: u.can_create_sections == true,
      order_by: [asc: e.inserted_at],
      select: u
    )
  end
end
