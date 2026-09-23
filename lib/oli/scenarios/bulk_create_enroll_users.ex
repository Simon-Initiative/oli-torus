defmodule Oli.Scenarios.BulkCreateEnrollUsers do
  @moduledoc "Creates retry-stable synthetic users and enrolls them through delivery contexts."

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections
  alias Oli.Repo
  alias Oli.Utils.DataGenerators.NameGenerator

  import Ecto.Query

  @insert_batch_size 500

  @spec create_and_enroll(Oli.Delivery.Sections.Section.t(), map()) ::
          {:ok, %{String.t() => User.t()}, map()} | {:error, term()}
  def create_and_enroll(section, directive) do
    specs =
      user_specs(directive.prefix, :instructor, directive.instructors) ++
        user_specs(directive.prefix, :learner, directive.learners)

    with {:ok, existing, missing} <- partition_existing(specs),
         :ok <- insert_missing(missing),
         users_by_email <- fetch_users(specs),
         :ok <- enroll_by_role(specs, users_by_email, section) do
      users = Map.new(specs, &{&1.reference, Map.fetch!(users_by_email, &1.email)})

      {:ok, users,
       %{created: length(missing), reused: map_size(existing), enrolled: length(specs)}}
    end
  end

  defp user_specs(_prefix, _role, 0), do: []

  defp user_specs(prefix, role, count) do
    role_name = Atom.to_string(role)

    for index <- 1..count do
      reference = "#{prefix}_#{role_name}_#{index}"

      %{
        reference: reference,
        role: role,
        email: "#{reference}@example.edu",
        sub: "scenario:#{reference}",
        given_name: NameGenerator.first_name(),
        family_name: NameGenerator.last_name()
      }
    end
  end

  defp partition_existing(specs) do
    existing = fetch_users(specs)

    case Enum.find(specs, fn spec ->
           case Map.get(existing, spec.email) do
             nil -> false
             %User{sub: sub} -> sub != spec.sub
           end
         end) do
      nil ->
        missing = Enum.reject(specs, &Map.has_key?(existing, &1.email))
        {:ok, existing, missing}

      spec ->
        {:error, {spec.reference, :identity_collision}}
    end
  end

  defp fetch_users([]), do: %{}

  defp fetch_users(specs) do
    emails = Enum.map(specs, & &1.email)

    User
    |> where([user], user.email in ^emails)
    |> Repo.all()
    |> Map.new(&{&1.email, &1})
  end

  defp insert_missing([]), do: :ok

  defp insert_missing(specs) do
    with {:ok, users} <- build_users(specs) do
      users
      |> Enum.map(&insert_attrs/1)
      |> Enum.chunk_every(@insert_batch_size)
      |> Enum.reduce(0, fn batch, count ->
        {inserted, _} = Repo.insert_all(User, batch)
        count + inserted
      end)
      |> case do
        count when count == length(specs) -> :ok
        count -> {:error, {:unexpected_insert_count, count}}
      end
    end
  rescue
    exception -> {:error, {:user_insert_failed, exception.__struct__}}
  end

  defp build_users(specs) do
    specs
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {spec, index}, {:ok, users} ->
      attrs = %{
        guest: false,
        independent_learner: false,
        email: spec.email,
        email_verified: true,
        given_name: spec.given_name,
        family_name: spec.family_name,
        sub: spec.sub
      }

      changeset = User.noauth_changeset(%User{sub: spec.sub, guest: true}, attrs)

      case Ecto.Changeset.apply_action(changeset, :insert) do
        {:ok, user} -> {:cont, {:ok, [user | users]}}
        {:error, changeset} -> {:halt, {:error, {:invalid_scenario_user, index, changeset}}}
      end
    end)
    |> case do
      {:ok, users} -> {:ok, Enum.reverse(users)}
      error -> error
    end
  end

  defp insert_attrs(user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %{
      sub: user.sub,
      name: user.name,
      given_name: user.given_name,
      family_name: user.family_name,
      email: user.email,
      email_verified: user.email_verified,
      guest: user.guest,
      independent_learner: user.independent_learner,
      inserted_at: now,
      updated_at: now
    }
  end

  defp enroll_by_role(specs, users_by_email, section) do
    with :ok <- enroll_role(specs, users_by_email, section, :instructor),
         :ok <- enroll_role(specs, users_by_email, section, :learner) do
      :ok
    end
  end

  defp enroll_role(specs, users_by_email, section, role) do
    ids =
      specs
      |> Enum.filter(&(&1.role == role))
      |> Enum.map(&Map.fetch!(users_by_email, &1.email).id)

    context_role = context_role(role)

    case ids do
      [] -> :ok
      ids -> normalize_enrollment(Sections.enroll(ids, section.id, [context_role]))
    end
  end

  defp normalize_enrollment(result) do
    case result do
      {:ok, {:ok, [_ | _]}} -> :ok
      {:ok, [_ | _]} -> :ok
      {:error, reason} -> {:error, reason}
      other -> {:error, {:unexpected_enrollment_result, other}}
    end
  end

  defp context_role(:instructor), do: ContextRoles.get_role(:context_instructor)
  defp context_role(:learner), do: ContextRoles.get_role(:context_learner)
end
