defmodule Oli.Factory do
  use ExMachina.Ecto, repo: Oli.Repo

  alias Oli.Accounts.VrUserAgent
  alias Oli.Accounts.{Author, User, AuthorPreferences, UserPreferences, UserToken}
  alias Oli.Authoring.Authors.{AuthorProject, ProjectRole}
  alias Oli.Analytics.Summary.ResourceSummary

  alias Oli.Authoring.Course.{
    Family,
    Project,
    ProjectAttributes,
    ProjectVisibility,
    ProjectResource
  }

  alias Oli.Branding.Brand
  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.Sections.Certificate
  alias Oli.Delivery.Sections.GrantedCertificate
  alias Oli.Delivery.Sections.ContainedObjective

  alias Oli.Delivery.Attempts.Core.{
    ActivityAttempt,
    LMSGradeUpdate,
    PartAttempt,
    ResourceAccess,
    ResourceAttempt
  }

  alias Oli.Delivery.Settings.StudentException
  alias Oli.Delivery.Gating.GatingCondition
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
  alias Oli.Institutions.{Institution, SsoJwk, PendingRegistration}
  alias Oli.Inventories.Publisher
  alias Oli.Lti.Tool.{Deployment, Registration}
  alias Oli.Notifications.SystemMessage
  alias Oli.Publishing.{PublishedResource}
  alias Oli.Publishing.Publications.Publication
  alias Oli.Resources.{Resource, ResourceType, Revision}
  alias Oli.Resources.Collaboration.{CollabSpaceConfig, Post, PostContent, UserReactionPost}
  alias Oli.Search.RevisionEmbedding

  def author_factory() do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Author{
      email: "#{sequence("author")}@example.edu",
      email_verified: true,
      email_confirmed_at: now,
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
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %User{
      email: "#{sequence("user")}@example.edu",
      email_verified: true,
      email_confirmed_at: now,
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
      publisher: anonymous_build(:publisher),
      attributes: anonymous_build(:project_attributes)
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
      analytics_version: :v1,
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
      collab_space_config: build(:collab_space_config),
      content: %{
        "model" => []
      },
      ids_added: true
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

  def user_reaction_post_factory() do
    %UserReactionPost{
      reaction: :like
      # user: anonymous_build(:user),
      # post: anonymous_build(:post)
    }
  end

  def delivery_setting_factory() do
    %StudentException{
      user: anonymous_build(:user),
      section: anonymous_build(:section),
      resource: anonymous_build(:resource),
      collab_space_config: build(:collab_space_config)
    }
  end

  def resource_factory() do
    %Resource{}
  end

  def project_resource_factory(attr) do
    %ProjectResource{
      project_id: attr[:project_id] || insert(:project).id,
      resource_id: attr[:resource_id] || insert(:resource).id
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
      enrollment: anonymous_build(:enrollment),
      generation_date: DateTime.utc_now()
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

  def pending_registration_factory() do
    %PendingRegistration{
      country_code: "US",
      institution_email: "#{sequence("institution_")}@edu.com",
      institution_url: "https://www.#{sequence("institution_")}.com",
      name: sequence("Institution "),
      issuer: sequence("issuer_"),
      client_id: sequence("client_id_"),
      deployment_id: sequence("deployment_id_"),
      key_set_url: "https://www.#{sequence("key_set_url_")}.com",
      auth_token_url: "https://www.#{sequence("key_set_url_")}.com/auth/token",
      auth_login_url: "https://www.#{sequence("key_set_url_")}.com/auth/login",
      auth_server: "https://www.#{sequence("key_set_url_")}.com/auth/server",
      line_items_service_domain: ""
    }
  end

  def contained_objective_factory() do
    %ContainedObjective{
      section: anonymous_build(:section),
      container_id: insert(:resource).id,
      objective_id: insert(:resource).id
    }
  end

  def student_exception_factory() do
    %StudentException{
      user: anonymous_build(:user),
      section: anonymous_build(:section),
      resource: anonymous_build(:resource),
      collab_space_config: build(:collab_space_config)
    }
  end

  def vr_user_agent_factory() do
    %VrUserAgent{}
  end

  def revision_embedding_factory() do
    %RevisionEmbedding{
      revision: anonymous_build(:revision),
      resource: anonymous_build(:resource),
      resource_type_id: 1,
      component_type: :stem,
      chunk_type: :paragraph,
      chunk_ordinal: 1,
      fingerprint_md5: "fingerprint_md5",
      content: "content",
      embedding: anonymous_build(:embedding)
    }
  end

  def embedding_factory() do
    Pgvector.new(Enum.to_list(1..1536))
  end

  def project_attributes_factory() do
    %ProjectAttributes{
      learning_language: "en",
      license: anonymous_build(:project_attributes_license),
      calculate_embeddings_on_publish: false
    }
  end

  def project_attributes_license_factory() do
    %ProjectAttributes.License{
      license_type: :none,
      custom_license_details: ""
    }
  end

  def page_context_factory() do
    %PageContext{
      user: build(:user),
      review_mode: false,
      page: build(:revision, resource_type_id: ResourceType.get_id_by_type("page")),
      progress_state: :in_progress,
      resource_attempts: [build(:resource_attempt)],
      activities: [],
      objectives: [],
      latest_attempts: [],
      bib_revisions: [],
      historical_attempts: [],
      collab_space_config: build(:collab_space_config),
      is_instructor: false,
      is_student: true,
      effective_settings: %Oli.Delivery.Settings.Combined{}
    }
  end

  def resource_summary_factory() do
    %ResourceSummary{
      num_correct: 5,
      num_attempts: 10
    }
  end

  def certificate_factory() do
    %Certificate{
      title: "#{sequence("certificate")}",
      section: anonymous_build(:section)
    }
  end

  def granted_certificate_factory() do
    %GrantedCertificate{
      guid: UUID.uuid4(),
      user: build(:user),
      certificate: build(:certificate)
    }
  end

  def user_token_factory(attr) do
    token = attr[:non_hashed_token] || :crypto.strong_rand_bytes(32)
    hashed_token = :crypto.hash(:sha256, token)

    user = attr[:user] || insert(:user)

    %UserToken{
      token: hashed_token,
      context: attr[:context] || "session",
      sent_to: user.email,
      user_id: user.id
    }
  end

  # HELPERS

  defp anonymous_build(entity_name, attrs \\ %{}),
    do: fn -> build(entity_name, attrs) end

  defp anonymous_build_list(count, entity_name, attrs \\ %{}),
    do: fn -> build_list(count, entity_name, attrs) end
end
