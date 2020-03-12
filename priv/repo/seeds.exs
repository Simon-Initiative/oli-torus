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

Oli.Repo.insert!(%Oli.Accounts.User{
  email: System.get_env("ADMIN_EMAIL", "admin@oli.cmu.edu"),
  first_name: "Administrator",
  last_name: "",
  provider: "identity",
  password_hash: Bcrypt.hash_pwd_salt(System.get_env("ADMIN_PASSWORD", "admin")),
  email_verified: true
})

Oli.Repo.insert!(%Oli.Accounts.SystemRole{
  type: :administrator
})

Oli.Repo.insert!(%Oli.Accounts.SystemRole{
  type: :user
})

Oli.Repo.insert!(%Oli.Accounts.ProjectRole{
  type: :owner
})

Oli.Repo.insert!(%Oli.Accounts.ProjectRole{
  type: :contributor
})

Oli.Repo.insert!(%Oli.Accounts.SectionRole{
  type: :instructor
})

Oli.Repo.insert!(%Oli.Accounts.SectionRole{
  type: :student
})

Oli.Repo.insert!(%Oli.Authoring.ResourceType{
  type: :unscored_page
})

Oli.Repo.insert!(%Oli.Authoring.ResourceType{
  type: :scored_page
})

Oli.Repo.insert!(%Oli.Authoring.ResourceType{
  type: :activity
})
