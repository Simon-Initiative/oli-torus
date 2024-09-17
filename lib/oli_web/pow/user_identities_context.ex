defmodule OliWeb.Pow.UserIdentities do
  use PowAssent.Ecto.UserIdentities.Context,
    repo: Oli.Repo,
    user: Oli.Accounts.User

  alias Oli.Accounts

  # Handle the case where a user signs in with a social account but that email already exists.
  # This will only be allowed to execute if the email given by the signin provider is verified.
  def create_user(
        user_identity_params,
        %{"email" => email, "email_verified" => true} = user_params,
        user_id_params
      ) do
    case Accounts.get_independent_user_by(email: email, independent_learner: true) do
      nil ->
        # user account with the given email doesnt exist, so create it
        pow_assent_create_user(user_identity_params, user_params, user_id_params)

      user ->
        # if a user with the given email already exists and the email is verified by the provider,
        # link the existing user account with that email to this social login provider
        pow_assent_upsert(user, user_identity_params)

        {:ok, user}
    end
  end
end
