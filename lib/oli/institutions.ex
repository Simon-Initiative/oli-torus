defmodule Oli.Institutions do
  @moduledoc """
  The Institutions context.
  """

  import Ecto.Query, warn: false

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
  Creates a institution.
  ## Examples
      iex> create_institution(%{field: value})
      {:ok, %Institution{}}
      iex> create_institution(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_institution(attrs \\ %{}) do
    %Institution{}
    |> Institution.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a institution.
  ## Examples
      iex> update_institution(institution, %{field: new_value})
      {:ok, %Institution{}}
      iex> update_institution(institution, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_institution(%Institution{} = institution, attrs) do
    institution
    |> Institution.changeset(attrs)
    |> Repo.update()
  end

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
  Creates a registration.

  ## Examples

      iex> create_registration(%{field: value})
      {:ok, %Registration{}}

      iex> create_registration(%{field: bad_value})
      {:error, ...}

  """
  def create_registration(attrs \\ %{}) do
    %Registration{}
    |> Registration.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns a registration if one exists with the given params, otherwise creates a new one.

  ## Examples

      iex> find_or_create_registration(%{field: value})
      {:ok, %Registration{}}
  """
  def find_or_create_registration(%{issuer: issuer, client_id: client_id} = registration_attrs) do
    case Repo.one(
           from(r in Registration,
             where:
               r.issuer == ^issuer and
                 r.client_id == ^client_id,
             select: r
           )
         ) do
      nil -> create_registration(registration_attrs)
      registration -> {:ok, registration}
    end
  end

  @doc """
  Updates a registration.

  ## Examples

      iex> update_registration(registration, %{field: new_value})
      {:ok, %Registration{}}

      iex> update_registration(registration, %{field: bad_value})
      {:error, ...}

  """
  def update_registration(%Registration{} = registration, attrs) do
    registration
    |> Registration.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Registration.

  ## Examples

      iex> delete_registration(registration)
      {:ok, %Registration{}}

      iex> delete_registration(registration)
      {:error, ...}

  """
  def delete_registration(%Registration{} = registration) do
    Repo.delete(registration)
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
  Creates a deployment.

  ## Examples

      iex> create_deployment(%{field: value})
      {:ok, %Deployment{}}

      iex> create_deployment(%{field: bad_value})
      {:error, ...}

  """
  def create_deployment(attrs \\ %{}) do
    %Deployment{}
    |> Deployment.changeset(attrs)
    |> Repo.insert()
  end

  def maybe_create_deployment(%{deployment_id: nil}), do: {:ok, nil}
  def maybe_create_deployment(%{deployment_id: _} = attrs), do: create_deployment(attrs)

  @doc """
  Updates a deployment.

  ## Examples

      iex> update_deployment(deployment, %{field: new_value})
      {:ok, %Deployment{}}

      iex> update_deployment(deployment, %{field: bad_value})
      {:error, ...}

  """
  def update_deployment(%Deployment{} = deployment, attrs) do
    deployment
    |> Deployment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Deployment.

  ## Examples

      iex> delete_deployment(deployment)
      {:ok, %Deployment{}}

      iex> delete_deployment(deployment)
      {:error, ...}

  """
  def delete_deployment(%Deployment{} = deployment) do
    Repo.delete(deployment)
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
  Deletes a pending_registration.
  ## Examples
      iex> delete_pending_registration(pending_registration)
      {:ok, %PendingRegistration{}}
      iex> delete_pending_registration(pending_registration)
      {:error, %Ecto.Changeset{}}
  """
  def delete_pending_registration(%PendingRegistration{} = pending_registration) do
    Repo.delete(pending_registration)
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

  @doc false
  # Returns the institution that has a similar (normalized) url. If no institutions a similar url
  # exist, then a new one is created. If more than one institution with a similar url exist, then
  # the first institution in the result is returned.
  #
  # ## Examples
  #     iex> find_or_create_institution_by_normalized_url(institution_attrs)
  #     {:ok, %Institution{}}
  def find_or_create_institution_by_normalized_url(institution_attrs) do
    normalized_url =
      institution_attrs[:institution_url]
      |> String.downcase()
      |> String.replace(~r/^https?\:\/\//i, "")
      |> String.replace_trailing("/", "")

    case Repo.all(
           from(i in Institution,
             where:
               ilike(i.institution_url, ^normalized_url) and
                 i.status != :deleted,
             select: i,
             order_by: i.id
           )
         ) do
      [] -> create_institution(institution_attrs)
      [institution] -> {:ok, institution}
      [institution | _] -> {:ok, institution}
    end
  end

  @doc """
  Approves a pending registration request. If successful, a new deployment will be created and attached
  to a new or existing institution if one with a similar url already exists.

  The operation guarantees all actions or none are performed.

  ## Examples
      iex> approve_pending_registration(pending_registration)
      {:ok, {%Institution{}, %Registration{}}}
      iex> approve_pending_registration(pending_registration)
      {:error, reason}
  """
  def approve_pending_registration(%PendingRegistration{} = pending_registration) do
    Repo.transaction(fn ->
      with {:ok, institution} <-
             find_or_create_institution_by_normalized_url(
               PendingRegistration.institution_attrs(pending_registration)
             ),
           {:ok, active_jwk} = Lti_1p3.get_active_jwk(),
           registration_attrs =
             Map.merge(PendingRegistration.registration_attrs(pending_registration), %{
               institution_id: institution.id,
               tool_jwk_id: active_jwk.id
             }),
           {:ok, registration} <- find_or_create_registration(registration_attrs),
           deployment_attrs =
             Map.merge(PendingRegistration.deployment_attrs(pending_registration), %{
               institution_id: institution.id,
               registration_id: registration.id
             }),
           {:ok, deployment} <- maybe_create_deployment(deployment_attrs),
           {:ok, _pending_registration} <- delete_pending_registration(pending_registration) do
        {institution, registration, deployment}
      else
        error -> Repo.rollback(error)
      end
    end)
  end

  @doc """
  Approves a pending registration request. If successful, a new deployment will be created and attached
  to a the required new institution.

  The operation guarantees all actions or none are performed.

  ## Examples
      iex> approve_pending_registration_as_new_institution(pending_registration)
      {:ok, {%Institution{}, %Registration{}, %Deployment{}}}
      iex> approve_pending_registration_as_new_institution(pending_registration)
      {:error, reason}
  """

  def approve_pending_registration_as_new_institution(
        %PendingRegistration{} = pending_registration
      ) do
    Repo.transaction(fn ->
      with {:ok, institution} <-
             create_institution(PendingRegistration.institution_attrs(pending_registration)),
           {:ok, active_jwk} <- Lti_1p3.get_active_jwk(),
           registration_attrs =
             Map.merge(PendingRegistration.registration_attrs(pending_registration), %{
               institution_id: institution.id,
               tool_jwk_id: active_jwk.id
             }),
           {:ok, registration} <- find_or_create_registration(registration_attrs),
           deployment_attrs =
             Map.merge(PendingRegistration.deployment_attrs(pending_registration), %{
               institution_id: institution.id,
               registration_id: registration.id
             }),
           {:ok, deployment} <- create_deployment(deployment_attrs),
           {:ok, _pending_registration} <- delete_pending_registration(pending_registration) do
        {institution, registration, deployment}
      else
        error -> Repo.rollback(error)
      end
    end)
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
    Repo.one(
      from(d in Deployment,
        join: r in Registration,
        on: r.id == d.registration_id,
        join: i in Institution,
        on: i.id == d.institution_id,
        where:
          r.issuer == ^issuer and r.client_id == ^client_id and
            d.deployment_id == ^deployment_id,
        select: {i, r, d}
      )
    )
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
