defmodule Oli.Inventories do
  import Ecto.Query, warn: false

  alias Ecto.{Changeset, Multi}
  alias Oli.Inventories.Publisher
  alias Oli.{Repo, Utils}

  # ------------------------------------------------------------
  # Publishers

  @doc """
  Returns the list of publishers.

  ## Examples

      iex> list_publishers()
      [%Publisher{}, ...]

  """
  def list_publishers do
    Repo.all(from(p in Publisher, order_by: [desc: :default]))
  end

  @doc """
  Returns the list of publishers that meets the criteria passed in the input.

  ## Examples

      iex> search_publishers(%{available_via_api: true})
      [%Publisher{available_via_api: true}, ...]

      iex> search_publishers(%{available_via_api: false})
      []
  """
  def search_publishers(filter) do
    from(p in Publisher, where: ^Utils.filter_conditions(filter))
    |> Repo.all()
  end

  @doc """
  Creates a publisher.

  ## Examples

      iex> create_publisher(%{field: new_value})
      {:ok, %Publisher{}}

      iex> create_publisher(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_publisher(attrs \\ %{}) do
    %Publisher{}
    |> Publisher.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Finds or creates a publisher.

  ## Examples

      iex> find_or_create_publisher(%{field: value})
      {:ok, %Publisher{}}

      iex> find_or_create_publisher(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def find_or_create_publisher(attrs) do
    case get_publisher_by(%{name: attrs[:name]}) do
      nil ->
        create_publisher(attrs)

      %Publisher{} = publisher ->
        {:ok, publisher}
    end
  end

  @doc """
  Gets the default publisher.

  ## Examples

      iex> default_publisher()
      %Publisher{}
  """
  def default_publisher do
    get_publisher_by(%{default: true})
  end

  @doc """
  Set the default publisher.

  ## Examples

      iex> set_default_publisher(publisher)
      {:ok, %Publisher{}}

      iex> set_default_publisher(publisher)
      {:error, %Ecto.Changeset{}}
  """
  def set_default_publisher(publisher) do
    old_default = Publisher.changeset(default_publisher(), %{default: false})
    new_default = Publisher.changeset(publisher, %{default: true})

    res =
      Multi.new()
      |> Multi.update(:old_default, old_default)
      |> Multi.update(:new_default, new_default)
      |> Repo.transaction()

    case res do
      {:ok, %{new_default: new_default}} ->
        {:ok, new_default}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets a publisher by id.

  ## Examples

      iex> get_publisher(1)
      %Publisher{}
      iex> get_publisher(123)
      nil
  """
  def get_publisher(id), do: Repo.get(Publisher, id)

  @doc """
  Gets a single publisher by query parameter

  ## Examples

      iex> get_publisher_by(%{name: "example"})
      %Publisher{}
      iex> get_publisher_by(%{name: "bad_name"})
      nil
  """
  def get_publisher_by(clauses), do: Repo.get_by(Publisher, clauses)

  @doc """
  Updates a publisher.

  ## Examples

      iex> update_publisher(publisher, %{name: new_value})
      {:ok, %Publisher{}}
      iex> update_publisher(publisher, %{name: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_publisher(%Publisher{} = publisher, attrs) do
    publisher
    |> Publisher.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a publisher.

  ## Examples

      iex> delete_publisher(publisher)
      {:ok, %Publisher{}}

      iex> delete_publisher(publisher)
      {:error, %Ecto.Changeset{}}

  """
  def delete_publisher(%Publisher{default: true} = publisher) do
    changeset =
      publisher
      |> Changeset.change()
      |> Changeset.add_error(:default, "cannot delete the default publisher")

    {:error, changeset}
  end

  def delete_publisher(%Publisher{} = publisher) do
    publisher
    |> Changeset.change()
    |> Changeset.no_assoc_constraint(:projects)
    |> Changeset.no_assoc_constraint(:products)
    |> Repo.delete()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking publisher changes.

  ## Examples

      iex> change_publisher(publisher)
      %Ecto.Changeset{data: %Publisher{}}

  """
  def change_publisher(%Publisher{} = publisher, attrs \\ %{}) do
    Publisher.changeset(publisher, attrs)
  end

  def get_publisher_for_context(%{"section" => %Oli.Delivery.Sections.Section{id: section_id}}) do
    from(s in Oli.Delivery.Sections.Section,
      join: p in Oli.Authoring.Course.Project,
      on: s.base_project_id == p.id,
      join: pub in Oli.Inventories.Publisher,
      on: p.publisher_id == pub.id,
      where: s.id == ^section_id,
      select: pub
    )
    |> Oli.Repo.one() || default_publisher()
  end

  def get_publisher_for_context(%{"project" => %Oli.Authoring.Course.Project{id: project_id}}) do
    from(p in Oli.Inventories.Publisher,
      join: proj in Oli.Authoring.Course.Project,
      on: proj.publisher_id == p.id,
      where: proj.id == ^project_id,
      select: p
    )
    |> Oli.Repo.one() || default_publisher()
  end

  def get_publisher_for_context(_), do: default_publisher()

  @doc """
  Returns the knowledge base link for the given publisher.
  If the publisher has a non-empty knowledge_base_link, it is returned.
  Otherwise, returns the global default from Oli.VendorProperties.knowledgebase_url/0.
  """
  @spec knowledge_base_link_for_publisher(Publisher.t() | nil) :: String.t()
  def knowledge_base_link_for_publisher(%Publisher{knowledge_base_link: kb})
      when is_binary(kb) and kb != "" do
    kb
  end

  def knowledge_base_link_for_publisher(_), do: Oli.VendorProperties.knowledgebase_url()

  @doc """
  Returns the support email for the given publisher.
  If the publisher has a non-empty support_email, it is returned.
  Otherwise, returns the global default from Oli.VendorProperties.support_email/0.
  """
  @spec support_email_for_publisher(Publisher.t() | nil) :: String.t()
  def support_email_for_publisher(%Publisher{support_email: email})
      when is_binary(email) and email != "" do
    email
  end

  def support_email_for_publisher(_), do: Oli.VendorProperties.support_email()
end
