defmodule Oli.Groups do
  @moduledoc """
  The Groups context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}
  alias Oli.Groups.{Community, CommunityAccount, CommunityInstitution, CommunityVisibility}
  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias Oli.Publishing
  alias Oli.Publishing.Publication
  alias Oli.Repo

  # ------------------------------------------------------------
  # Communities

  @doc """
  Returns the list of communities.

  ## Examples

      iex> list_communities()
      [%Community{}, ...]

  """
  def list_communities, do: Repo.all(Community)

  @doc """
  Returns the list of communities that meets the criteria passed in the input.

  ## Examples

      iex> search_communities(%{status: :active})
      [%Community{status: :active}, ...]

      iex> search_communities(%{global_access: false})
      []
  """
  def search_communities(filter) do
    from(c in Community, where: ^filter_conditions(filter))
    |> Repo.all()
  end

  @doc """
  Creates a community.

  ## Examples

      iex> create_community(%{field: new_value})
      {:ok, %Community{}}

      iex> create_community(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_community(attrs \\ %{}) do
    %Community{}
    |> Community.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a community by id.

  ## Examples

      iex> get_community(1)
      %Community{}
      iex> get_community(123)
      nil
  """
  def get_community(id), do: Repo.get_by(Community, %{id: id, status: :active})

  @doc """
  Updates a community.

  ## Examples

      iex> update_community(community, %{name: new_value})
      {:ok, %Community{}}
      iex> update_community(community, %{name: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_community(%Community{} = community, attrs) do
    community
    |> Community.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a community.

  ## Examples

      iex> delete_community(community)
      {:ok, %Community{}}

      iex> delete_community(community)
      {:error, %Ecto.Changeset{}}

  """
  def delete_community(%Community{} = community) do
    update_community(community, %{status: :deleted})
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking community changes.

  ## Examples

      iex> change_community(community)
      %Ecto.Changeset{data: %Community{}}

  """
  def change_community(%Community{} = community, attrs \\ %{}) do
    Community.changeset(community, attrs)
  end

  # ------------------------------------------------------------
  # Communities accounts

  @doc """
  Finds or creates a community account for a user. More efficient than using
  many-to-many assoc.

  ## Examples

      iex> find_or_create_community_user_account(user_id, community_id)
      {:ok, %CommunityAccount{}}

      iex> find_or_create_community_user_account(bad_user_id, community_id)
      {:error, %Ecto.Changeset{}}

  """
  def find_or_create_community_user_account(user_id, community_id) do
    clauses = %{user_id: user_id, community_id: community_id}

    res =
      Multi.new()
      |> Multi.run(:community_account, fn _, _ -> {:ok, get_community_account_by!(clauses)} end)
      |> Multi.run(:new_community_account, &maybe_create_community_account(&1, &2, clauses))
      |> Repo.transaction()

    case res do
      {:ok, %{new_community_account: community_account}} ->
        {:ok, community_account}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  defp maybe_create_community_account(_repo, %{community_account: nil}, clauses),
    do: create_community_account(clauses)

  defp maybe_create_community_account(_repo, %{community_account: community_account}, _clauses),
    do: {:ok, community_account}

  @doc """
  Creates a community account.

  ## Examples

      iex> create_community_account(%{field: new_value})
      {:ok, %CommunityAccount{}}

      iex> create_community_account(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_community_account(attrs \\ %{}) do
    %CommunityAccount{}
    |> CommunityAccount.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a community account from an author email (gets the author first).

  ## Examples

      iex> create_community_account_from_author_email("example@foo.com", %{field: new_value})
      {:ok, %CommunityAccount{}}

      iex> create_community_account_from_author_email("example@foo.com", %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """

  def create_community_account_from_author_email(email, attrs \\ %{}) do
    case Accounts.get_author_by_email(email) do
      %Author{id: id} ->
        attrs |> Map.put(:author_id, id) |> create_community_account()

      nil ->
        {:error, :author_not_found}
    end
  end

  @doc """
  Creates a community account from a user email (gets the user first).

  ## Examples

      iex> create_community_account_from_user_email("example@foo.com", %{field: new_value})
      {:ok, %CommunityAccount{}}

      iex> create_community_account_from_user_email("example@foo.com", %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """

  def create_community_account_from_user_email(email, attrs \\ %{}) do
    case Accounts.get_user_by(%{email: email}) do
      %User{id: id} ->
        attrs |> Map.put(:user_id, id) |> create_community_account()

      nil ->
        {:error, :user_not_found}
    end
  end

  @doc """
  Creates a community account from a user type and email (gets the user first).

  ## Examples

      iex> create_community_account_from_email("admin", "example@foo.com", %{field: new_value})
      {:ok, %CommunityAccount{}}

      iex> create_community_account_from_user_email("member", "example@foo.com", %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """

  def create_community_account_from_email(user_type, email, attrs \\ %{})

  def create_community_account_from_email("admin", email, attrs) do
    create_community_account_from_author_email(email, attrs)
  end

  def create_community_account_from_email("member", email, attrs) do
    create_community_account_from_user_email(email, attrs)
  end

  @doc """
  Creates community accounts from user type and emails.

  ## Examples

      iex> create_community_accounts_from_emails("admin", ["foo@foo.com", "bar@bar.com"], %{field: new_value})
      {:ok, [%CommunityAccount{}, %CommunityAccount{}]}

      iex> create_community_accounts_from_emails("member", ["example@foo.com"], %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """

  def create_community_accounts_from_emails(user_type, emails, attrs),
    do:
      create_community_associations_from_fields(
        emails,
        attrs,
        &create_community_account_from_email(user_type, &1, &2)
      )

  @doc """
  Gets a community account by id.

  ## Examples

      iex> get_community_account(1)
      %CommunityAccount{}
      iex> get_community_account(123)
      nil
  """
  def get_community_account(id), do: Repo.get(CommunityAccount, id)

  @doc """
  Gets a community account by clauses. Will raise an error if
  more than one matches the criteria.

  ## Examples

      iex> get_community_account_by!(%{author_id: 1})
      %CommunityAccount{}
      iex> get_community_account_by!(%{author_id: 123})
      nil
      iex> get_community_account_by!(%{author_id: 2})
      Ecto.MultipleResultsError
  """
  def get_community_account_by!(clauses), do: Repo.get_by(CommunityAccount, clauses)

  @doc """
  Deletes a community account.

  ## Examples

      iex> delete_community_account(%{community_id: 1, author_id: 1})
      {:ok, %CommunityAccount{}}

      iex> delete_community_account(%{community_id: 1, author_id: bad})
      nil

  """
  def delete_community_account(clauses) do
    case get_community_account_by!(clauses) do
      nil -> {:error, :not_found}
      community_account -> Repo.delete(community_account)
    end
  end

  @doc """
  Get all the admins for a specific community.

  ## Examples

      iex> list_community_admins(1)
      {:ok, [%Author{}, ...]}

      iex> list_community_admins(123)
      {:ok, []}
  """
  def list_community_admins(community_id) do
    Repo.all(
      from(
        community_account in CommunityAccount,
        join: author in assoc(community_account, :author),
        where: community_account.community_id == ^community_id and community_account.is_admin,
        select: author
      )
    )
  end

  @doc """
  Get all the members for a specific community.

  ## Examples

      iex> list_community_members(1)
      {:ok, [%User{}, ...]}

      iex> list_community_members(123)
      {:ok, []}
  """
  def list_community_members(community_id, limit \\ nil) do
    Repo.all(
      from(
        community_account in CommunityAccount,
        join: member in assoc(community_account, :user),
        where: community_account.community_id == ^community_id and not community_account.is_admin,
        select: member,
        order_by: [desc: :inserted_at],
        limit: ^limit
      )
    )
  end

  # ------------------------------------------------------------
  # Communities visibilities

  @doc """
  Creates a community visibility.

  ## Examples

      iex> create_community_visibility(%{field: new_value})
      {:ok, %CommunityVisibility{}}

      iex> create_community_visibility(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_community_visibility(attrs \\ %{}) do
    %CommunityVisibility{}
    |> CommunityVisibility.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a community visibility by id.

  ## Examples

      iex> get_community_visibility(1)
      %CommunityVisibility{}
      iex> get_community_visibility(123)
      nil
  """
  def get_community_visibility(id), do: Repo.get(CommunityVisibility, id)

  @doc """
  Deletes a community visibility.

  ## Examples

      iex> delete_community_visibility(%{community_id: 1, project_id: 1})
      {:ok, %CommunityVisibility{}}

      iex> delete_community_visibility(%{community_id: 1, project_id: bad})
      nil

  """
  def delete_community_visibility(id) do
    case get_community_visibility(id) do
      nil -> {:error, :not_found}
      community_visibility -> Repo.delete(community_visibility)
    end
  end

  @doc """
  Get all the projects and products associated within a community in only one query.

  ## Examples

      iex> list_community_visibilities(1)
      {:ok, [%CommunityVisibility{project: %Project{}, section: nil, ...}, ,...]}

      iex> list_community_visibilities(123)
      {:ok, []}
  """
  def list_community_visibilities(community_id) do
    from(
      community_visibility in CommunityVisibility,
      left_join: project in assoc(community_visibility, :project),
      left_join: section in assoc(community_visibility, :section),
      where: community_visibility.community_id == ^community_id,
      select: community_visibility,
      select_merge: %{
        project: project,
        section: section,
        unique_type:
          fragment("case when section_id is not null then 'product' else 'project' end")
      }
    )
    |> Repo.all()
  end

  @doc """
  Get all the communities the user belongs and/or the communities the
  user's institution belongs

  ## Examples

      iex> list_associated_communities(1, %Institution{})
      [%Community{}, ...]

      iex> list_associated_communities(123, %Institution{})
      []
  """
  def list_associated_communities(user_id, institution),
    do: Repo.all(associated_communities_query(user_id, institution))

  @doc """
  Get all the publications associated with:
    - The communities the user belongs
    - The communities the user's institution belongs

  ## Examples

      iex> list_community_associated_publications(1, %Institution{})
      [%Publication{project: %Project{}}, ...]

      iex> list_community_associated_publications(123, %Institution{})
      []
  """
  def list_community_associated_publications(user_id, institution) do
    from(
      community in Community,
      join:
        associated_communities in subquery(associated_communities_query(user_id, institution)),
      on: associated_communities.id == community.id,
      join: community_visibility in CommunityVisibility,
      on: community_visibility.community_id == community.id,
      left_join: project in assoc(community_visibility, :project),
      join: last_publication in subquery(Publishing.last_publication_query()),
      on: last_publication.project_id == project.id,
      join: publication in Publication,
      on: publication.id == last_publication.id,
      select: %{publication | project: project},
      group_by: [project.id, publication.id]
    )
    |> Repo.all()
  end

  @doc """
  Get all the publications and products associated with:
    - The communities the user belongs
    - The communities the user's institution belongs

  ## Examples

      iex> list_community_associated_publications_and_products(1, %Institution{})
      [{%Publication{project: %Project{}}, nil}, {%Publication{}, %Section{}}, ...]

      iex> list_community_associated_publications_and_products(123, %Institution{})
      []
  """
  def list_community_associated_publications_and_products(user_id, institution) do
    from(
      community in Community,
      join:
        associated_communities in subquery(associated_communities_query(user_id, institution)),
      on: associated_communities.id == community.id,
      join: community_visibility in CommunityVisibility,
      on: community_visibility.community_id == community.id,
      left_join: project in assoc(community_visibility, :project),
      left_join: section in assoc(community_visibility, :section),
      join: last_publication in subquery(Publishing.last_publication_query()),
      on:
        last_publication.project_id == project.id or
          last_publication.project_id == section.base_project_id,
      join: publication in Publication,
      on: publication.id == last_publication.id,
      select:
        {%{
           publication
           | project: project
         }, section},
      distinct: true
    )
    |> Repo.all()
  end

  defp associated_communities_query(user_id, institution) do
    user_communities_query =
      from community in Community,
        join: community_account in CommunityAccount,
        on:
          community.id == community_account.community_id and community_account.user_id == ^user_id,
        select: community

    case institution do
      nil ->
        user_communities_query

      %Institution{id: institution_id} ->
        institution_communities_query =
          from community in Community,
            join: community_institution in CommunityInstitution,
            on:
              community.id == community_institution.community_id and
                community_institution.institution_id == ^institution_id,
            select: community

        from user_communities_query,
          union: ^institution_communities_query,
          distinct: true
    end
  end

  # ------------------------------------------------------------
  # Communities institutions

  @doc """
  Get all the institutions for a specific community.

  ## Examples

      iex> list_community_institutions(1)
      {:ok, [%Institution{}, ...]}

      iex> list_community_institutions(123)
      {:ok, []}
  """
  def list_community_institutions(community_id) do
    Repo.all(
      from(
        community_institution in CommunityInstitution,
        join: institution in assoc(community_institution, :institution),
        where: community_institution.community_id == ^community_id,
        select: institution
      )
    )
  end

  @doc """
  Creates a community institution.

  ## Examples

      iex> create_community_institution(%{community_id: 1, institution_id: 2})
      {:ok, %CommunityInstitution{}}

      iex> create_community_institution(%{community_id: 1, institution_id: bad_institution})
      {:error, %Ecto.Changeset{}}

  """
  def create_community_institution(attrs) do
    %CommunityInstitution{}
    |> CommunityInstitution.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a community institution from an institution name (gets the institution first).

  ## Examples

      iex> create_community_institution_from_institution_name("My institution", %{community_id: 1})
      {:ok, %CommunityInstitution{}}

      iex> create_community_institution_from_institution_name("Bad institution", %{community_id: 1})
      {:error, :institution_not_found}

  """

  def create_community_institution_from_institution_name(institution_name, attrs \\ %{}) do
    case Institutions.get_institution_by!(%{name: institution_name}) do
      %Institution{id: id} ->
        attrs |> Map.put(:institution_id, id) |> create_community_institution()

      nil ->
        {:error, :institution_not_found}
    end
  end

  @doc """
  Creates community institutions from names.
  ## Examples
      iex> create_community_institutions_from_names(["Institution 1", "Institution 2"], %{community_id: 1})
      {:ok, [%CommunityInstitution{}, %CommunityInstitution{}]}
      iex> create_community_institutions_from_names(["Institution 1", "Institution 2"], %{community_id: bad_value})
      {:error, %Ecto.Changeset{}}
  """

  def create_community_institutions_from_names(names, attrs),
    do:
      create_community_associations_from_fields(
        names,
        attrs,
        &create_community_institution_from_institution_name/2
      )

  @doc """
  Gets a community institution by clauses. Will raise an error if
  more than one matches the criteria.

  ## Examples

      iex> get_community_institution_by!(%{community_id: 1, institution_id: 3})
      %CommunityInstitution{}
      iex> get_community_institution_by!(%{community_id: 123})
      nil
      iex> get_community_institution_by!(%{community_id: 2})
      Ecto.MultipleResultsError
  """
  def get_community_institution_by!(clauses), do: Repo.get_by(CommunityInstitution, clauses)

  @doc """
  Deletes a community institution.

  ## Examples

      iex> delete_community_institution(%{community_id: 1, institution_id: 1})
      {:ok, %CommunityInstitution{}}

      iex> delete_community_institution(%{community_id: 1, institution_id: bad})
      {:error, :not_found}

  """
  def delete_community_institution(clauses) do
    case get_community_institution_by!(clauses) do
      nil -> {:error, :not_found}
      community_institution -> Repo.delete(community_institution)
    end
  end

  # ------------------------------------------------------------

  defp filter_conditions(filter) do
    Enum.reduce(filter, false, fn {field, value}, conditions ->
      dynamic([entity], field(entity, ^field) == ^value or ^conditions)
    end)
  end

  defp create_community_associations_from_fields(fields, attrs, create_association) do
    {created_community_associations, errors} =
      Enum.reduce(fields, {[], []}, fn field, {created, errors} ->
        case create_association.(field, attrs) do
          {:ok, community_association} ->
            {[community_association | created], errors}

          {:error, error} ->
            {created, [error | errors]}
        end
      end)

    case errors do
      [error | _errors] ->
        {:error, error}

      [] ->
        {:ok, created_community_associations}
    end
  end
end
