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
  Oli.Repo.insert! %Oli.Accounts.Author{
    email: System.get_env("ADMIN_EMAIL", "admin@example.edu"),
    first_name: "Administrator",
    last_name: "Admin",
    provider: "identity",
    password_hash: Bcrypt.hash_pwd_salt(System.get_env("ADMIN_PASSWORD", "admin")),
    email_verified: true,
    system_role_id: Oli.Accounts.SystemRole.role_id.admin
  }
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

# create an active lti_1p3 jwk
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

# create default open and free institution
if !Oli.Repo.get_by(Oli.Accounts.Institution, id: 1) do
  Oli.Accounts.create_institution(%{
    id: 1,
    country_code: "US",
    institution_email: System.get_env("ADMIN_EMAIL", "admin@example.edu"),
    institution_url: "oli.cmu.edu",
    name: "Open Learning Initiative",
    timezone: "US/Eastern",
    author_id: 1,
  })
end

# create lti_1p3 platform roles
if !Oli.Repo.get_by(Oli.Lti_1p3.PlatformRole, id: 1) do
  Oli.Repo.insert_all(Oli.Lti_1p3.PlatformRole, Oli.Lti_1p3.PlatformRoles.list_roles())
end

# create lti_1p3 context roles
if !Oli.Repo.get_by(Oli.Lti_1p3.ContextRole, id: 1) do
  Oli.Repo.insert_all(Oli.Lti_1p3.ContextRole, Oli.Lti_1p3.ContextRoles.list_roles())
end

# only seed with sample data if in development mode
if Application.fetch_env!(:oli, :env) == :dev do
  if !Oli.Repo.get_by(Oli.Accounts.Author, email: "test@oli.cmu.edu") do
    Oli.Repo.insert! %Oli.Accounts.Author{
      email: "test@oli.cmu.edu",
      first_name: "Test",
      last_name: "Test",
      provider: "identity",
      password_hash: Bcrypt.hash_pwd_salt("test"),
      email_verified: true,
      system_role_id: Oli.Accounts.SystemRole.role_id.admin
    }
  end

  if !Oli.Repo.get_by(Oli.Authoring.Course.Project, id: 1) do
    # create an example package and publication
    admin_author = Oli.Accounts.get_author_by_email(System.get_env("ADMIN_EMAIL", "admin@example.edu"))
    _test_author = Oli.Accounts.get_author_by_email("test@oli.cmu.edu")

    seeds = Seeder.base_project_with_resource2()
    |> Seeder.create_section()
    |> Seeder.add_activity(%{title: "Activity with with no attempts"}, :activity_no_attempts)
    |> SnapshotSeeder.setup_csv(Path.expand(__DIR__) <> "/test_snapshots.csv")
    Collaborators.add_collaborator(admin_author, seeds.project)

    Oli.Publishing.publish_project(seeds.project)
  end

  # TODO: REMOVE ME/CLEANUP   ########################
  # {:ok, registration} = Oli.Lti_1p3.create_new_registration(%{
  #   issuer: "https://lti-ri.imsglobal.org",
  #   client_id: "12345",
  #   key_set_url: "https://lti-ri.imsglobal.org/platforms/1237/platform_keys/1231.json",
  #   auth_token_url: "https://lti-ri.imsglobal.org/platforms/1237/access_tokens",
  #   auth_login_url: "https://lti-ri.imsglobal.org/platforms/1237/authorizations/new",
  #   auth_server: "https://lti-ri.imsglobal.org",
  #   tool_private_key: private_key,
  #   kid: "0ijoZKpZWSJQ07b22gbdaCDmglc7BzwyeiQMvK8u-Gk",
  # })

  %{id: jwk_id, pem: pem, typ: typ, alg: alg, kid: kid} = Oli.Lti_1p3.get_active_jwk()

  {:ok, registration} = Oli.Lti_1p3.create_new_registration(%{
    issuer: "https://canvas.oli.cmu.edu",
    client_id: "10000000000031",
    key_set_url: "https://canvas.oli.cmu.edu/api/lti/security/jwks",
    auth_token_url: "https://canvas.oli.cmu.edu/login/oauth2/token",
    auth_login_url: "https://canvas.oli.cmu.edu/api/lti/authorize_redirect",
    auth_server: "https://canvas.oli.cmu.edu",
    tool_jwk_id: jwk_id,
    institution_id: 1,
    kid: "2018-05-18T22:33:20Z",
  })

  Oli.Lti_1p3.create_new_deployment(%{
    deployment_id: "43:4dde05e8ca1973bcca9bffc13e1548820eee93a3",
    registration_id: registration.id,
  })

  public_jwk = pem |> JOSE.JWK.from_pem |> JOSE.JWK.to_public
    |> JOSE.JWK.to_map()
    |> (fn {_kty, public_jwk} -> public_jwk end).()
    |> Map.put("typ", typ)
    |> Map.put("alg", alg)
    |> Map.put("kid", kid)
    |> Jason.encode!

  IO.puts "Public Key: #{public_jwk}"

  ########################

end
