defmodule Oli.Dashboard.ScopeResolver do
  @moduledoc """
  Resolves and validates dashboard scope selections against context and authorization.

  Shared scope resolution lives in `Oli.Dashboard.*` and intentionally remains
  product-agnostic. Product-specific registries can reuse this module by passing
  dashboard context and user inputs.
  """

  alias Oli.Accounts.User
  alias Oli.Dashboard.Scope
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Repo

  @type dashboard_context_type :: :section | :project
  @type dashboard_context :: %{type: dashboard_context_type(), id: pos_integer()}
  @type error ::
          {:invalid_scope_context, term()}
          | {:unauthorized_scope, term()}
          | Scope.error()

  @doc """
  Resolve and validate a scope input for a dashboard context and user.
  """
  @spec resolve(Scope.input(), map() | keyword()) :: {:ok, Scope.t()} | {:error, error()}
  def resolve(scope_input, opts \\ []) do
    with {:ok, dashboard_context} <- dashboard_context_from_opts(opts),
         {:ok, user} <- user_from_opts(opts),
         :ok <- authorize_context(user, dashboard_context, opts),
         {:ok, scope} <- Scope.new(scope_input),
         :ok <- validate_container(scope, dashboard_context, opts) do
      {:ok, scope}
    end
  end

  @doc """
  Resolve and validate default course scope for a dashboard context and user.
  """
  @spec resolve_default(map() | keyword()) :: {:ok, Scope.t()} | {:error, error()}
  def resolve_default(opts \\ []), do: resolve(%{}, opts)

  @doc """
  Validate container scope selection against the provided context.
  """
  @spec validate_container(Scope.t(), map() | keyword()) :: :ok | {:error, error()}
  def validate_container(%Scope{} = scope, opts) do
    with {:ok, dashboard_context} <- dashboard_context_from_opts(opts) do
      validate_container(scope, dashboard_context, opts)
    end
  end

  defp validate_container(%Scope{} = scope, dashboard_context, opts) do
    case Scope.course_scope?(scope) do
      true -> :ok
      false -> validate_non_course_container(scope, dashboard_context, opts)
    end
  end

  defp validate_non_course_container(
         %Scope{container_type: :container, container_id: container_id},
         %{type: :section, id: section_id},
         opts
       ) do
    container_ids = available_container_ids(section_id, opts)

    if MapSet.member?(container_ids, container_id) do
      :ok
    else
      {:error, {:invalid_scope, {:unknown_container, container_id}}}
    end
  end

  defp validate_non_course_container(
         %Scope{container_type: :container},
         %{type: context_type},
         _opts
       ) do
    {:error, {:invalid_scope_context, {:unsupported_container_context, context_type}}}
  end

  defp available_container_ids(section_id, opts) do
    loader = Map.get(to_map(opts), :container_ids_loader, &default_container_ids_loader/1)

    loader.(section_id)
    |> MapSet.new()
  end

  defp default_container_ids_loader(section_id) do
    SectionResourceDepot.containers(section_id, hidden: false)
    |> Enum.map(& &1.resource_id)
  end

  defp authorize_context(%User{} = user, %{type: :section, id: section_id}, opts) do
    with {:ok, section} <- fetch_section(section_id, opts) do
      authorize_section(user, section, opts)
    end
  end

  defp authorize_context(_user, %{type: :project}, _opts) do
    {:error, {:unauthorized_scope, {:unsupported_context_type, :project}}}
  end

  defp fetch_section(section_id, opts) do
    fetcher = Map.get(to_map(opts), :section_fetcher, &default_section_fetcher/1)

    case fetcher.(section_id) do
      nil -> {:error, {:invalid_scope_context, {:unknown_section, section_id}}}
      section -> {:ok, section}
    end
  end

  defp default_section_fetcher(section_id), do: Sections.get_section_by(id: section_id)

  defp authorize_section(user, section, opts) do
    authorizer = Map.get(to_map(opts), :section_authorizer, &default_section_authorizer/2)

    if authorizer.(user, section) do
      :ok
    else
      {:error, {:unauthorized_scope, :section_access_denied}}
    end
  end

  defp default_section_authorizer(%User{} = user, section) do
    case Sections.is_instructor?(user, section.slug) do
      true ->
        true

      false ->
        user
        |> Repo.preload(:platform_roles)
        |> Sections.is_admin?(section.slug)
    end
  end

  defp user_from_opts(opts) do
    case fetch(to_map(opts), :user) do
      %User{} = user ->
        {:ok, user}

      nil ->
        {:error, {:unauthorized_scope, :missing_user}}

      other ->
        {:error, {:unauthorized_scope, {:invalid_user, other}}}
    end
  end

  defp dashboard_context_from_opts(opts) do
    opts = to_map(opts)

    case fetch(opts, :dashboard_context) do
      nil -> normalize_dashboard_context(opts)
      dashboard_context -> normalize_dashboard_context(dashboard_context)
    end
  end

  defp normalize_dashboard_context(context) when is_list(context),
    do: normalize_dashboard_context(Map.new(context))

  defp normalize_dashboard_context(context) when is_map(context) do
    type = fetch(context, :type) || fetch(context, :dashboard_context_type)
    id = fetch(context, :id) || fetch(context, :dashboard_context_id)

    with {:ok, normalized_type} <- normalize_context_type(type),
         {:ok, normalized_id} <- normalize_positive_integer(id, :dashboard_context_id) do
      {:ok, %{type: normalized_type, id: normalized_id}}
    end
  end

  defp normalize_dashboard_context(_context) do
    {:error, {:invalid_scope_context, :invalid_dashboard_context}}
  end

  defp normalize_context_type(:section), do: {:ok, :section}
  defp normalize_context_type(:project), do: {:ok, :project}
  defp normalize_context_type("section"), do: {:ok, :section}
  defp normalize_context_type("project"), do: {:ok, :project}

  defp normalize_context_type(other),
    do: {:error, {:invalid_scope_context, {:unsupported_context_type, other}}}

  defp normalize_positive_integer(value, _field) when is_integer(value) and value > 0,
    do: {:ok, value}

  defp normalize_positive_integer(value, field) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} when parsed > 0 -> {:ok, parsed}
      _ -> {:error, {:invalid_scope_context, {:invalid_positive_integer, field, value}}}
    end
  end

  defp normalize_positive_integer(value, field) do
    {:error, {:invalid_scope_context, {:invalid_positive_integer, field, value}}}
  end

  defp to_map(opts) when is_list(opts), do: Map.new(opts)
  defp to_map(opts) when is_map(opts), do: opts

  defp fetch(map, key) do
    case Map.get(map, key) do
      nil -> Map.get(map, Atom.to_string(key))
      value -> value
    end
  end
end
