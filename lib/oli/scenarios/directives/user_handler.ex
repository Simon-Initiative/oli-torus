defmodule Oli.Scenarios.Directives.UserHandler do
  @moduledoc """
  Handles user creation directives.
  """

  alias Oli.Scenarios.DirectiveTypes.UserDirective
  alias Oli.Scenarios.Engine
  alias Oli.Accounts.{User, Author, SystemRole}
  alias Oli.Repo
  require Bcrypt

  @default_password "temporarypassword123"

  def handle(
        %UserDirective{
          name: name,
          type: type,
          email: email,
          given_name: given_name,
          family_name: family_name,
          password: password,
          system_role: system_role,
          can_create_sections: can_create_sections,
          email_verified: email_verified
        },
        state
      ) do
    password = password || @default_password
    system_role = system_role || :author
    can_create_sections = can_create_sections || false
    email_verified = if is_nil(email_verified), do: true, else: email_verified

    try do
      user =
        case type do
          :author ->
            create_author(%{
              email: email,
              given_name: given_name,
              family_name: family_name,
              password: password,
              system_role: system_role,
              email_verified: email_verified
            })

          :instructor ->
            create_user(%{
              email: email,
              given_name: given_name,
              family_name: family_name,
              is_instructor: true,
              password: password,
              can_create_sections: can_create_sections,
              email_verified: email_verified
            })

          :student ->
            create_user(%{
              email: email,
              given_name: given_name,
              family_name: family_name,
              password: password,
              can_create_sections: can_create_sections,
              email_verified: email_verified
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
    password = attrs[:password] || @default_password
    system_role = attrs[:system_role] || :author
    email_verified = Map.get(attrs, :email_verified, true)

    email_confirmed_at =
      if email_verified do
        DateTime.utc_now() |> DateTime.truncate(:second)
      else
        nil
      end

    system_role_id =
      SystemRole.role_id()
      |> Map.get(system_role) ||
        raise("Invalid system_role #{inspect(system_role)} for author directive")

    {:ok, %Author{} = author} =
      %Author{}
      |> Author.registration_changeset(%{
        email: attrs.email,
        given_name: attrs.given_name,
        family_name: attrs.family_name,
        password: password,
        password_confirmation: password
      })
      |> Author.noauth_changeset(%{
        email: attrs.email,
        given_name: attrs.given_name,
        family_name: attrs.family_name,
        system_role_id: system_role_id,
        email_confirmed_at: email_confirmed_at
      })
      |> Repo.insert()

    %Author{author | email_verified: email_verified}
  end

  defp create_user(attrs) do
    password = attrs[:password] || @default_password
    can_create_sections = attrs[:can_create_sections] || false
    email_verified = Map.get(attrs, :email_verified, true)

    email_confirmed_at =
      if email_verified do
        DateTime.utc_now() |> DateTime.truncate(:second)
      else
        nil
      end

    {:ok, user} =
      %User{}
      |> Ecto.Changeset.cast(%{password: password}, [:password])
      |> hash_password()
      |> User.noauth_changeset(%{
        email: attrs.email,
        given_name: attrs.given_name,
        family_name: attrs.family_name,
        sub: UUID.uuid4(),
        email_verified: email_verified,
        email_confirmed_at: email_confirmed_at,
        research_opt_out: false,
        is_instructor: attrs[:is_instructor] || false,
        can_create_sections: can_create_sections
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
