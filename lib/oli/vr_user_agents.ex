defmodule Oli.VrUserAgents do
  import Ecto.Query, warn: false

  alias Oli.Accounts.Schemas.VrUserAgent
  alias Oli.Accounts.User
  alias Oli.Repo

  def search_user_for_vr(text_search, identifier \\ "name")

  def search_user_for_vr(text_search, "id") do
    case Integer.parse(text_search) do
      {text_search, _} ->
        from(u in User,
          left_join: vrua in VrUserAgent,
          on: vrua.user_id == u.id,
          where: is_nil(vrua.user_id),
          where: u.id == ^text_search,
          select: %{user_id: u.id, user_name: u.name, user_email: u.email, value: false}
        )
        |> Repo.all()

      _ ->
        []
    end
  end

  def search_user_for_vr(text_search, identifier) when identifier in ["name", "email"] do
    identifier = String.to_existing_atom(identifier)

    text_search = String.trim(text_search)

    from(u in User,
      left_join: vrua in VrUserAgent,
      on: vrua.user_id == u.id,
      where: is_nil(vrua.user_id),
      where: ilike(field(u, ^identifier), ^"%#{text_search}%"),
      select: %{user_id: u.id, user_name: u.name, user_email: u.email, value: false}
    )
    |> Repo.all()
  end

  def search_user_for_vr(_text_search, _identifier), do: []

  def vr_user_agents(opts \\ []) do
    {order, column} =
      case Keyword.get(opts, :sort_by) do
        {order, column} when order in [:desc, :asc] and column in ["id", "name", "value"] ->
          {order, String.to_existing_atom(column)}

        _ ->
          {:asc, :id}
      end

    %{limit: limit, offset: offset} = Keyword.get(opts, :paginate) |> IO.inspect()

    query =
      from(vrua in VrUserAgent,
        as: :vrua,
        join: u in User,
        on: u.id == vrua.user_id,
        as: :user,
        select: %{
          user_id: vrua.user_id,
          value: vrua.value,
          name: u.name,
          given_name: u.given_name,
          family_name: u.family_name
        },
        limit: ^limit,
        offset: ^offset
      )

    if column == :value do
      order_by(query, [vrua: vrua], {^order, vrua.value})
    else
      order_by(query, [user: u], {^order, field(u, ^column)})
    end
    |> Repo.all()
  end
end
