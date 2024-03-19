defmodule Oli.VrUserAgents do
  @doc """
  This module is responsible for managing the VR user agents.
  """
  import Ecto.Query, warn: false
  alias Oli.Accounts.VrUserAgent
  alias Oli.Repo

  @spec count() :: integer()
  def count(), do: Repo.aggregate(VrUserAgent, :count)

  @spec get(integer) :: VrUserAgent.t() | nil
  def get(user_id), do: Repo.get(VrUserAgent, user_id)

  @spec insert(map()) :: {:ok, VrUserAgent.t()} | {:error, Ecto.Changeset.t()}
  def insert(data) do
    VrUserAgent.new_changeset(data)
    |> Oli.Repo.insert()
    |> tap(fn _ -> Oli.VrLookupCache.reload() end)
  end

  @spec delete(integer) :: {:ok, VrUserAgent.t()} | {:error, Ecto.Changeset.t()}
  def delete(user_id) do
    get(user_id)
    |> Repo.delete()
    |> tap(fn _ -> Oli.VrLookupCache.reload() end)
  end

  @spec vr_user_agents(Keyword.t()) :: [map()] | []
  def vr_user_agents(opts \\ []) do
    {order, column} =
      case Keyword.get(opts, :sort) do
        {order, column} when order in [:desc, :asc] and column in ["id", "user_agent"] ->
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
      order_by: [{^order, field(vrua, ^column)}],
      select: %{id: vrua.id, user_agent: vrua.user_agent},
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
  end

  def all(), do: Repo.all(VrUserAgent)
end
