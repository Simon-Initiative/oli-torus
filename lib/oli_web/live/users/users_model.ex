defmodule OliWeb.Users.UsersModel do

  defstruct users_model: nil, authors_model: nil, active: :authors, author: nil

  def new(users_model: users_model, authors_model: authors_model, author: author) do
    {:ok, %__MODULE__{users_model: users_model, authors_model: authors_model, author: author}}
  end

  def update_users(%__MODULE__{} = struct, users) do
    struct
    |> Map.put(:users_model, users)
  end

  def update_authors(%__MODULE__{} = struct, authors) do
    struct
    |> Map.put(:authors_model, authors)
  end

  def change_active_view(%__MODULE__{} = struct, active) do
    struct
    |> Map.put(:active, active)
  end

end
