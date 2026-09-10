defmodule Oli.Scenarios.Directives.OwnershipHandler do
  @moduledoc "Resolves explicit release-scenario ownership selectors."

  import Ecto.Query, only: [from: 2]

  alias Oli.Accounts.{Author, SystemRole}
  alias Oli.Institutions.Institution
  alias Oli.Repo
  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, OwnershipDirective}

  def handle(%OwnershipDirective{} = directive, %ExecutionState{} = state) do
    with {:ok, author} <- resolve_author(directive.author, state),
         {:ok, institution} <- resolve_institution(directive.institution, state) do
      {:ok, %{state | current_author: author, current_institution: institution}}
    end
  end

  defp resolve_author("default_admin", _state) do
    configured_or_unique_author(
      Application.get_env(:oli, :preview_qa_tools, [])[:default_admin_email],
      from(a in Author,
        where: a.system_role_id == ^SystemRole.role_id().system_admin and is_nil(a.locked_at)
      ),
      "default_admin"
    )
  end

  defp resolve_author("ref:" <> name, state) do
    case Map.get(state.users, name) do
      %Author{locked_at: nil} = author -> {:ok, author}
      nil -> {:error, "author reference '#{name}' was not created before ownership selection"}
      _ -> {:error, "author reference '#{name}' is inactive or has the wrong type"}
    end
  end

  defp resolve_author("email:" <> email, _state) do
    unique(from(a in Author, where: a.email == ^email and is_nil(a.locked_at)), "author email")
  end

  defp resolve_author(_, _state), do: {:error, "invalid author ownership selector"}

  defp resolve_institution("default_institution", _state) do
    case Application.get_env(:oli, :preview_qa_tools, [])[:default_institution_id] do
      nil ->
        unique(from(i in Institution, where: i.status == :active), "default_institution")

      id ->
        unique(
          from(i in Institution, where: i.id == ^id and i.status == :active),
          "default_institution"
        )
    end
  end

  defp resolve_institution("ref:" <> name, state) do
    case Map.get(state.institutions, name) do
      %Institution{status: :active} = institution ->
        {:ok, institution}

      nil ->
        {:error, "institution reference '#{name}' was not created before ownership selection"}

      _ ->
        {:error, "institution reference '#{name}' is inactive or has the wrong type"}
    end
  end

  defp resolve_institution("id:" <> id, _state) do
    case Integer.parse(id) do
      {id, ""} ->
        unique(
          from(i in Institution, where: i.id == ^id and i.status == :active),
          "institution id"
        )

      _ ->
        {:error, "invalid institution id selector"}
    end
  end

  defp resolve_institution(_, _state), do: {:error, "invalid institution ownership selector"}

  defp configured_or_unique_author(nil, query, label), do: unique(query, label)

  defp configured_or_unique_author(email, _query, label) do
    unique(from(a in Author, where: a.email == ^email and is_nil(a.locked_at)), label)
  end

  defp unique(query, label) do
    case Repo.all(from(record in query, limit: 2)) do
      [record] -> {:ok, record}
      [] -> {:error, "#{label} did not resolve to an active record"}
      _ -> {:error, "#{label} is ambiguous"}
    end
  end
end
