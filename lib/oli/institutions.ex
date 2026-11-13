defmodule Oli.Institutions do
  @moduledoc """
  The Institutions context.
  """

  import Ecto.Query, warn: false

  require Logger

  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}

  alias Oli.Institutions.{Institution, PendingRegistration, RegistrationBrowseOptions, SsoJwk}
  alias Oli.Lti.Tool.Registration
  alias Oli.Lti.Tool.Deployment
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.EnrollmentContextRole

  @doc """
  Returns the list of institutions.
  ## Examples
      iex> list_institutions()
      [%Institution{}, ...]
  """
  def list_institutions do
    from(i in Institution,
      where: i.status != :deleted
    )
    |> Repo.all()
  end

  @doc """
  Gets a single institution.
  Raises `Ecto.NoResultsError` if the Institution does not exist.
  ## Examples
      iex> get_institution!(123)
      %Institution{}
      iex> get_institution!(456)
      ** (Ecto.NoResultsError)
  """
  def get_institution!(id),
    do: Repo.get!(Institution, id) |> Repo.preload([:deployments, :default_brand])

  def get_students_by_institution(institution_id, text_search, limit, offset) do
    student_role_id = Lti_1p3.Roles.ContextRoles.get_role(:context_learner).id

    filter_by_text =
      if text_search in ["", nil] do
        true
      else
        text_search = String.trim(text_search)

        dynamic(
          [_e, _s, u],
          ilike(u.name, ^"%#{text_search}%") or
            ilike(u.email, ^"%#{text_search}%") or
            ilike(u.given_name, ^"%#{text_search}%") or
            ilike(u.family_name, ^"%#{text_search}%")
        )
      end

    from(e in Enrollment,
      join: s in Section,
      on: e.section_id == s.id,
      join: u in User,
      on: e.user_id == u.id,
      join: ecr in EnrollmentContextRole,
      on: e.id == ecr.enrollment_id,
      where:
        s.institution_id == ^institution_id and s.status == :active and e.status == :enrolled and
          ecr.context_role_id == ^student_role_id,
      where: ^filter_by_text,
      limit: ^limit,
      offset: ^offset,
      group_by: u.id,
      order_by: u.id,
      select: u,
      select_merge: %{total_count: fragment("count(*) OVER()")}
    )
    |> Repo.all()
    |> Repo.preload(:author)
  end

  @doc """
  Returns the institution that an LTI user is associated with.
  """
  def get_institution_by_lti_user(user) do
    # using enrollment records, we can infer the user's institution. This is because
    # an LTI user can be enrolled in multiple sections, but all sections must be from
    # the same institution.
    from(e in Enrollment,
      join: s in Section,
      on: e.section_id == s.id,
      join: u in User,
      on: e.user_id == u.id,
      join: institution in Institution,
      on: s.institution_id == institution.id,
      where: u.id == ^user.id and s.status == :active and e.status == :enrolled,
      limit: 1,
      select: institution
    )
    |> Repo.all()
    |> List.first()
  end

  @doc """
  Gets an institution by clauses. Will raise an error if
  more than one matches the criteria.

  ## Examples

      iex> get_institution_by!(%{name: "My institution"})
      %Institution{}
      iex> get_institution_by!(%{name: "bad name"})
      nil
      iex> get_institution_by!(%{country_code: "US"})
      Ecto.MultipleResultsError
  """
  def get_institution_by!(clauses), do: Repo.get_by(Institution, clauses)

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking institution changes.
  ## Examples
      iex> change_institution(institution)
      %Ecto.Changeset{source: %Institution{}}
  """
  def change_institution(%Institution{} = institution) do
    Institution.changeset(institution, %{})
  end

  @doc """
  Returns the list of registrations.

  ## Examples

      iex> list_registrations()
      [%Registration{}, ...]

  """
  def list_registrations(opts \\ []) do
    preload = Keyword.get(opts, :preload, [])

    Repo.all(Registration) |> Repo.preload(preload)
  end

  @doc """
  Gets a single registration.

  Raises if the Registration does not exist.

  ## Examples

      iex> get_registration!(123)
      %Registration{}

  """
  def get_registration!(id), do: Repo.get!(Registration, id)

  @doc """
  Gets a single registration with preloaded associations.

  Raises if the Registration does not exist.

  ## Examples

      iex> get_registration_preloaded!(123)
      %Registration{}

  """
  def get_registration_preloaded!(id) do
    from(r in Registration,
      left_join: d in assoc(r, :deployments),
      where: r.id == ^id,
      preload: [deployments: d]
    )
    |> Repo.one!()
  end

  @doc """
  Returns a data structure for tracking registration changes.

  ## Examples

      iex> change_registration(registration)
      %Todo{...}

  """
  def change_registration(%Registration{} = registration, _attrs \\ %{}) do
    Registration.changeset(registration, %{})
  end

  def browse_registrations(
        %Paging{limit: limit, offset: offset},
        %Sorting{field: field, direction: direction},
        %RegistrationBrowseOptions{} = options
      ) do
    filter_by_text =
      if options.text_search == "" or is_nil(options.text_search) do
        true
      else
        text_search = String.trim(options.text_search)

        dynamic(
          [s, d],
          ilike(s.issuer, ^"%#{text_search}%") or
            ilike(s.client_id, ^"%#{text_search}%") or
            ilike(s.key_set_url, ^"%#{text_search}%") or
            ilike(s.auth_token_url, ^"%#{text_search}%") or
            ilike(s.auth_login_url, ^"%#{text_search}%") or
            ilike(s.auth_server, ^"%#{text_search}%") or
            ilike(d.deployment_id, ^"%#{text_search}%")
        )
      end

    query =
      Registration
      |> join(:left, [r], d in Oli.Lti.Tool.Deployment, on: r.id == d.registration_id)
      |> where(^filter_by_text)
      |> limit(^limit)
      |> offset(^offset)
      |> group_by([r, _], r.id)
      |> select_merge([r, d], %{
        deployments_count: count(d.registration_id),
        total_count: fragment("count(*) OVER()")
      })

    query =
      case field do
        :deployments_count -> order_by(query, [_, d], {^direction, count(d.registration_id)})
        _ -> order_by(query, [r, _], {^direction, field(r, ^field)})
      end

    Repo.all(query)
  end

  @doc """
  Returns the list of deployments.

  ## Examples

      iex> list_deployments()
      [%Deployment{}, ...]

  """
  def list_deployments do
    Repo.all(Deployment)
  end

  @doc """
  Gets a single deployment.

  Raises if the Deployment does not exist.

  ## Examples

      iex> get_deployment!(123)
      %Deployment{}

  """
  def get_deployment!(id), do: Repo.get!(Deployment, id)

  @doc """
  Returns true if the institution with a given id has any associated deployments
  """
  def institution_has_deployments?(institution_id) do
    count =
      from(d in Deployment, where: d.institution_id == ^institution_id)
      |> Repo.aggregate(:count)

    if count > 0 do
      true
    else
      false
    end
  end

  @doc """
  Returns true if the institution with a given id has any associated deployments
  """
  def institution_has_communities?(institution_id) do
    count =
      from(c in Oli.Groups.CommunityInstitution, where: c.institution_id == ^institution_id)
      |> Repo.aggregate(:count)

    if count > 0 do
      true
    else
      false
    end
  end

  @doc """
  Returns a data structure for tracking deployment changes.

  ## Examples

      iex> change_deployment(deployment)
      %Todo{...}

  """
  def change_deployment(%Deployment{} = deployment, _attrs \\ %{}) do
    Deployment.changeset(deployment, %{})
  end

  def get_registration_by_issuer_client_id(issuer, client_id) do
    Repo.one(
      from(registration in Registration,
        where: registration.issuer == ^issuer and registration.client_id == ^client_id,
        select: registration
      )
    )
  end

  @doc """
  Returns the list of pending_registrations.
  ## Examples
      iex> list_pending_registrations()
      [%PendingRegistration{}, ...]
  """
  def list_pending_registrations do
    Repo.all(PendingRegistration)
  end

  @doc """
  Returns the count of pending_registrations.
  ## Examples
      iex> count_pending_registrations()
      123
  """
  def count_pending_registrations do
    Repo.aggregate(PendingRegistration, :count)
  end

  @doc """
  Gets a single pending_registration.
  Raises `Ecto.NoResultsError` if the PendingRegistration does not exist.
  ## Examples
      iex> get_pending_registration!(123)
      %PendingRegistration{}
      iex> get_pending_registration!(456)
      ** (Ecto.NoResultsError)
  """
  def get_pending_registration!(id), do: Repo.get!(PendingRegistration, id)

  @doc """
  Gets a single pending_registration by the issuer, client_id and deployment_id.
  Returns nil if the PendingRegistration does not exist.
  ## Examples
      iex> get_pending_registration(issuer, client_id, deployment_id)
      %PendingRegistration{}
      iex> get_pending_registration(issuer, client_id, deployment_id)
      nil
  """
  def get_pending_registration(issuer, client_id, nil) do
    Repo.one(
      from(pr in PendingRegistration,
        where: pr.issuer == ^issuer and pr.client_id == ^client_id,
        select: pr
      )
    )
  end

  def get_pending_registration(issuer, client_id, deployment_id) do
    Repo.one(
      from(pr in PendingRegistration,
        where:
          pr.issuer == ^issuer and pr.client_id == ^client_id and
            pr.deployment_id == ^deployment_id,
        select: pr
      )
    )
  end

  @doc """
  Creates a pending_registration.
  ## Examples
      iex> create_pending_registration(%{field: value})
      {:ok, %PendingRegistration{}}
      iex> create_pending_registration(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_pending_registration(attrs \\ %{}) do
    %PendingRegistration{}
    |> PendingRegistration.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a pending_registration.
  ## Examples
      iex> update_pending_registration(pending_registration, %{field: new_value})
      {:ok, %PendingRegistration{}}
      iex> update_pending_registration(pending_registration, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_pending_registration(%PendingRegistration{} = pending_registration, attrs) do
    pending_registration
    |> PendingRegistration.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking pending_registration changes.
  ## Examples
      iex> change_pending_registration(pending_registration)
      %Ecto.Changeset{source: %PendingRegistration{}}
  """
  def change_pending_registration(%PendingRegistration{} = pending_registration) do
    PendingRegistration.changeset(pending_registration, %{})
  end

  @doc """
  Returns the first active institution whose URL matches `institution_url` after normalizing
  case, scheme, and trailing slash, or `nil` when none does.
  """
  def find_active_institution_by_normalized_url(institution_url) do
    normalized_url =
      institution_url
      |> String.downcase()
      |> String.replace(~r/^https?\:\/\//i, "")
      |> String.replace_trailing("/", "")

    Repo.one(
      from(i in Institution,
        where: ilike(i.institution_url, ^normalized_url) and i.status != :deleted,
        order_by: i.id,
        limit: 1
      )
    )
  end

  @doc """
  Returns an institution, registration and deployment from a given deployment_id
  ## Examples
      iex> get_institution_registration_deployment("some-issuer", "some-client-id", "some-deployment-id")
      {%Institution{}, %Registration{}, %Deployment{}}
      iex> get_institution_registration_deployment("some-issuer", "some-client-id", "some-deployment-id")
      nil
  """
  def get_institution_registration_deployment(issuer, client_id, deployment_id) do
    from(d in Deployment,
      join: r in Registration,
      on: r.id == d.registration_id,
      join: i in Institution,
      on: i.id == d.institution_id,
      where:
        r.issuer == ^issuer and r.client_id == ^client_id and
          d.deployment_id == ^deployment_id,
      select: {i, r, d},
      limit: 2
    )
    |> Repo.all()
    |> case do
      [institution_registration_deployment] ->
        institution_registration_deployment

      [] ->
        nil

      [_ | _] ->
        # The schema does not declare this identity unique, so an ambiguous one names no
        # deployment rather than raising out of whatever is asking.
        Logger.warning(
          "More than one LTI deployment matches issuer #{inspect(issuer)}, client #{inspect(client_id)} and deployment #{inspect(deployment_id)}"
        )

        nil
    end
  end

  @doc """
  Searches for a list of Institution with an name matching a wildcard pattern
  """
  def search_institutions_matching(query) do
    q = query
    q = "%" <> q <> "%"

    Repo.all(
      from(i in Institution,
        where: ilike(i.name, ^q) and i.status != :deleted
      )
    )
  end

  @doc """
  Gets a JWK by clauses. Will raise an error if
  more than one matches the criteria.

  ## Examples

      iex> get_jwk_by(%{kid: "123"})
      %SsoJwk{}
      iex> get_jwk_by(%{kid: "bad_kid"})
      nil
      iex> get_jwk_by(%{alg: "HS256"})
      Ecto.MultipleResultsError
  """
  def get_jwk_by(clauses), do: Repo.get_by(SsoJwk, clauses)

  @doc """
  Inserts a list of JWK.

  ## Examples

      iex> insert_bulk_jwks([%{...}, %{...}])
      [%SsoJwk{}, %SsoJwk{}]
  """
  def insert_bulk_jwks(sso_jwks) do
    Enum.map(sso_jwks, fn attrs ->
      %SsoJwk{}
      |> SsoJwk.changeset(attrs)
      |> Repo.insert()
      |> elem(1)
    end)
  end

  @doc """
  Builds a JWK map.

  ## Examples

      iex> build_jwk(key)
      %{typ: "JWT", alg: "RS256", kid: "123", pem: "something"}
  """
  def build_jwk({_, _, _, %{"kid" => kid, "alg" => alg}} = key) do
    {_, pem} = JOSE.JWK.to_pem(key)

    %{typ: "JWT", alg: alg, kid: kid, pem: pem}
  end
end
