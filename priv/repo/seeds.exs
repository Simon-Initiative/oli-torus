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

pow_config = OliWeb.Pow.PowHelpers.get_pow_config(:author)

# create admin author
if !Oli.Repo.get_by(Oli.Accounts.Author, email: System.get_env("ADMIN_EMAIL", "admin@example.edu")) do
  case Pow.Ecto.Context.create(
         %{
           email: System.get_env("ADMIN_EMAIL", "admin@example.edu"),
           name: "Administrator",
           given_name: "Administrator",
           family_name: "",
           password: System.get_env("ADMIN_PASSWORD", "changeme"),
           password_confirmation: System.get_env("ADMIN_PASSWORD", "changeme"),
           system_role_id: Oli.Accounts.SystemRole.role_id().admin
         },
         pow_config
       ) do
    {:ok, user} ->
      PowEmailConfirmation.Ecto.Context.confirm_email(user, %{}, pow_config)
  end
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
    "janus_carousel",
    "janus_mcq",
    "janus_popup",
    "janus_capi_iframe"
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
  Lti_1p3.Tool.PlatformRoles.list_roles()
  |> Enum.map(fn t ->
    struct(Lti_1p3.DataProviders.EctoProvider.PlatformRole, Map.from_struct(t))
  end)
  |> Enum.map(&Lti_1p3.DataProviders.EctoProvider.PlatformRole.changeset/1)
  |> Enum.map(fn t -> Oli.Repo.insert!(t, on_conflict: :replace_all, conflict_target: :id) end)
end

# create lti_1p3 context roles
if !Oli.Repo.get_by(Lti_1p3.DataProviders.EctoProvider.ContextRole, id: 1) do
  Lti_1p3.Tool.ContextRoles.list_roles()
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

    Oli.Publishing.publish_project(seeds.project)

    # create any registrations defined in registrations.json
    case Utils.read_json_file("./registrations.json") do
      {:ok, json} ->
        {:ok, %{id: jwk_id}} = Lti_1p3.get_active_jwk()

        json
        |> Enum.each(fn attrs ->
          attrs =
            attrs
            |> Map.merge(%{"tool_jwk_id" => jwk_id, "institution_id" => 1})

          %Oli.Lti_1p3.Tool.Registration{}
          |> Oli.Lti_1p3.Tool.Registration.changeset(attrs)
          |> Oli.Repo.insert()
        end)

      _ ->
        # no registrations.json file, do nothing
        nil
    end
  end
end
