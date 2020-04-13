defmodule Oli.Delivery.Sections do
  @moduledoc """
  The Sections context.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Delivery.Sections.Section

  def list_sections do
    Repo.all(Section)
  end

  def get_section!(id), do: Repo.get!(Section, id)

  def get_section_by(clauses), do: Repo.get_by(Section, clauses) |> Repo.preload([:publication, :project])

  def create_section(attrs \\ %{}) do
    %Section{}
    |> Section.changeset(attrs)
    |> Repo.insert()
  end

  def update_section(%Section{} = section, attrs) do
    section
    |> Section.changeset(attrs)
    |> Repo.update()
  end

  def delete_section(%Section{} = section) do
    Repo.delete(section)
  end

  def change_section(%Section{} = section) do
    Section.changeset(section, %{})
  end
end
