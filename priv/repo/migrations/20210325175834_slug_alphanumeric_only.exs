defmodule Oli.Repo.Migrations.SlugAlphanumericOnly do
  use Ecto.Migration
  import Ecto.Query, warn: false

  alias Oli.Resources.Revision
  alias Oli.Utils.Slug

  def change do
    # nothing to do
  end

  def up do
    # find all revisions with slugs that contain illegal chars (non-alphanumeric)
    revisions = Oli.Repo.all(
      from r in Revision,
      where: fragment("slug ~* '[^A-Za-z0-9_]'"),
      select: r
    )

    # regenerate all affected slugs
    Enum.each(revisions, fn revision ->
      revision
      |> Revision.changeset(%{slug: Slug.generate(:revisions, revision.title)})
      |> Oli.Repo.update()
    end)
  end
end
