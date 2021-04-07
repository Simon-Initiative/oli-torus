defmodule Oli.Repo.Migrations.SlugAlphanumericOnly do
  use Ecto.Migration
  import Ecto.Query, warn: false

  alias Oli.Utils.Slug

  def change do
    # nothing to do
  end

  def up do
    # find all revisions with slugs that contain illegal chars (non-alphanumeric)
    revisions =
      Oli.Repo.all(
        from(r in "revisions",
          where: fragment("slug ~* '[^A-Za-z0-9_]'"),
          select: %{id: r.id, title: r.title}
        )
      )

    # regenerate all affected slugs
    Enum.each(revisions, fn %{id: id, title: title} ->
      revision = from(r in "revisions", where: r.id == ^id)
      Oli.Repo.update_all(revision, set: [slug: Slug.generate("revisions", title)])
    end)
  end
end
