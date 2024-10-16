defmodule OliWeb.Pow.UserContext do
  @moduledoc """
  Custom module that handles pow users context for user.
  """
  use OliWeb, :verified_routes

  use Pow.Ecto.Context,
    repo: Oli.Repo,
    user: Oli.Accounts.User

  alias Oli.{AccountLookupCache, Accounts}
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.{Repo, Utils}
  alias OliWeb.Router.Helpers, as: Routes

  require Logger

  @doc """
  Overrides the existing pow get_by/1 and ensures only
  independent learners are queried
  """
  @impl true
  def get_by(clauses) do
    clauses = Keyword.put_new(clauses, :independent_learner, true)

    pow_get_by(clauses)
  end

  @spec lock(map()) :: {:ok, map()} | {:error, map()}
  def lock(user) do
    user
    |> User.lock_changeset()
    |> Repo.update()
    |> case do
      {:ok, %User{id: user_id}} ->
        AccountLookupCache.delete("user_#{user_id}")

      error ->
        error
    end
  end

  @spec unlock(map()) :: {:ok, map()} | {:error, map()}
  def unlock(user) do
    user
    |> User.noauth_changeset(%{locked_at: nil})
    |> Repo.update()
    |> case do
      {:ok, %User{id: user_id}} ->
        AccountLookupCache.delete("user_#{user_id}")

      error ->
        error
    end
  end

  @doc """
  Overrides the default Pow.Ecto.Context `create` to set the virtual `enroll_after_email_confirmation`
  field after a user is created as part of an independent enrollment email confirmation
  """
  @impl true
  def create(params) do
    case Accounts.get_independent_user_by(%{email: params["email"]}) do
      %User{email: email} = user ->
        if user.confirmed_at,
          do:
            Oli.Email.create_email(
              email,
              "Account already exists",
              "account_already_exists.html",
              %{
                url: ~p"/users/log_in",
                forgot_password: Utils.ensure_absolute_url(~p"/users/reset_password")
              }
            )
            |> Oli.Mailer.deliver_now()

        {:error, %{email: "has already been taken"}}

      _nil ->
        params =
          with %{"section" => section_slug} <- params,
               %Section{skip_email_verification: true} <-
                 Sections.get_section_by_slug(section_slug) do
            confirmed_at = DateTime.truncate(DateTime.utc_now(), :second)
            Map.put(params, "confirmed_at", confirmed_at)
          else
            _ -> params
          end

        %User{}
        |> User.verification_changeset(params)
        |> Repo.insert()
        |> case do
          {:ok, user} ->
            if Application.fetch_env!(:oli, :age_verification)[:is_enabled] == "true" do
              Logger.info(
                "User (id: #{user.id}, email: #{user.email}) created successfully with age verification"
              )
            end

            case params do
              %{"section" => section} ->
                # set the `enroll_after_email_confirmation` virtual field from the given section param
                {:ok, Map.put(user, :enroll_after_email_confirmation, section)}

              _ ->
                {:ok, user}
            end

          {:error, error} ->
            {:error, error}
        end
    end
  end

  @impl true
  def update(user, attrs),
    do: Accounts.update_user(user, attrs)
end
