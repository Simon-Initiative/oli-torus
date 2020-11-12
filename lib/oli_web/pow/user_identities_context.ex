defmodule OliWeb.Pow.UserIdentities do
  use PowAssent.Ecto.UserIdentities.Context,
    repo: Oli.Repo,
    user: Oli.Accounts.Author

  alias Oli.Accounts

  def create_user(user_identity_params, user_params, user_id_params) do
    case Accounts.get_author_by_email(user_params["email"]) do
      nil -> pow_assent_create_user(user_identity_params, user_params, user_id_params)
      user -> user
    end
  end
end
