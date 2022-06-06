defmodule Oli.Factory do
  use ExMachina.Ecto, repo: Oli.Repo

  alias Oli.Accounts.{Author, User}
  alias Oli.Authoring.Course.{Family, Project, ProjectVisibility, ProjectResource}
  alias Oli.Branding.Brand

  alias Oli.Delivery.Attempts.Core.{
    ActivityAttempt,
    LMSGradeUpdate,
    PartAttempt,
    ResourceAccess,
    ResourceAttempt
  }

  alias Oli.Delivery.Gating.GatingCondition
  alias Oli.Delivery.Snapshots.Snapshot
  alias Oli.Lti.LtiParams

  alias Oli.Delivery.Sections.{
    Enrollment,
    Section,
    SectionsProjectsPublications,
    SectionResource,
    SectionInvite
  }

  alias Oli.Delivery.Paywall.{Discount, Payment}
  alias Oli.Groups.{Community, CommunityAccount, CommunityInstitution, CommunityVisibility}
  alias Oli.Institutions.{Institution, SsoJwk}
  alias Oli.Inventories.Publisher
  alias Oli.Lti.Tool.{Deployment, Registration}
  alias Oli.Notifications.SystemMessage
  alias Oli.Publishing.{Publication, PublishedResource}
  alias Oli.Resources.{Resource, Revision}

  def author_factory() do
    %Author{
      email: "#{sequence("author")}@example.edu",
      name: "Author name",
      given_name: sequence("Author given name"),
      family_name: "Author family name",
      system_role_id: Oli.Accounts.SystemRole.role_id().author
    }
  end

  def user_factory() do
    %User{
      email: "#{sequence("user")}@example.edu",
      name: sequence("User name"),
      given_name: sequence("User given name"),
      family_name: "User family name",
      sub: "#{sequence("usersub")}",
      author: fn -> build(:author) end,
      guest: false,
      independent_learner: true,
      can_create_sections: true,
      locked_at: nil,
      age_verified: true
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

  def community_user_account_factory() do
    %CommunityAccount{
      community: fn -> build(:community) end,
      user: fn -> build(:user) end,
      is_admin: false
    }
  end

  def community_account_factory(), do: struct!(community_admin_account_factory())

  def community_admin_account_factory() do
    %CommunityAccount{
      community: fn -> build(:community) end,
      author: fn -> build(:author) end,
      is_admin: true
    }
  end

  def community_visibility_factory(), do: struct!(community_project_visibility_factory())

  def community_project_visibility_factory() do
    %CommunityVisibility{
      community: fn -> build(:community)end,
      project: fn -> build(:project) end
    }
  end

  def community_product_visibility_factory() do
    %CommunityVisibility{
      community: fn -> build(:community) end,
      section: fn -> build(:section) end
    }
  end

  def project_factory() do
    %Project{
      description: "Example description",
      title: sequence("Example Course"),
      slug: sequence("examplecourse"),
      version: "1",
      family: fn -> build(:family) end,
      visibility: :global,
      authors: fn -> build_list(2, :author) end,
      publisher: fn -> build(:publisher) end
    }
  end

  def project_visibility_factory(), do: struct!(project_author_visibility_factory())

  def project_author_visibility_factory() do
    project = insert(:project)
    author = insert(:author)

    %ProjectVisibility{
      project_id: project.id,
      author_id: author.id
    }
  end

  def project_institution_visibility_factory() do
    project = insert(:project)
    institution = insert(:institution)

    %ProjectVisibility{
      project_id: project.id,
      institution_id: institution.id
    }
  end

  def publication_factory() do
    {:ok, date, _timezone} = DateTime.from_iso8601("2019-05-22 20:30:00Z")

    %Publication{
      published: date,
      project: fn -> build(:project) end
    }
  end

  def family_factory() do
    %Family{
      description: "Family description",
      title: "Family title"
    }
  end

  def section_factory() do
    deployment = insert(:lti_deployment)

    %Section{
      title: sequence("Section"),
      timezone: "America/New_York",
      registration_open: true,
      context_id: UUID.uuid4(),
      institution: deployment.institution,
      base_project: fn -> build(:project) end,
      slug: sequence("examplesection"),
      type: :blueprint,
      open_and_free: false,
      description: "A description",
      brand: fn -> build(:brand) end,
      publisher: fn -> build(:publisher) end,
      lti_1p3_deployment: deployment,
      has_grace_period: false
    }
  end

  def section_with_dates_factory() do
    now = DateTime.utc_now()
    start_date = DateTime.add(now, 3600)
    end_date = DateTime.add(now, 7200)

    struct!(
      section_factory(),
      %{
        start_date: start_date,
        end_date: end_date
      }
    )
  end

  def brand_factory() do
    %Brand{
      name: "Some brand",
      slug: sequence("examplebrand"),
      logo: "www.logo.com",
      logo_dark: "www.logodark.com",
      favicons: "www.favicons.com",
      institution: fn -> build(:institution) end
    }
  end

  def discount_factory() do
    %Discount{
      type: :percentage,
      percentage: 10,
      amount: nil,
      section: fn -> build(:section) end,
      institution: fn -> build(:institution) end
    }
  end

  def institution_factory() do
    %Institution{
      name: sequence("Example Institution"),
      country_code: "US",
      institution_email: "ins@example.edu",
      institution_url: "example.edu",
      timezone: "America/New_York"
    }
  end

  def lti_deployment_factory() do
    %Deployment{
      deployment_id: sequence("deployment_id"),
      registration: fn -> build(:lti_registration) end,
      institution: fn -> build(:institution) end
    }
  end

  def lti_registration_factory() do
    %Registration{
      auth_login_url: "some auth_login_url",
      auth_server: "some auth_server",
      auth_token_url: "some auth_token_url",
      client_id: sequence("some client_id"),
      issuer: "some issuer",
      key_set_url: "some key_set_url",
      tool_jwk_id: nil
    }
  end

  def community_member_account_factory() do
    %CommunityAccount{
      community: fn -> build(:community) end,
      user: fn -> build(:user) end,
      is_admin: false
    }
  end

  def community_institution_factory() do
    %CommunityInstitution{
      community: fn -> build(:community) end,
      institution: fn -> build(:institution) end
    }
  end

  def published_resource_factory() do
    %PublishedResource{
      resource: fn -> build(:resource) end,
      publication: fn -> build(:publication) end,
      revision: fn -> build(:revision) end,
      author: fn -> build(:author) end
    }
  end

  def section_project_publication_factory() do
    %SectionsProjectsPublications{
      project: fn -> build(:project) end,
      section: fn -> build(:section) end,
      publication: fn -> build(:publication) end
    }
  end

  def section_resource_factory() do
    %SectionResource{
      project: fn -> build(:project) end,
      section: fn -> build(:section) end,
      resource_id: insert(:resource).id,
      slug: sequence("some_slug")
    }
  end

  def revision_factory() do
    %Revision{
      title: "Example revision",
      slug: "example_revision",
      resource: fn -> build(:resource) end
    }
  end

  def resource_factory() do
    %Resource{}
  end

  def project_resource_factory() do
    %ProjectResource{
      project_id: insert(:project).id,
      resource_id: insert(:resource).id
    }
  end

  def gating_condition_factory() do
    {:ok, start_date, _timezone} = DateTime.from_iso8601("2019-05-22 20:30:00Z")
    {:ok, end_date, _timezone} = DateTime.from_iso8601("2019-06-24 20:30:00Z")

    %GatingCondition{
      user: fn -> build(:user) end,
      section: fn -> build(:section) end,
      resource: fn -> build(:resource) end,
      type: :schedule,
      data: %{end_datetime: end_date, start_datetime: start_date}
    }
  end

  def sso_jwk_factory() do
    %{private_key: private_key} = Lti_1p3.KeyGenerator.generate_key_pair()

    %SsoJwk{
      pem: private_key,
      typ: "JWT",
      alg: "RS256",
      kid: UUID.uuid4()
    }
  end

  def enrollment_factory() do
    %Enrollment{
      user: fn -> build(:user) end,
      section: fn -> build(:section) end
    }
  end

  def payment_factory() do
    %Payment{
      type: :direct,
      amount: Money.new(:USD, 25),
      provider_type: :stripe,
      section: fn -> build(:section) end,
      enrollment: fn -> build(:enrollment) end
    }
  end

  def system_message_factory() do
    {:ok, start_date, _timezone} = DateTime.from_iso8601("2022-02-07 20:30:00Z")
    {:ok, end_date, _timezone} = DateTime.from_iso8601("2022-02-07 21:30:00Z")

    %SystemMessage{
      message: sequence("Message"),
      active: true,
      start: start_date,
      end: end_date
    }
  end

  def active_system_message_factory() do
    now = DateTime.utc_now()
    start_date = DateTime.add(now, -3600)
    end_date = DateTime.add(now, 3600)

    %SystemMessage{
      message: sequence("Message"),
      active: true,
      start: start_date,
      end: end_date
    }
  end

  def section_invite_factory() do
    date_expires = DateTime.add(DateTime.utc_now(), 3600)

    %SectionInvite{
      section: fn -> build(:section) end,
      slug: sequence("exampleinvite"),
      date_expires: date_expires
    }
  end

  def snapshot_factory() do
    revision = insert(:revision)

    %Snapshot{
      resource: revision.resource,
      activity: revision.resource,
      user: fn -> build(:user) end,
      section: fn -> build(:section) end,
      #
      part_attempt: fn -> build(:part_attempt) end,
      revision: revision,
      part_id: sequence("part_id"),
      score: Enum.random(0..100),
      out_of: 100,
      correct: true,
      hints: 0,
      attempt_number: 1,
      part_attempt_number: 1,
      resource_attempt_number: 1,
      activity_type_id: 1
    }
  end

  def part_attempt_factory() do
    %PartAttempt{
      attempt_guid: sequence("guid"),
      attempt_number: sequence("") |> Integer.parse() |> elem(0),
      part_id: sequence("part_id"),
      activity_attempt: fn -> build(:activity_attempt) end
    }
  end

  def activity_attempt_factory() do
    revision = insert(:revision)

    %ActivityAttempt{
      attempt_guid: sequence("guid"),
      attempt_number: sequence("") |> Integer.parse() |> elem(0),
      resource: revision.resource,
      revision: revision,
      resource_attempt: fn -> build(:resource_attempt) end
    }
  end

  def resource_attempt_factory() do
    revision = insert(:revision)

    %ResourceAttempt{
      attempt_guid: sequence("guid"),
      attempt_number: sequence("") |> Integer.parse() |> elem(0),
      resource_access: fn -> build(:resource_access) end,
      revision: revision,
      content: %{}
    }
  end

  def resource_access_factory() do
    %ResourceAccess{
      access_count: sequence("") |> Integer.parse() |> elem(0),
      user: fn -> build(:user) end,
      section: fn -> build(:section) end,
      resource: fn -> build(:resource) end
    }
  end

  def lti_params_factory() do
    %LtiParams{
      issuer: sequence("issuer"),
      client_id: sequence("client_id"),
      deployment_id: sequence("deployment_id"),
      context_id: sequence("context_id"),
      sub: sequence("sub"),
      params: %{},
      exp: DateTime.add(DateTime.utc_now(), 3600)
    }
  end

  def publisher_factory() do
    %Publisher{
      name: sequence("Publisher"),
      email: "#{sequence("publisher")}@example.education",
      address: "Publisher Address",
      main_contact: "Publisher Contact",
      website_url: "mypublisher.com",
      default: false
    }
  end

  def lms_grade_update_factory() do
    %LMSGradeUpdate{
      score: Enum.random(0..100),
      out_of: 100,
      type: :inline,
      result: :success,
      attempt_number: 1,
      resource_access: fn -> build(:resource_access) end
    }
  end
end
