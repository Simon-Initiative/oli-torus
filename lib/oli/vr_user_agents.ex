defmodule Oli.VrUserAgents do
  @doc """
  This module is responsible for managing the VR user agents.
  """
  import Ecto.Query, warn: false
  alias Oli.Accounts.Schemas.VrUserAgent
  alias Oli.Accounts.User
  alias Oli.Repo
  alias Oli.VrLookupCache

  @spec count() :: integer()
  def count(), do: Repo.aggregate(VrUserAgent, :count)

  @spec get(integer) :: VrUserAgent.t() | nil
  def get(user_id), do: Repo.get(VrUserAgent, user_id)

  @spec insert(map()) :: {:ok, VrUserAgent.t()} | {:error, Ecto.Changeset.t()}
  def insert(data) do
    %VrUserAgent{}
    |> VrUserAgent.changeset(data)
    |> Oli.Repo.insert()
  end

  @spec delete(integer) :: {:ok, VrUserAgent.t()} | {:error, Ecto.Changeset.t()}
  def delete(user_id) do
    get(user_id)
    |> Repo.delete()
    |> delete_from_cache()
  end

  @spec update(VrUserAgent.t(), map()) :: {:ok, VrUserAgent.t()} | {:error, Ecto.Changeset.t()}
  def update(vr_user_agent, data) do
    vr_user_agent
    |> VrUserAgent.changeset(data)
    |> Repo.update()
    |> delete_from_cache()
  end

  @spec delete_from_cache({:ok, VrUserAgent.t()} | {:error, Ecto.Changeset.t()}) ::
          {:ok, VrUserAgent.t()} | {:error, Ecto.Changeset.t()}
  defp delete_from_cache(result) do
    case result do
      vr_user_agent = {:ok, %VrUserAgent{user_id: user_id}} ->
        VrLookupCache.delete("vr_user_agent_#{user_id}")
        vr_user_agent

      error ->
        error
    end
  end

  @spec search_user_for_vr(String.t(), String.t()) :: [map()] | []
  def search_user_for_vr(text_search, identifier \\ "name")

  def search_user_for_vr(text_search, identifier = "id") do
    identifier = String.to_existing_atom(identifier)
    text_search = String.trim(text_search)

    case Integer.parse(text_search) do
      {number, _} -> Repo.all(query_search(number, identifier))
      _ -> []
    end
  end

  def search_user_for_vr(text_search, identifier) when identifier in ["name", "email"] do
    identifier = String.to_existing_atom(identifier)
    text_search = String.trim(text_search)

    Repo.all(query_search(text_search, identifier))
  end

  def search_user_for_vr(_text_search, _identifier), do: []

  defp query_search(text_search, identifier) do
    from(u in User,
      as: :user,
      left_join: vrua in VrUserAgent,
      on: vrua.user_id == u.id,
      where: is_nil(vrua.user_id),
      where: ^find_by(text_search, identifier),
      select: %{user_id: u.id, user_name: u.name, user_email: u.email, value: false}
    )
  end

  defp find_by(text_search, :id) when is_number(text_search) do
    dynamic([user: u], u.id == ^text_search)
  end

  defp find_by(text_search, identifier) when identifier in [:name, :email] do
    dynamic([user: u], ilike(field(u, ^identifier), ^"%#{text_search}%"))
  end

  @spec vr_user_agents(Keyword.t()) :: [map()] | []
  def vr_user_agents(opts \\ []) do
    {order, column} =
      case Keyword.get(opts, :sort_by) do
        {order, column} when order in [:desc, :asc] and column in ["id", "name", "value"] ->
          {order, String.to_existing_atom(column)}

        _ ->
          {:asc, :id}
      end

    %{limit: limit, offset: offset} =
      case Keyword.get(opts, :paginate) do
        %{limit: _limit, offset: _offset} = paginate -> paginate
        _ -> %{limit: 10, offset: 0}
      end

    from(vrua in VrUserAgent,
      as: :vrua,
      join: u in User,
      on: u.id == vrua.user_id,
      as: :user,
      order_by: ^filter_order_by(order, column),
      select: %{user_id: vrua.user_id, value: vrua.value, name: u.name},
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
  end

  defp filter_order_by(order, :value),
    do: [{order, dynamic([vrua: vrua], vrua.value)}]

  defp filter_order_by(order, column),
    do: [{order, dynamic([user: u], field(u, ^column))}]
end
