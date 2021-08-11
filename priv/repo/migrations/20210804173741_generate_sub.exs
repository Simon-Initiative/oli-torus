defmodule Oli.Repo.Migrations.GenerateSub do
  use Ecto.Migration
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Accounts.User

  def change do
    # generate a sub uuid for all users that have a null sub
    from(u in "users",
      where: is_nil(u.sub),
      select: u.id
    )
    |> Repo.all()
    |> Enum.each(fn id ->
      user = from(u in "users", where: u.id == ^id)
      Oli.Repo.update_all(user, set: [sub: UUID.uuid4()])
    end)
  end
end
