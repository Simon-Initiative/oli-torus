defmodule Oli.Scenarios.Directives.UserHandler do
  @moduledoc """
  Handles user creation directives.
  """

  alias Oli.Scenarios.DirectiveTypes.UserDirective
  alias Oli.Scenarios.Engine
  alias Oli.Accounts.{User, Author}
  alias Oli.Repo
  require Bcrypt

  def handle(
        %UserDirective{
          name: name,
          type: type,
          email: email,
          given_name: given_name,
          family_name: family_name
        },
        state
      ) do
    try do
      user =
        case type do
          :author ->
            create_author(%{
              email: email,
              given_name: given_name,
              family_name: family_name
            })

          :instructor ->
            create_user(%{
              email: email,
              given_name: given_name,
              family_name: family_name,
              is_instructor: true
            })

          :student ->
            create_user(%{
              email: email,
              given_name: given_name,
              family_name: family_name
            })

          _ ->
            raise "Unknown user type: #{type}"
        end

      # Store user in state
      new_state = Engine.put_user(state, name, user)

      # Update current author if this is an author
      new_state =
        if type == :author do
          %{new_state | current_author: user}
        else
          new_state
        end

      {:ok, new_state}
    rescue
      e ->
        {:error, "Failed to create user '#{name}': #{Exception.message(e)}"}
    end
  end

  defp create_author(attrs) do
    {:ok, author} =
      %Author{}
      |> Author.registration_changeset(%{
        email: attrs.email,
        given_name: attrs.given_name,
        family_name: attrs.family_name,
        password: "temporarypassword123",
        password_confirmation: "temporarypassword123"
      })
      |> Author.noauth_changeset(%{
        email: attrs.email,
        given_name: attrs.given_name,
        family_name: attrs.family_name
      })
      |> Repo.insert()
    
    author
  end

  defp create_user(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    
    {:ok, user} =
      %User{}
      |> Ecto.Changeset.cast(%{password: "temporarypassword123"}, [:password])
      |> hash_password()
      |> User.noauth_changeset(%{
        email: attrs.email,
        given_name: attrs.given_name,
        family_name: attrs.family_name,
        sub: UUID.uuid4(),
        email_verified: true,
        email_confirmed_at: now,
        research_opt_out: false,
        is_instructor: attrs[:is_instructor] || false
      })
      |> Repo.insert()
    
    user
  end

  defp hash_password(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        Ecto.Changeset.put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
      _ ->
        changeset
    end
  end
end
