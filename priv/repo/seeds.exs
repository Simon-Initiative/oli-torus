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
if !Oli.Repo.get_by(Oli.Accounts.Author, email: System.get_env("ADMIN_EMAIL", "admin@oli.cmu.edu")) do
  Oli.Repo.insert! %Oli.Accounts.Author{
    email: System.get_env("ADMIN_EMAIL", "admin@oli.cmu.edu"),
    first_name: "Administrator",
    last_name: "Admin",
    provider: "identity",
    password_hash: Bcrypt.hash_pwd_salt(System.get_env("ADMIN_PASSWORD", "admin")),
    email_verified: true,
    system_role_id: Oli.Accounts.SystemRole.role_id.admin
  }
end


# create project roles
if !Oli.Repo.get_by(Oli.Accounts.ProjectRole, id: 1) do
  Oli.Repo.insert! %Oli.Accounts.ProjectRole{
    id: 1,
    type: "owner"
  }

  Oli.Repo.insert! %Oli.Accounts.ProjectRole{
    id: 2,
    type: "contributor"
  }
end
# create section roles
if !Oli.Repo.get_by(Oli.Accounts.SectionRole, id: 1) do
  Oli.Repo.insert! %Oli.Accounts.SectionRole{
    id: 1,
    type: "instructor"
  }

  Oli.Repo.insert! %Oli.Accounts.SectionRole{
    id: 2,
    type: "student"
  }
end

# create resource types
if !Oli.Repo.get_by(Oli.Resources.ResourceType, id: 1) do
  Oli.Repo.insert! %Oli.Resources.ResourceType{
    id: 1,
    type: "unscored_page"
  }
  Oli.Repo.insert! %Oli.Resources.ResourceType{
    id: 2,
    type: "scored_page"
  }
  Oli.Repo.insert! %Oli.Resources.ResourceType{
    id: 3,
    type: "container"
  }

end

# Seed the database with the locally implemented activity types
if (length(Oli.Activities.list_activity_registrations()) == 0) do
  Oli.Registrar.register_local_activities()
end

# only seed with sample data if in development mode
if Mix.env == :dev do
  # create an example institution
  if !Oli.Repo.get_by(Oli.Accounts.Institution, id: 1) do
    {:ok, _institution} = Oli.Accounts.create_institution(%{
      country_code: "US",
      institution_email: "admin@oli.cmu.edu",
      institution_url: "oli.cmu.edu",
      name: "Open Learning Initiative",
      timezone: "US/Eastern",
      consumer_key: "0527416a-29ec-4537-b560-6897286a33ec",
      shared_secret: "4FE4F15E33AACCD85D7E198055B2FE83",
      author_id: 1,
    })
  end

  Oli.Repo.insert! %Oli.Accounts.Author{
    email: "test@oli.cmu.edu",
    first_name: "Test",
    last_name: "Test",
    provider: "identity",
    password_hash: Bcrypt.hash_pwd_salt("test"),
    email_verified: true,
    system_role_id: Oli.Accounts.SystemRole.role_id.admin
  }

  # create an example package and publication
  admin_author = Oli.Accounts.get_author_by_email(System.get_env("ADMIN_EMAIL", "admin@oli.cmu.edu"))
  test_author = Oli.Accounts.get_author_by_email("test@oli.cmu.edu")

  {:ok, _project} = Oli.Course.create_project("Example Open and Free Course", admin_author)

  # add a complete base project and attach the admin user as an author
  Oli.Seeder.base_project_with_resource()
    |> Oli.Seeder.add_author(admin_author, :admin_author)
    |> Oli.Seeder.add_author(test_author, :test_author)
    |> Oli.Seeder.add_objective("Define and describe something")
    |> Oli.Seeder.add_objective("Compare and contrast something")
    |> Oli.Seeder.add_objective("Pick and choose when something")

end
