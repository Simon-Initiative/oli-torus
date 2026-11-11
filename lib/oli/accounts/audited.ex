defmodule Oli.Accounts.Audited do
  @moduledoc """
  Application boundary for audited account commands.

  Each command performs the account write and records its audit events in one transaction, so
  the change and its events are committed or rolled back together. Commands do not authorize the
  actor: callers keep their existing authorization, such as the route's administrator plug. The
  internal mutation module is not exported to callers.

  Every command has a `*_multi/4` variant that adds its steps to a caller's `Ecto.Multi`, and a
  wrapper that runs its own transaction and returns `{:error, :nested_transaction}` when called
  inside another one. Account fields map to events as follows; one command writes one event per
  event type that has changes, all sharing the context's operation ID:

    * `system_role_id` - `author_role_changed`
    * `is_internal` - `account_internal_flag_changed`
    * `can_create_sections` - `account_creation_rights_changed`
    * `independent_learner`, `hidden`, `guest`, platform roles - `account_permissions_changed`
    * `locked_at` - `account_locked` or `account_unlocked`
    * every other audited field - `account_updated`

  A command whose write changes nothing writes no event.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export Mutations. Outgoing checks are off because
  # this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  import Ecto.Query, warn: false

  require Logger

  alias Ecto.Multi
  alias Lti_1p3.DataProviders.EctoProvider.Marshaler
  alias Oli.Accounts.{Author, ProtectedKeys, SystemRole, User}
  alias Oli.Accounts.Audited.Mutations
  alias Oli.Auditing
  alias Oli.Auditing.{Changes, Context}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Repo

  @type kind :: :user | :author

  @type command_error ::
          :invalid_request
          | :not_found
          | :delete_failed
          | :nested_transaction
          | :protected
          | Ecto.Changeset.t()
          | Auditing.Error.t()

  @admin_user_fields [:given_name, :family_name, :email, :can_create_sections, :is_internal]
  @admin_author_fields [:given_name, :family_name, :email, :system_role_id, :is_internal]
  @profile_fields [:name, :given_name, :family_name]

  @routed_fields %{
    "system_role_id" => :author_role_changed,
    "is_internal" => :account_internal_flag_changed,
    "can_create_sections" => :account_creation_rights_changed,
    "independent_learner" => :account_permissions_changed,
    "hidden" => :account_permissions_changed,
    "guest" => :account_permissions_changed,
    "platform_roles" => :account_permissions_changed
  }

  @event_keys %{
    account_updated: "updated",
    account_locked: "locked",
    account_unlocked: "unlocked",
    account_permissions_changed: "permissions_changed",
    account_creation_rights_changed: "creation_rights_changed",
    author_role_changed: "author_role_changed",
    account_internal_flag_changed: "account_internal_flag_changed"
  }

  ## Deletion

  @doc """
  Deletes the user with ID `user_id` and records `user_deleted` in the same transaction.

  `context` identifies the author who performs the deletion and becomes the event's actor; it
  must belong to an author. This function does not check the author's permissions: the caller
  must already have authorized them, as the user-detail route does for account administrators.

  The user is locked before deletion, so concurrent deletions of the same user commit one
  deletion and one event, and the others return `:not_found`.

  Returns `{:error, :nested_transaction}` when called inside another transaction; compose
  `delete_user_multi/4` instead. Any error rolls back both the deletion and the event.
  """
  @spec delete_user(Context.t(), pos_integer()) ::
          {:ok, %{user_id: pos_integer()}} | {:error, command_error()}
  def delete_user(context, user_id),
    do: run(:delete_user, &delete_user_multi(&1, :delete_user, context, user_id))

  @doc """
  Adds the steps of `delete_user/2` to `multi`, for callers that own the transaction.

  The result is stored under `name`; internal steps use `{name, step}` names. The caller's
  transaction decides whether the deletion and its event commit.
  """
  @spec delete_user_multi(Multi.t(), Multi.name(), Context.t(), pos_integer()) :: Multi.t()
  def delete_user_multi(multi, name, context, user_id),
    do: delete_account_multi(multi, name, context, :user, user_id)

  @doc """
  Deletes the author with ID `author_id` and records `author_deleted` in the same transaction.

  `context` identifies the author who performs the deletion (an administrator, or the project
  author who cancels a pending collaborator invitation) and must belong to an author. Callers
  authorize the action. Concurrency, errors, and nesting behave as in `delete_user/2`.
  """
  @spec delete_author(Context.t(), pos_integer()) ::
          {:ok, %{author_id: pos_integer()}} | {:error, command_error()}
  def delete_author(context, author_id),
    do: run(:delete_author, &delete_author_multi(&1, :delete_author, context, author_id))

  @doc "Adds the steps of `delete_author/2` to `multi`, as `delete_user_multi/4` does."
  @spec delete_author_multi(Multi.t(), Multi.name(), Context.t(), pos_integer()) :: Multi.t()
  def delete_author_multi(multi, name, context, author_id),
    do: delete_account_multi(multi, name, context, :author, author_id)

  defp delete_account_multi(
         %Multi{} = multi,
         name,
         %Context{actor_type: :author, author_id: actor_id} = context,
         kind,
         id
       )
       when is_integer(actor_id) and is_integer(id) and id > 0 do
    multi
    |> Multi.run({name, kind}, fn repo, _changes -> lock_row(repo, kind, id) end)
    |> Multi.run({name, :deleted}, fn _repo, changes ->
      changes |> Map.fetch!({name, kind}) |> delete(kind)
    end)
    |> Auditing.append({name, :event}, fn changes ->
      deleted_event(context, kind, Map.fetch!(changes, {name, :deleted}))
    end)
    |> Multi.run(name, fn _repo, changes ->
      {:ok, %{:"#{kind}_id" => Map.fetch!(changes, {name, :deleted}).id}}
    end)
  end

  defp delete_account_multi(%Multi{} = multi, name, _context, _kind, _id),
    do: Multi.error(multi, name, :invalid_request)

  ## Administrator updates

  @doc """
  Updates the user with ID `user_id` from the administrator's user form.

  `attrs` may contain `given_name`, `family_name`, `email`, `can_create_sections`, and
  `is_internal`; any other user field returns `{:error, :protected}`. Writes `account_updated`,
  `account_creation_rights_changed`, and `account_internal_flag_changed` for the fields that
  changed. `context` must belong to an author; callers authorize the action and decide which
  fields the administrator may submit.
  """
  @spec admin_update_user(Context.t(), pos_integer(), map()) ::
          {:ok, %User{}} | {:error, command_error()}
  def admin_update_user(context, user_id, attrs),
    do: run(:account, &admin_update_user_multi(&1, :account, context, {user_id, attrs}))

  @doc "Adds the steps of `admin_update_user/3` to `multi`."
  @spec admin_update_user_multi(Multi.t(), Multi.name(), Context.t(), {pos_integer(), map()}) ::
          Multi.t()
  def admin_update_user_multi(multi, name, %Context{actor_type: :author} = context, {id, attrs})
      when is_map(attrs) do
    update_multi(multi, name, context, :user, id, fn user ->
      restrict(
        User.noauth_changeset(user, Map.take(attrs, keys(@admin_user_fields))),
        attrs,
        @admin_user_fields
      )
    end)
  end

  def admin_update_user_multi(%Multi{} = multi, name, _context, _args),
    do: Multi.error(multi, name, :invalid_request)

  @doc """
  Updates the author with ID `author_id` from the administrator's author form.

  `attrs` may contain `given_name`, `family_name`, `email`, `system_role_id`, and `is_internal`;
  any other author field returns `{:error, :protected}`. Writes `account_updated`,
  `author_role_changed`, and `account_internal_flag_changed` for the fields that changed.
  `context` must belong to an author; callers authorize the action and decide which fields the
  administrator may submit (only system administrators change roles or the internal flag).
  """
  @spec admin_update_author(Context.t(), pos_integer(), map()) ::
          {:ok, %Author{}} | {:error, command_error()}
  def admin_update_author(context, author_id, attrs),
    do: run(:account, &admin_update_author_multi(&1, :account, context, {author_id, attrs}))

  @doc "Adds the steps of `admin_update_author/3` to `multi`."
  @spec admin_update_author_multi(Multi.t(), Multi.name(), Context.t(), {pos_integer(), map()}) ::
          Multi.t()
  def admin_update_author_multi(multi, name, %Context{actor_type: :author} = context, {id, attrs})
      when is_map(attrs) do
    update_multi(multi, name, context, :author, id, fn author ->
      author
      |> Author.noauth_changeset(Map.take(attrs, keys(@admin_author_fields)))
      |> Ecto.Changeset.validate_inclusion(:system_role_id, Map.values(SystemRole.role_id()))
      |> restrict(attrs, @admin_author_fields)
    end)
  end

  def admin_update_author_multi(%Multi{} = multi, name, _context, _args),
    do: Multi.error(multi, name, :invalid_request)

  ## Own profile

  @doc """
  Updates the signed-in account's own name from its settings page and records
  `account_updated`.

  `attrs` may contain `name`, `given_name`, and `family_name`; any other field of the account
  returns `{:error, :protected}` and writes nothing. `context` must belong to `account` itself.
  Validation errors return the changeset, as the settings forms render it.
  """
  @spec update_own_profile(Context.t(), %User{} | %Author{}, map()) ::
          {:ok, %User{} | %Author{}} | {:error, command_error()}
  def update_own_profile(%Context{} = context, %schema{id: id}, attrs)
      when schema in [User, Author] and is_integer(id) and is_map(attrs) do
    kind = kind(schema)

    case {context.actor_type, Map.get(context, :"#{kind}_id")} do
      {^kind, ^id} ->
        run(:account, fn multi ->
          update_multi(multi, :account, context, kind, id, fn account ->
            account
            |> schema.noauth_changeset(Map.take(attrs, keys(@profile_fields)))
            |> restrict(attrs, @profile_fields)
          end)
        end)

      _other_actor ->
        {:error, :invalid_request}
    end
  end

  def update_own_profile(_context, _account, _attrs), do: {:error, :invalid_request}

  ## Lock, unlock, and confirmation

  @doc """
  Locks the account so it can no longer sign in, and records `account_locked`.

  Locking an account that is already locked changes nothing and records nothing. `context` must
  belong to an author; callers authorize the action.
  """
  @spec lock_account(Context.t(), kind(), pos_integer()) ::
          {:ok, %User{} | %Author{}} | {:error, command_error()}
  def lock_account(context, kind, id),
    do: run(:account, &lock_account_multi(&1, :account, context, {kind, id, true}))

  @doc """
  Unlocks the account and records `account_unlocked`. Unlocking an account that is not locked
  changes nothing and records nothing.
  """
  @spec unlock_account(Context.t(), kind(), pos_integer()) ::
          {:ok, %User{} | %Author{}} | {:error, command_error()}
  def unlock_account(context, kind, id),
    do: run(:account, &lock_account_multi(&1, :account, context, {kind, id, false}))

  @doc "Adds the steps of `lock_account/3` (`locked` true) or `unlock_account/3` to `multi`."
  @spec lock_account_multi(
          Multi.t(),
          Multi.name(),
          Context.t(),
          {kind(), pos_integer(), boolean()}
        ) ::
          Multi.t()
  def lock_account_multi(multi, name, %Context{actor_type: :author} = context, {kind, id, locked})
      when kind in [:user, :author] and is_boolean(locked) do
    update_multi(multi, name, context, kind, id, fn account ->
      case {locked, account.locked_at} do
        {true, nil} -> schema(kind).lock_account_changeset(account, true)
        {false, %DateTime{}} -> schema(kind).lock_account_changeset(account, false)
        _unchanged -> Ecto.Changeset.change(account)
      end
    end)
  end

  def lock_account_multi(%Multi{} = multi, name, _context, _args),
    do: Multi.error(multi, name, :invalid_request)

  @doc """
  Marks the account's email as confirmed on behalf of an administrator, and records
  `account_updated` with the new `email_confirmed_at`. `context` must belong to an author;
  callers authorize the action.
  """
  @spec admin_confirm_email(Context.t(), {kind(), pos_integer()}) ::
          {:ok, %User{} | %Author{}} | {:error, command_error()}
  def admin_confirm_email(%Context{actor_type: :author} = context, {kind, id})
      when kind in [:user, :author] do
    run(:account, fn multi ->
      schema = schema(kind)
      update_multi(multi, :account, context, kind, id, &schema.confirm_changeset/1)
    end)
  end

  def admin_confirm_email(_context, _account), do: {:error, :invalid_request}

  ## Platform roles

  @doc """
  Replaces the user's institution-level (LTI platform) roles with `roles`, a list of
  `Lti_1p3.Roles.PlatformRole` structs, and records `account_permissions_changed` with the
  previous and resulting role URIs. A sync that keeps the same set writes nothing.

  `context` is the identity-provider provisioning actor for LTI launches, or the user when they
  enroll themselves.
  """
  @spec sync_platform_roles(Context.t(), pos_integer(), [struct()]) ::
          {:ok, %User{}} | {:error, command_error()}
  def sync_platform_roles(context, user_id, roles),
    do: run(:account, &sync_platform_roles_multi(&1, :account, context, {user_id, roles}))

  @doc "Adds the steps of `sync_platform_roles/3` to `multi`."
  @spec sync_platform_roles_multi(
          Multi.t(),
          Multi.name(),
          Context.t(),
          {pos_integer(), [struct()]}
        ) ::
          Multi.t()
  def sync_platform_roles_multi(%Multi{} = multi, name, %Context{} = context, {user_id, roles})
      when is_integer(user_id) and user_id > 0 and is_list(roles) do
    multi
    |> Multi.run({name, :before}, fn repo, _changes ->
      with {:ok, user} <- lock_row(repo, :user, user_id) do
        {:ok, repo.preload(user, :platform_roles)}
      end
    end)
    |> Multi.run({name, :after}, fn _repo, changes ->
      user = Map.fetch!(changes, {name, :before})

      case role_uris(user.platform_roles) == role_uris(roles) do
        true -> {:ok, user}
        false -> Mutations.put_platform_roles(user, Marshaler.to(roles))
      end
    end)
    |> Auditing.append({name, :event}, fn changes ->
      before = Map.fetch!(changes, {name, :before})
      updated = Map.fetch!(changes, {name, :after})

      case {role_uris(before.platform_roles), role_uris(updated.platform_roles)} do
        {same, same} ->
          :skip

        {previous, resulting} ->
          account_event(context, :account_permissions_changed, :user, updated, %{
            "platform_roles" => %{
              "operation" => "set",
              "before" => previous,
              "after" => resulting
            }
          })
      end
    end)
    |> Multi.run(name, fn _repo, changes -> {:ok, Map.fetch!(changes, {name, :after})} end)
  end

  def sync_platform_roles_multi(%Multi{} = multi, name, _context, _args),
    do: Multi.error(multi, name, :invalid_request)

  ## Shared steps

  defp run(name, build) do
    case Repo.in_transaction?() do
      true ->
        {:error, :nested_transaction}

      false ->
        Multi.new()
        |> build.()
        |> Repo.transaction()
        |> case do
          {:ok, changes} -> {:ok, Map.fetch!(changes, name)}
          {:error, _step, reason, _changes} -> {:error, reason}
        end
    end
  end

  # Locks the account, applies the changeset built by `change`, and records one event per event
  # type whose fields changed.
  defp update_multi(%Multi{} = multi, name, context, kind, id, change)
       when kind in [:user, :author] and is_integer(id) and id > 0 do
    multi
    |> Multi.run({name, :before}, fn repo, _changes -> lock_row(repo, kind, id) end)
    |> Multi.run({name, :after}, fn _repo, changes ->
      changes |> Map.fetch!({name, :before}) |> change.() |> update()
    end)
    |> Multi.merge(fn changes ->
      before = Map.fetch!(changes, {name, :before})
      updated = Map.fetch!(changes, {name, :after})

      before
      |> Changes.diff(updated, policy(kind))
      |> group_changes(updated)
      |> Enum.reduce(Multi.new(), fn {event_type, changes}, events ->
        Auditing.append(events, {name, event_type}, fn _ ->
          account_event(
            context,
            event_type,
            kind,
            updated,
            changes,
            event_details(event_type, context, kind, before, updated)
          )
        end)
      end)
    end)
    |> Multi.run(name, fn _repo, changes -> {:ok, Map.fetch!(changes, {name, :after})} end)
  end

  defp update_multi(%Multi{} = multi, name, _context, _kind, _id, _change),
    do: Multi.error(multi, name, :invalid_request)

  defp restrict(changeset, attrs, allowed), do: ProtectedKeys.validate(changeset, attrs, allowed)

  defp update(%Ecto.Changeset{} = changeset) do
    case ProtectedKeys.protected?(changeset) do
      true -> {:error, :protected}
      false -> Mutations.update_account(changeset)
    end
  end

  defp group_changes(changes, updated) do
    changes
    |> Enum.group_by(fn {field, _record} -> event_for(field, updated) end)
    |> Enum.map(fn {event_type, records} -> {event_type, Map.new(records)} end)
    |> Enum.sort()
  end

  defp event_for("locked_at", %{locked_at: nil}), do: :account_unlocked
  defp event_for("locked_at", _account), do: :account_locked
  defp event_for(field, _account), do: Map.get(@routed_fields, field, :account_updated)

  defp lock_row(repo, kind, id) do
    case repo.one(from(a in schema(kind), where: a.id == ^id, lock: "FOR UPDATE")) do
      nil -> {:error, :not_found}
      account -> {:ok, account}
    end
  end

  defp delete(account, kind) do
    case Mutations.delete_account(account) do
      {:ok, account} ->
        {:ok, account}

      {:error, reason} ->
        Logger.warning(
          "Audited #{kind} deletion failed #{kind}_id=#{account.id} reason=#{failure_reason(reason)}"
        )

        {:error, :delete_failed}
    end
  end

  # Logs only error keys, never changeset values, so personal data stays out of logs.
  defp failure_reason(:referenced), do: "referenced"

  defp failure_reason(%Ecto.Changeset{errors: errors}),
    do: "changeset:" <> (errors |> Keyword.keys() |> Enum.uniq() |> Enum.join(","))

  ## Events

  defp deleted_event(context, kind, account) do
    Auditing.build(context, %{
      event_type: :"#{kind}_deleted",
      entity: {kind, account.id, account},
      affected: {kind, account.id},
      event_key: "account:primary:deleted",
      details: %{
        "email" => account.email,
        "name" => account.name,
        "deleted_by" => context.actor_snapshot["email"]
      }
    })
  end

  defp account_event(context, event_type, kind, account, changes, details \\ %{}) do
    Auditing.build(context, %{
      event_type: event_type,
      entity: {kind, account.id, account},
      affected: {kind, account.id},
      event_key: "account:primary:" <> Map.fetch!(@event_keys, event_type),
      changes: changes,
      details: details
    })
  end

  defp event_details(:author_role_changed, context, :author, before, updated) do
    %{
      "actor_name" => context.actor_snapshot["name"],
      "actor_email" => context.actor_snapshot["email"],
      "author_id" => updated.id,
      "author_name" => updated.name,
      "author_email" => updated.email,
      "previous_role_id" => before.system_role_id,
      "new_role_id" => updated.system_role_id,
      "previous_role" => SystemRole.label(before.system_role_id),
      "new_role" => SystemRole.label(updated.system_role_id)
    }
  end

  defp event_details(:account_internal_flag_changed, _context, kind, before, updated) do
    %{
      "account_type" => Atom.to_string(kind),
      "#{kind}_id" => updated.id,
      "previous" => before.is_internal,
      "is_internal" => updated.is_internal
    }
  end

  defp event_details(_event_type, _context, _kind, _before, _updated), do: %{}

  defp policy(:user), do: Fields.user_account()
  defp policy(:author), do: Fields.author_account()

  defp schema(:user), do: User
  defp schema(:author), do: Author

  defp kind(User), do: :user
  defp kind(Author), do: :author

  defp keys(fields), do: Enum.flat_map(fields, &[&1, Atom.to_string(&1)])

  defp role_uris(roles), do: roles |> Enum.map(& &1.uri) |> Enum.sort()
end
