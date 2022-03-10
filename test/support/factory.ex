defmodule Oli.Factory do
  use ExMachina.Ecto, repo: Oli.Repo

  alias Oli.Accounts.{Author, User}
  alias Oli.Authoring.Course.{Family, Project, ProjectVisibility}
  alias Oli.Branding.Brand
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, PartAttempt, ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.Gating.GatingCondition
  alias Oli.Delivery.Snapshots.Snapshot

  alias Oli.Delivery.Sections.{
    Enrollment,
    Section,
    SectionsProjectsPublications,
    SectionResource,
    SectionInvite
  }

  alias Oli.Delivery.Paywall.Payment
  alias Oli.Groups.{Community, CommunityAccount, CommunityInstitution, CommunityVisibility}
  alias Oli.Institutions.{Institution, SsoJwk}
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
      author: insert(:author),
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
      community: insert(:community),
      user: insert(:user),
      is_admin: false
    }
  end

  def community_account_factory(), do: struct!(community_admin_account_factory())

  def community_admin_account_factory() do
    %CommunityAccount{
      community: insert(:community),
      author: insert(:author),
      is_admin: true
    }
  end

  def community_visibility_factory(), do: struct!(community_project_visibility_factory())

  def community_project_visibility_factory() do
    %CommunityVisibility{
      community: insert(:community),
      project: insert(:project)
    }
  end

  def community_product_visibility_factory() do
    %CommunityVisibility{
      community: insert(:community),
      section: insert(:section)
    }
  end

  def project_factory() do
    %Project{
      description: "Example description",
      title: "Example Course",
      slug: sequence("examplecourse"),
      version: "1",
      family: insert(:family),
      visibility: :global,
      authors: insert_list(2, :author)
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
      project: insert(:project)
    }
  end

  def family_factory() do
    %Family{
      description: "Family description",
      title: "Family title"
    }
  end

  def section_factory() do
    %Section{
      title: "Section",
      timezone: "America/New_York",
      registration_open: true,
      context_id: UUID.uuid4(),
      institution: insert(:institution),
      base_project: insert(:project),
      slug: sequence("examplesection"),
      type: :blueprint,
      open_and_free: false,
      description: "A description",
      brand: insert(:brand)
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
      institution: insert(:institution)
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

  def community_member_account_factory() do
    %CommunityAccount{
      community: insert(:community),
      user: insert(:user),
      is_admin: false
    }
  end

  def community_institution_factory() do
    %CommunityInstitution{
      community: insert(:community),
      institution: insert(:institution)
    }
  end

  def published_resource_factory() do
    %PublishedResource{
      resource: insert(:resource),
      publication: insert(:publication),
      revision: insert(:revision),
      author: insert(:author)
    }
  end

  def section_project_publication_factory() do
    %SectionsProjectsPublications{
      project: insert(:project),
      section: insert(:section),
      publication: insert(:publication)
    }
  end

  def section_resource_factory() do
    %SectionResource{
      project: insert(:project),
      section: insert(:section),
      resource_id: insert(:resource).id
    }
  end

  def revision_factory() do
    %Revision{
      title: "Example revision",
      slug: "example_revision",
      resource: insert(:resource)
    }
  end

  def resource_factory() do
    %Resource{}
  end

  def gating_condition_factory() do
    {:ok, start_date, _timezone} = DateTime.from_iso8601("2019-05-22 20:30:00Z")
    {:ok, end_date, _timezone} = DateTime.from_iso8601("2019-06-24 20:30:00Z")

    %GatingCondition{
      user: insert(:user),
      section: insert(:section),
      resource: insert(:resource),
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
      user: insert(:user),
      section: insert(:section)
    }
  end

  def payment_factory() do
    %Payment{
      type: :direct,
      amount: Money.new(:USD, 25),
      provider_type: :stripe,
      section: insert(:section),
      enrollment: insert(:enrollment)
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
      section: insert(:section),
      slug: sequence("exampleinvite"),
      date_expires: date_expires
    }
  end

  def snapshot_factory() do
    revision = insert(:revision)

    %Snapshot{
      resource: revision.resource,
      activity: revision.resource,
      user: insert(:user),
      section: insert(:section),
      #
      part_attempt: insert(:part_attempt),
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
      activity_attempt: insert(:activity_attempt)
    }
  end

  def activity_attempt_factory() do
    revision = insert(:revision)

    %ActivityAttempt{
      attempt_guid: sequence("guid"),
      attempt_number: sequence("") |> Integer.parse() |> elem(0),
      resource: revision.resource,
      revision: revision,
      resource_attempt: insert(:resource_attempt)
    }
  end

  def resource_attempt_factory() do
    revision = insert(:revision)

    %ResourceAttempt{
      attempt_guid: sequence("guid"),
      attempt_number: sequence("") |> Integer.parse() |> elem(0),
      resource_access: insert(:resource_access),
      revision: revision,
      content: %{}
    }
  end

  def resource_access_factory() do
    %ResourceAccess{
      access_count: sequence("") |> Integer.parse() |> elem(0),
      user: insert(:user),
      section: insert(:section),
      resource: insert(:resource)
    }
  end
end
