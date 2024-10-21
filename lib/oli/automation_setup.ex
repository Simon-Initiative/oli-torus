defmodule Oli.AutomationSetup do
  @moduledoc """
  Sets up data in a torus instance that is meant be used with automated e2e tests to
  enable testing of content in remote torus instances.
  """
  alias Lti_1p3.Tool.ContextRoles

  alias Oli.Repo
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Course.ProjectResource
  alias Oli.Resources.Resource

  alias Ecto.Multi

  import Ecto.Query, warn: false
  require Logger

  def setup_data(
        project_archive,
        create_learner?,
        create_educator?,
        create_author?,
        create_section?
      ) do
    result =
      Multi.new()
      |> Multi.run(:author, fn _repo, _ ->
        create_author(create_author? or project_archive != nil)
      end)
      |> Multi.run(:project, fn _repo, %{author: {author, _}} ->
        create_project(project_archive, author)
      end)
      |> Multi.run(:educator, fn _repo, %{author: {author, _}} ->
        create_educator(create_educator? or create_section?, author)
      end)
      |> Multi.run(:publication, fn _repo, %{project: project, author: {author, _}} ->
        publish_project(project, author.id)
      end)
      |> Multi.run(:section, fn _repo,
                                %{
                                  project: project,
                                  educator: {educator, _},
                                  publication: publication
                                } ->
        create_section(create_section?, publication, project, educator)
      end)
      |> Multi.run(:learner, fn _repo, %{section: section} ->
        create_learner(create_learner?, section)
      end)
      |> Repo.transaction()

    case result do
      {:ok,
       %{
         author: {author, author_password},
         educator: {educator, educator_password},
         learner: {learner, learner_password},
         project: project,
         section: section
       }} ->
        {:ok, author, author_password, educator, educator_password, learner, learner_password,
         project, section}

      error ->
        error
    end
  end

  # Tears down a test project
  # Deletes:
  # project
  #   -> publications
  #       -> publication_resources
  #   -> project_resources
  #       -> resources
  #          -> revisions
  #
  # Only works on automation-test projects
  def teardown_project(slug) do
    with {:ok, project} <-
           Repo.one(
             from p in Project,
               where: p.slug == ^slug,
               preload: [
                 :authors,
                 :resources,
                 :family,
                 :activity_registrations,
                 :part_component_registrations,
                 :communities,
                 :publications
               ]
           )
           |> has_project(),
         # Only tear down projects where duplicates are not allowed
         {:ok} <- no_duplicates(project),
         # Only tear down projects with no authors
         {:ok} <-
           has_no_authors(project.authors) do
      resource_ids = for r <- project.resources, do: r.id

      result =
        Multi.new()
        # Delete all the publications for this project, this will also get the publication_resources
        |> Multi.run(:publications, fn _, _ ->
          {:ok, Enum.each(project.publications, &Oli.Publishing.delete_publication/1)}
        end)
        # Delete all the associations between this project and resources
        |> Multi.delete_all(
          :project_resources,
          from(pr in ProjectResource, where: pr.project_id == ^project.id, select: pr)
        )
        # Delete the revisions that go along with the resources in this project.
        |> Multi.delete_all(
          :revisions,
          from(r in Oli.Resources.Revision, where: r.resource_id in ^resource_ids)
        )
        # Delete the project resources
        |> Multi.delete_all(:resources, from(r in Resource, where: r.id in ^resource_ids))
        |> Multi.delete(:project, project)
        |> Repo.transaction()

      case result do
        {:ok, _} ->
          %{success: true}

        _ ->
          %{success: false}
      end
    else
      {:error, message} -> %{success: false, message: message}
      _ -> %{success: false, message: "Unknown Reason"}
    end
  end

  def teardown_section(nil) do
    %{success: false, message: "No section slug provided"}
  end

  def teardown_section(slug) do
    with {:ok, section} <-
           Oli.Delivery.Sections.get_section_by(slug: slug) |> can_delete_section(),
         {:ok, _} <- Oli.Delivery.Sections.delete_section(section) do
      %{success: true}
    else
      {:error, message} -> %{success: false, message: message}
      _ -> %{success: false, message: "Unknown Reason"}
    end
  end

  def teardown_educator(email, password) do
    teardown_user(email, password, :user, "Test Educator")
  end

  def teardown_learner(email, password) do
    teardown_user(email, password, :user, "Test Learner")
  end

  def teardown_author(email, password) do
    teardown_user(email, password, :author, "Test Author")
  end

  defp publish_project(nil, _) do
    {:ok, nil}
  end

  defp publish_project(project, author_id) do
    Oli.Publishing.publish_project(
      project,
      "Automated test setup",
      author_id
    )
  end

  defp create_project(nil, _) do
    # It's normal & ok if we don't want to set up a project.
    {:ok, nil}
  end

  defp create_project(archive_file, author) do
    Oli.Interop.Ingest.ingest(archive_file, author)
  end

  defp create_section(false, _, _, _) do
    {:ok, nil}
  end

  defp create_section(true, _, nil, _) do
    # Needs a project to create a section, but this is a normal use-case, not an error.
    {:ok, nil}
  end

  defp create_section(true, publication, project, educator) do
    customizations =
      case project.customizations do
        nil -> nil
        labels -> Map.from_struct(labels)
      end

    {:ok, section} =
      Oli.Delivery.Sections.create_section(%{
        title: "Automation test section",
        context_id: UUID.uuid4(),
        start_date: Timex.now(),
        end_date: Timex.add(Timex.now(), Timex.Duration.from_days(1)),
        base_project_id: project.id,
        open_and_free: true,
        customizations: customizations
      })

    Oli.Delivery.Sections.create_section_resources(section, publication)

    Oli.Delivery.Sections.enroll(educator.id, section.id, [
      ContextRoles.get_role(:context_instructor)
    ])

    {:ok, section}
  end

  defp create_learner(false, _section) do
    {:ok, nil, nil}
  end

  defp create_learner(true, section) do
    password = random_password()

    {:ok, user} =
      Oli.Accounts.register_independent_user(%{
        email: generate_email("learner"),
        given_name: "Test",
        family_name: "Learner",
        password: password,
        password_confirmation: password,
        age_verified: true,
        email_verified: true,
        email_confirmed_at: Timex.now(),
        research_opt_out: true,
        can_create_sections: false
      })

    if section do
      Oli.Delivery.Sections.enroll(user.id, section.id, [
        ContextRoles.get_role(:context_learner)
      ])
    end

    {:ok, {user, password}}
  end

  defp create_educator(false, _) do
    {:ok, nil, nil}
  end

  defp create_educator(true, author) do
    password = random_password()

    {:ok, user} =
      Oli.Accounts.register_independent_user(%{
        email: generate_email("educator"),
        given_name: "Test",
        family_name: "Educator",
        password: password,
        password_confirmation: password,
        age_verified: true,
        email_verified: true,
        confirmed_at: Timex.now(),
        research_opt_out: true,
        can_create_sections: true,
        author_id: if(is_nil(author), do: nil, else: author.id)
      })

    {:ok, {user, password}}
  end

  defp create_author(false) do
    {:ok, nil}
  end

  defp create_author(true) do
    password = random_password()

    {:ok, user} =
      Oli.Accounts.register_author(%{
        email: generate_email("author"),
        given_name: "Test",
        family_name: "Author",
        password: password,
        password_confirmation: password,
        system_role_id: Oli.Accounts.SystemRole.role_id().author,
        confirmed_at: Timex.now()
      })

    {:ok, {user, password}}
  end

  defp has_project(nil) do
    {:error, "Project not found"}
  end

  defp has_project(project) do
    {:ok, project}
  end

  defp has_no_authors([]) do
    {:ok}
  end

  defp has_no_authors(_) do
    {:error, "Can only delete projects with no authors"}
  end

  defp can_delete_section(nil) do
    {:error, "Section not found"}
  end

  defp can_delete_section(%{:title => "Automation test section"} = section) do
    {:ok, section}
  end

  defp can_delete_section(_) do
    {:error, "Can only delete sections with title 'Automation test section'"}
  end

  defp no_duplicates(project) do
    child_project_exists =
      Repo.exists?(
        from p in Project,
          where: p.project_id == ^project.id,
          select: p
      )

    unless project.allow_duplication or child_project_exists do
      {:ok}
    else
      # If we have child projects, or the project allows duplicates, don't let us delete it.
      {:error, "Project allows duplicates"}
    end
  end

  defp teardown_user(nil, _, _, _),
    do: %{
      success: false,
      message: "User not specififed"
    }

  defp teardown_user(_, nil, _, _),
    do: %{
      success: false,
      message: "Password not specified"
    }

  defp teardown_user(email, password, user_type, expected_name) do
    case(validate_user(email, password, user_type, expected_name)) do
      {:error, message} ->
        %{
          success: false,
          message: message
        }

      {:ok, user} ->
        Logger.info("Deleting test user #{email}")
        Oli.Repo.delete(user)
        %{success: true}
    end
  end

  defp validate_user(email, password, user_type, expected_name) do
    # MER-3835 TODO
    throw "NOT IMPLEMENTED"
  end

  defp generate_email(prefix) do
    "#{prefix}-e2e-test-#{System.os_time()}@argos.test"
  end

  defp random_password do
    for _ <- 1..20, into: "", do: <<Enum.random(~c"0123456789abcdefghijklmnopqrstuvwxyz_$#@!")>>
  end
end
