defmodule Oli.Editing.Utils do

  alias Oli.Accounts

  def authorize_user(author, project) do
    case Accounts.can_access?(author, project) do
      true -> {:ok}
      false -> {:error, {:not_authorized}}
    end
  end

  def trap_nil(result) do
    case result do
      nil -> {:error, {:not_found}}
      _ -> {:ok, result}
    end
  end
end
