# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Oli.Repo.insert!(%Oli.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Oli.Seeder
alias Oli.Snapshots.SnapshotSeeder
alias Oli.Authoring.Collaborators

# create system roles
if !Oli.Repo.get_by(Oli.Accounts.SystemRole, id: 1) do
  Oli.Repo.insert! %Oli.Accounts.SystemRole{
    id: 1,
    type: "author"
  }

  Oli.Repo.insert! %Oli.Accounts.SystemRole{
    id: 2,
    type: "admin"
  }
end

# create admin author
if !Oli.Repo.get_by(Oli.Accounts.Author, email: System.get_env("ADMIN_EMAIL", "admin@example.edu")) do
  case Pow.Ecto.Context.create(%{
    email: System.get_env("ADMIN_EMAIL", "admin@example.edu"),
    name: "Administrator",
    given_name: "Administrator",
    family_name: "",
    password: System.get_env("ADMIN_PASSWORD", "changeme"),
    password_confirmation: System.get_env("ADMIN_PASSWORD", "changeme"),
    system_role_id: Oli.Accounts.SystemRole.role_id.admin
  }, otp_app: :oli) do
    {:ok, user} ->
      PowEmailConfirmation.Ecto.Context.confirm_email(user, %{}, otp_app: :oli)
  end
end

# create project roles
if !Oli.Repo.get_by(Oli.Authoring.Authors.ProjectRole, id: 1) do
  Oli.Repo.insert! %Oli.Authoring.Authors.ProjectRole{
    id: 1,
    type: "owner"
  }

  Oli.Repo.insert! %Oli.Authoring.Authors.ProjectRole{
    id: 2,
    type: "contributor"
  }
end

# create resource types
if !Oli.Repo.get_by(Oli.Resources.ResourceType, id: 1) do

  Oli.Resources.ResourceType.get_types()
  |> Enum.map(&Oli.Resources.create_resource_type/1)

end

# create scoring strategy types
if !Oli.Repo.get_by(Oli.Resources.ScoringStrategy, id: 1) do

  Oli.Resources.ScoringStrategy.get_types()
  |> Enum.map(&Oli.Resources.create_scoring_strategy/1)

end

# Seed the database with the locally implemented activity types
if Enum.empty?(Oli.Activities.list_activity_registrations()) do
  Oli.Registrar.register_local_activities()
end

# create themes
[%Oli.Authoring.Theme{
  id: 1,
  name: "Automatic",
  url: nil,
  default: true
},
%Oli.Authoring.Theme{
  id: 2,
  name: "Light",
  url: "/css/authoring_theme_light.css",
  default: false
},
%Oli.Authoring.Theme{
  id: 3,
  name: "Dark",
  url: "/css/authoring_theme_dark.css",
  default: false
}]
|> Enum.map(&Oli.Authoring.Theme.changeset/1)
|> Enum.map(fn t -> Oli.Repo.insert!(t, on_conflict: :replace_all, conflict_target: :id) end)

# create a default active lti_1p3 jwk
if !Oli.Repo.get_by(Oli.Lti_1p3.Jwk, id: 1) do
  %{private_key: private_key} = Oli.Lti_1p3.KeyGenerator.generate_key_pair()
  Oli.Lti_1p3.create_new_jwk(%{
    pem: private_key,
    typ: "JWT",
    alg: "RS256",
    kid: UUID.uuid4(),
    active: true,
  })
end

# create lti_1p3 platform roles
if !Oli.Repo.get_by(Oli.Lti_1p3.PlatformRole, id: 1) do
  Oli.Lti_1p3.PlatformRoles.list_roles()
  |> Enum.map(&Oli.Lti_1p3.PlatformRole.changeset/1)
  |> Enum.map(fn t -> Oli.Repo.insert!(t, on_conflict: :replace_all, conflict_target: :id) end)
end

# create lti_1p3 context roles
if !Oli.Repo.get_by(Oli.Lti_1p3.ContextRole, id: 1) do
  Oli.Lti_1p3.ContextRoles.list_roles()
  |> Enum.map(&Oli.Lti_1p3.ContextRole.changeset/1)
  |> Enum.map(fn t -> Oli.Repo.insert!(t, on_conflict: :replace_all, conflict_target: :id) end)
end

# only seed with sample data if in development mode
if Application.fetch_env!(:oli, :env) == :dev do
  if !Oli.Repo.get_by(Oli.Authoring.Course.Project, id: 1) do
    # create an example package and publication
    admin_author = Oli.Accounts.get_author_by_email(System.get_env("ADMIN_EMAIL", "admin@example.edu"))

    seeds = Seeder.base_project_with_resource(admin_author)
    |> Seeder.create_section()
    |> Seeder.add_activity(%{title: "Activity with with no attempts"}, :activity_no_attempts)
    |> SnapshotSeeder.setup_csv(Path.expand(__DIR__) <> "/test_snapshots.csv")
    Collaborators.add_collaborator(admin_author, seeds.project)

    Oli.Publishing.publish_project(seeds.project)
  end

end
