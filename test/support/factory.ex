defmodule Oli.Factory do
  use ExMachina.Ecto, repo: Oli.Repo

  alias Oli.Accounts.{Author, User, AuthorPreferences, UserPreferences}
  alias Oli.Authoring.Authors.{AuthorProject, ProjectRole}
  alias Oli.Authoring.Course.{Family, Project, ProjectVisibility, ProjectResource}
  alias Oli.Branding.Brand

  alias Oli.Delivery.Attempts.Core.{
    ActivityAttempt,
    LMSGradeUpdate,
    PartAttempt,
    ResourceAccess,
    ResourceAttempt
  }

  alias Oli.Delivery.DeliverySetting
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
  alias Oli.Publishing.{PublishedResource}
  alias Oli.Publishing.Publications.Publication
  alias Oli.Resources.{Resource, Revision}
  alias Oli.Resources.Collaboration.{CollabSpaceConfig, Post, PostContent}

  def author_factory() do
    %Author{
      email: "#{sequence("author")}@example.edu",
      name: "Author name",
      given_name: sequence("Author given name"),
      family_name: "Author family name",
      system_role_id: Oli.Accounts.SystemRole.role_id().author,
      preferences: build(:author_preferences)
    }
  end

  def author_preferences_factory() do
    %AuthorPreferences{
      timezone: "America/New_York"
    }
  end

  def user_factory() do
    %User{
      email: "#{sequence("user")}@example.edu",
      name: sequence("User name"),
      given_name: sequence("User given name"),
      family_name: "User family name",
      sub: "#{sequence("usersub")}",
      author: anonymous_build(:author),
      guest: false,
      independent_learner: true,
      can_create_sections: true,
      locked_at: nil,
      age_verified: true,
      preferences: build(:user_preferences)
    }
  end

  def user_preferences_factory() do
    %UserPreferences{
      timezone: "America/New_York"
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
      community: anonymous_build(:community),
      user: anonymous_build(:user),
      is_admin: false
    }
  end

  def community_account_factory(), do: struct!(community_admin_account_factory())

  def community_admin_account_factory() do
    %CommunityAccount{
      community: anonymous_build(:community),
      author: anonymous_build(:author),
      is_admin: true
    }
  end

  def community_visibility_factory(), do: struct!(community_project_visibility_factory())

  def community_project_visibility_factory() do
    %CommunityVisibility{
      community: anonymous_build(:community),
      project: anonymous_build(:project)
    }
  end

  def community_product_visibility_factory() do
    %CommunityVisibility{
      community: anonymous_build(:community),
      section: anonymous_build(:section)
    }
  end

  def project_factory() do
    %Project{
      description: "Example description",
      title: sequence("Example Course"),
      slug: sequence("examplecourse"),
      version: "1",
      family: anonymous_build(:family),
      visibility: :global,
      authors: anonymous_build_list(2, :author),
      publisher: anonymous_build(:publisher)
    }
  end

  def author_project_factory() do
    author = insert(:author)
    project = insert(:project)

    %AuthorProject{
      author_id: author.id,
      project_id: project.id,
      project_role_id: ProjectRole.role_id().owner
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
      project: anonymous_build(:project)
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
      registration_open: true,
      context_id: UUID.uuid4(),
      institution: deployment.institution,
      base_project: anonymous_build(:project),
      slug: sequence("examplesection"),
      type: :blueprint,
      open_and_free: false,
      description: "A description",
      brand: anonymous_build(:brand),
      publisher: anonymous_build(:publisher),
      lti_1p3_deployment: deployment,
      has_grace_period: false,
      line_items_service_url: "http://default.com"
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
      institution: anonymous_build(:institution)
    }
  end

  def discount_factory() do
    %Discount{
      type: :percentage,
      percentage: 10,
      amount: nil,
      section: anonymous_build(:section),
      institution: anonymous_build(:institution)
    }
  end

  def institution_factory() do
    %Institution{
      name: sequence("Example Institution"),
      country_code: "US",
      institution_email: "ins@example.edu",
      institution_url: "example.edu",
      research_consent: :oli_form
    }
  end

  def lti_deployment_factory() do
    %Deployment{
      deployment_id: sequence("deployment_id"),
      registration: anonymous_build(:lti_registration),
      institution: anonymous_build(:institution)
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
      tool_jwk_id: nil,
      line_items_service_domain: "some line_items_service_domain"
    }
  end

  def community_member_account_factory() do
    %CommunityAccount{
      community: anonymous_build(:community),
      user: anonymous_build(:user),
      is_admin: false
    }
  end

  def community_institution_factory() do
    %CommunityInstitution{
      community: anonymous_build(:community),
      institution: anonymous_build(:institution)
    }
  end

  def published_resource_factory() do
    %PublishedResource{
      resource: anonymous_build(:resource),
      publication: anonymous_build(:publication),
      revision: anonymous_build(:revision),
      author: anonymous_build(:author)
    }
  end

  def section_project_publication_factory() do
    %SectionsProjectsPublications{
      project: anonymous_build(:project),
      section: anonymous_build(:section),
      publication: anonymous_build(:publication)
    }
  end

  def section_resource_factory() do
    %SectionResource{
      project: anonymous_build(:project),
      section: anonymous_build(:section),
      resource_id: insert(:resource).id,
      slug: sequence("some_slug")
    }
  end

  def revision_factory() do
    %Revision{
      title: "Example revision",
      slug: sequence("example_revision"),
      resource: anonymous_build(:resource),
      collab_space_config: build(:collab_space_config)
    }
  end

  def collab_space_config_factory() do
    %CollabSpaceConfig{}
  end

  def post_content_factory() do
    %PostContent{}
  end

  def post_factory() do
    %Post{
      content: %{message: "Example Post"},
      status: :approved,
      user: anonymous_build(:user),
      section: anonymous_build(:section),
      resource: anonymous_build(:resource),
      updated_at: DateTime.utc_now(),
      inserted_at: DateTime.utc_now(),
      anonymous: false
    }
  end

  def delivery_setting_factory() do
    %DeliverySetting{
      user: anonymous_build(:user),
      section: anonymous_build(:section),
      resource: anonymous_build(:resource),
      collab_space_config: build(:collab_space_config)
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
      user: anonymous_build(:user),
      section: anonymous_build(:section),
      resource: anonymous_build(:resource),
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
      user: anonymous_build(:user),
      section: anonymous_build(:section)
    }
  end

  def payment_factory() do
    %Payment{
      type: :direct,
      amount: Money.new(:USD, 25),
      provider_type: :stripe,
      section: anonymous_build(:section),
      enrollment: anonymous_build(:enrollment)
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
      section: anonymous_build(:section),
      slug: sequence("exampleinvite"),
      date_expires: date_expires
    }
  end

  def snapshot_factory() do
    revision = insert(:revision)

    %Snapshot{
      resource: revision.resource,
      activity: revision.resource,
      user: anonymous_build(:user),
      section: anonymous_build(:section),
      part_attempt: anonymous_build(:part_attempt),
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
      activity_attempt: anonymous_build(:activity_attempt)
    }
  end

  def activity_attempt_factory() do
    revision = insert(:revision)

    %ActivityAttempt{
      attempt_guid: sequence("guid"),
      attempt_number: sequence("") |> Integer.parse() |> elem(0),
      resource: revision.resource,
      revision: revision,
      resource_attempt: anonymous_build(:resource_attempt)
    }
  end

  def resource_attempt_factory() do
    revision = insert(:revision)

    %ResourceAttempt{
      attempt_guid: sequence("guid"),
      attempt_number: sequence("") |> Integer.parse() |> elem(0),
      resource_access: anonymous_build(:resource_access),
      revision: revision,
      content: %{}
    }
  end

  def resource_access_factory() do
    %ResourceAccess{
      access_count: sequence("") |> Integer.parse() |> elem(0),
      user: anonymous_build(:user),
      section: anonymous_build(:section),
      resource: anonymous_build(:resource)
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
      default: false,
      available_via_api: true
    }
  end

  def lms_grade_update_factory() do
    %LMSGradeUpdate{
      score: Enum.random(0..100),
      out_of: 100,
      type: :inline,
      result: :success,
      attempt_number: 1,
      resource_access: anonymous_build(:resource_access)
    }
  end

  # HELPERS

  defp anonymous_build(entity_name, attrs \\ %{}),
    do: fn -> build(entity_name, attrs) end

  defp anonymous_build_list(count, entity_name, attrs \\ %{}),
    do: fn -> build_list(count, entity_name, attrs) end
end
