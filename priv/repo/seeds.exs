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
alias Oli.Utils
alias Oli.Authoring.Collaborators
alias Oli.Features
alias Oli.Accounts
alias Oli.Accounts.{User, Author}
alias Oli.Repo
alias Oli.Utils.DataGenerators.NameGenerator

# create system roles
if !Oli.Repo.get_by(Oli.Accounts.SystemRole, id: 1) do
  Oli.Repo.insert!(%Oli.Accounts.SystemRole{
    id: 1,
    type: "author"
  })

  Oli.Repo.insert!(%Oli.Accounts.SystemRole{
    id: 2,
    type: "admin"
  })
end

# create admin author
if !Oli.Repo.get_by(Oli.Accounts.Author,
     email: System.get_env("ADMIN_EMAIL", "admin@example.edu")
   ) do
  {:ok, _admin} =
    %Author{}
    |> Author.bootstrap_admin_changeset(%{
      email: System.get_env("ADMIN_EMAIL", "admin@example.edu"),
      name: "Administrator",
      password: System.get_env("ADMIN_PASSWORD", "changeme"),
      system_role_id: Oli.Accounts.SystemRole.role_id().system_admin,
      email_confirmed_at: DateTime.utc_now()
    })
    |> Repo.insert()
end

# create project roles
if !Oli.Repo.get_by(Oli.Authoring.Authors.ProjectRole, id: 1) do
  Oli.Repo.insert!(%Oli.Authoring.Authors.ProjectRole{
    id: 1,
    type: "owner"
  })

  Oli.Repo.insert!(%Oli.Authoring.Authors.ProjectRole{
    id: 2,
    type: "contributor"
  })
end

# create feature flag states
Features.bootstrap_feature_states()

# create resource types
existing_rts =
  Oli.Resources.list_resource_types()
  |> Enum.map(fn %{id: id} -> id end)
  |> MapSet.new()

Oli.Resources.ResourceType.get_types()
|> Enum.each(fn rt ->
  if !MapSet.member?(existing_rts, rt.id) do
    Oli.Resources.create_resource_type(rt)
  end
end)

# create scoring strategy types
if !Oli.Repo.get_by(Oli.Resources.ScoringStrategy, id: 1) do
  Oli.Resources.ScoringStrategy.get_types()
  |> Enum.map(&Oli.Resources.create_scoring_strategy/1)
end

# Seed the database with the locally implemented activity types
Oli.Registrar.register_local_activities(
  MapSet.new([
    "oli_multiple_choice",
    "oli_check_all_that_apply",
    "oli_short_answer",
    "oli_ordering"
  ])
)

# Seed the database with the locally implemented part component types
Oli.Registrar.register_local_part_components(
  MapSet.new([
    "janus_text_flow",
    "janus_image",
    "janus_input_text",
    "janus_input_number",
    "janus_navigation_button",
    "janus_multi_line_text",
    "janus_dropdown",
    "janus_audio",
    "janus_video",
    "janus_slider",
    "janus_image_carousel",
    "janus_mcq",
    "janus_popup",
    "janus_capi_iframe",
    "janus_fill_blanks",
    "janus_hub_spoke"
  ])
)

# create a default active lti_1p3 jwk
if !Oli.Repo.get_by(Lti_1p3.DataProviders.EctoProvider.Jwk, id: 1) do
  %{private_key: private_key} = Lti_1p3.KeyGenerator.generate_key_pair()

  Lti_1p3.create_jwk(%Lti_1p3.Jwk{
    pem: private_key,
    typ: "JWT",
    alg: "RS256",
    kid: UUID.uuid4(),
    active: true
  })
end

# create lti_1p3 platform roles
if !Oli.Repo.get_by(Lti_1p3.DataProviders.EctoProvider.PlatformRole, id: 1) do
  Lti_1p3.Roles.PlatformRoles.list_roles()
  |> Enum.map(fn t ->
    struct(Lti_1p3.DataProviders.EctoProvider.PlatformRole, Map.from_struct(t))
  end)
  |> Enum.map(&Lti_1p3.DataProviders.EctoProvider.PlatformRole.changeset/1)
  |> Enum.map(fn t -> Oli.Repo.insert!(t, on_conflict: :replace_all, conflict_target: :id) end)
end

# create lti_1p3 context roles
if !Oli.Repo.get_by(Lti_1p3.DataProviders.EctoProvider.ContextRole, id: 1) do
  Lti_1p3.Roles.ContextRoles.list_roles()
  |> Enum.map(fn t ->
    struct(Lti_1p3.DataProviders.EctoProvider.ContextRole, Map.from_struct(t))
  end)
  |> Enum.map(&Lti_1p3.DataProviders.EctoProvider.ContextRole.changeset/1)
  |> Enum.map(fn t -> Oli.Repo.insert!(t, on_conflict: :replace_all, conflict_target: :id) end)
end

# only seed with sample data if in development mode
if Application.fetch_env!(:oli, :env) == :dev do
  if !Oli.Repo.get_by(Oli.Authoring.Course.Project, id: 1) do
    # create an example package and publication
    admin_author =
      Oli.Accounts.get_author_by_email(System.get_env("ADMIN_EMAIL", "admin@example.edu"))

    seeds = Seeder.base_project_with_resource(admin_author)

    Collaborators.add_collaborator(admin_author, seeds.project)

    {:ok, publication} = Oli.Publishing.publish_project(seeds.project, "Initial publish", 1)

    section_params =
      %{}
      |> Map.put("title", "Example Course Section")
      |> Map.put("type", :enrollable)
      |> Map.put("base_project_id", seeds.project.id)
      |> Map.put("open_and_free", true)
      |> Map.put("context_id", UUID.uuid4())
      |> Map.put("registration_open", true)

    section =
      with {:ok, section} <- Oli.Delivery.Sections.create_section(section_params),
           {:ok, section} <- Oli.Delivery.Sections.create_section_resources(section, publication) do
        section
      else
        {:error, changeset} -> IO.inspect(changeset)
      end

    # create any seeds defined in seeds.json
    case Utils.read_json_file("./seeds.json") do
      {:ok, json} ->
        case json["registrations"] do
          nil ->
            nil

          registrations ->
            {:ok, %{id: jwk_id}} = Lti_1p3.get_active_jwk()

            registrations
            |> Enum.each(fn attrs ->
              attrs =
                attrs
                |> Map.merge(%{"tool_jwk_id" => jwk_id, "institution_id" => 1})

              %Oli.Lti.Tool.Registration{}
              |> Oli.Lti.Tool.Registration.changeset(attrs)
              |> Oli.Repo.insert()
            end)
        end

        case json["generate_authors"] do
          nil ->
            nil

          num_authors ->
            # create a bunch of authors
            IO.puts("Generating #{num_authors} authors...")

            0..num_authors
            |> Enum.each(fn index ->
              name = NameGenerator.name()

              params = %{
                email: "#{Oli.Utils.Slug.slugify(name)}_#{index}@example.edu",
                name: name,
                system_role_id: Accounts.SystemRole.role_id().author,
                email_confirmed_at: DateTime.utc_now()
              }

              {:ok, _author} =
                Author.noauth_changeset(%Author{}, params)
                |> Repo.insert()
            end)
        end

        case json["generate_users"] do
          nil ->
            nil

          num_users ->
            # create a bunch of users
            IO.puts("Generating #{num_users} users...")

            0..num_users
            |> Enum.each(fn index ->
              name = NameGenerator.name()

              params = %{
                sub: UUID.uuid4(),
                name: name,
                picture:
                  "https://platform.example.edu/#{Oli.Utils.Slug.slugify(name)}_#{index}.jpg",
                email: "#{Oli.Utils.Slug.slugify(name)}_#{index}@platform.example.edu",
                email_confirmed_at: DateTime.utc_now(),
                locale: "en-US"
              }

              {:ok, user} =
                User.noauth_changeset(%User{}, params)
                |> Repo.insert()

              Oli.Delivery.Sections.enroll(user.id, section.id, [
                Lti_1p3.Roles.ContextRoles.get_role(:context_learner)
              ])
            end)
        end

      _ ->
        # no seeds.json file, do nothing
        nil
    end
  end
end
