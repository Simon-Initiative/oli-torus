defmodule OliWeb.Accounts.AccountsModel do

  defstruct users_model: nil,
    authors_model: nil,
    active_tab: :authors,
    author: nil,
    active: :accounts

  def new(users_model: users_model, authors_model: authors_model, author: author) do
    {:ok, %__MODULE__{users_model: users_model, authors_model: authors_model, author: author}}
  end

  def change_active_tab(%__MODULE__{} = struct, :authors), do: Map.put(struct, :active_tab, :authors)
  def change_active_tab(%__MODULE__{} = struct, :users), do: Map.put(struct, :active_tab, :users)

end
