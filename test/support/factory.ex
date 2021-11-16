defmodule Oli.Factory do
  use ExMachina.Ecto, repo: Oli.Repo

  alias Oli.Accounts.{Author, User}
  alias Oli.Groups.{Community, CommunityAccount}

  def author_factory() do
    %Author{
      email: "#{sequence("author")}@example.edu",
      name: "Author name",
      given_name: "Author given name",
      family_name: "Author family name",
      system_role_id: Oli.Accounts.SystemRole.role_id().author
    }
  end

  def user_factory() do
    %User{
      email: "#{sequence("user")}@example.edu",
      name: "User name",
      given_name: "User given name",
      family_name: "User family name",
      sub: "#{sequence("usersub")}"
    }
  end

  def community_factory() do
    %Community{
      name: sequence("Example Community"),
      description: "An awesome description",
      key_contact: "keycontact@example.com",
      global_access: true,
      status: :active
    }
  end

  def community_account_factory() do
    %CommunityAccount{
      community: insert(:community),
      author: insert(:author),
      user: insert(:user),
      is_admin: true
    }
  end
end
