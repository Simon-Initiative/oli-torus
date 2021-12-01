defmodule Oli.Factory do
  use ExMachina.Ecto, repo: Oli.Repo

  alias Oli.Accounts.{Author, User}
  alias Oli.Authoring.Course.{Family, Project}
  alias Oli.Delivery.Sections.Section
  alias Oli.Groups.{Community, CommunityAccount, CommunityVisibility}
  alias Oli.Institutions.Institution

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

  def community_visibility_factory() do
    %CommunityVisibility{
      community: insert(:community),
      project: insert(:project),
      section: nil
    }
  end

  def project_factory() do
    %Project{
      description: "Example description",
      title: "Example Course",
      slug: sequence("examplecourse"),
      version: "1",
      family: insert(:family)
    }
  end

  def family_factory() do
    %Family{
      description: "Family description",
      title: "Family title"
    }
  end

  def section_factory() do
    %Section{
      title: "Section",
      timezone: "America/New_York",
      registration_open: true,
      context_id: UUID.uuid4(),
      institution: insert(:institution),
      base_project: insert(:project),
      slug: sequence("examplesection"),
      type: :blueprint
    }
  end

  def institution_factory() do
    %Institution{
      name: "Example Institution",
      country_code: "US",
      institution_email: "ins@example.edu",
      institution_url: "example.edu",
      timezone: "America/New_York"
    }
  end
end
