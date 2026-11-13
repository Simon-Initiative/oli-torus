defmodule Oli.Accounts.Audited do
  @moduledoc """
  Application boundary for audited account commands.

  Each command performs the account write and records its audit events in one transaction, so
  the change and its events are committed or rolled back together. Commands do not authorize the
  actor: callers keep their existing authorization, such as the route's administrator plug. The
  internal mutation module is not exported to callers.

  Commands that other callers compose into their own transactions (deletion, administrator
  updates, lock and unlock, platform roles, provisioning, linking, invitations, sessions) also
  have a `*_multi` variant that adds their steps to a caller's `Ecto.Multi`. The wrappers run
  their own transaction and return `{:error, :nested_transaction}` when called inside another
  one. Account fields map to events as follows; one command writes one event per event type
  that has changes, all sharing the context's operation ID:

    * `system_role_id` - `author_role_changed`
    * `is_internal` - `account_internal_flag_changed`
    * `can_create_sections` - `account_creation_rights_changed`
    * `independent_learner`, `hidden`, `guest`, platform roles - `account_permissions_changed`
    * `locked_at` - `account_locked` or `account_unlocked`
    * `author_id` - `account_linked`
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
  alias Oli.Auditing.{Changes, Command, Context}
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
    "platform_roles" => :account_permissions_changed,
    "author_id" => :account_linked
  }

  @event_keys %{
    account_updated: "updated",
    account_credential_recovered: "credential_recovered",
    account_locked: "locked",
    account_unlocked: "unlocked",
    account_linked: "linked",
    account_permissions_changed: "permissions_changed",
    account_creation_rights_changed: "creation_rights_changed",
    author_role_changed: "author_role_changed",
    account_internal_flag_changed: "account_internal_flag_changed"
  }

  ## Account creation

  @doc """
  Creates an account from a registration form and records `account_created` with
  `creation_source` `self_registration`. With `:self`, the new account is the event's actor;
  pass a context for a technical actor such as Scenario bootstrap.

  Users register as independent learners; validation errors return the changeset.
  """
  @spec register_account(Context.t() | :self, kind(), map()) ::
          {:ok, %User{} | %Author{}} | {:error, command_error()}
  def register_account(actor, kind, attrs) when kind in [:user, :author] and is_map(attrs) do
    changeset =
      case kind do
        :user ->
          User.registration_changeset(%User{independent_learner: true, guest: false}, attrs,
            email_verification_required: Oli.Accounts.user_email_verification_required?()
          )

        :author ->
          Author.registration_changeset(%Author{}, attrs,
            email_verification_required: Oli.Accounts.author_email_verification_required?()
          )
      end

    create(actor, kind, changeset, "self_registration")
  end

  @doc """
  Creates a guest user with a new random `sub` and records `account_created` with
  `creation_source` `guest`. With `:self`, the new guest is the actor.
  """
  @spec create_guest(Context.t() | :self, map()) :: {:ok, %User{}} | {:error, command_error()}
  def create_guest(actor, attrs \\ %{}) when is_map(attrs) do
    changeset = User.noauth_changeset(%User{sub: UUID.uuid4(), guest: true}, attrs)
    create(actor, :user, changeset, "guest")
  end

  @doc """
  Creates an invited author for `email` and records `account_created` with `creation_source`
  `invitation`. `context` is the inviter.
  """
  @spec invite_author(Context.t(), String.t()) :: {:ok, %Author{}} | {:error, command_error()}
  def invite_author(%Context{} = context, email) when is_binary(email),
    do:
      create(context, :author, Author.invite_changeset(%Author{}, %{email: email}), "invitation")

  def invite_author(_context, _email), do: {:error, :invalid_request}

  @doc """
  Adds to `multi` the creation of one invited user per email, with `context` (the inviter) as
  actor. Records one `account_created` event per created user. The result under `name` is
  `{count, users}`.
  """
  @spec invite_users_multi(Multi.t(), Multi.name(), Context.t(), [String.t()]) :: Multi.t()
  def invite_users_multi(%Multi{} = multi, name, %Context{} = context, emails)
      when is_list(emails) do
    rows = Enum.map(emails, &Mutations.invited_user_row/1)
    insert_users_multi(multi, name, context, rows, "invitation")
  end

  def invite_users_multi(%Multi{} = multi, name, _context, _emails),
    do: Multi.error(multi, name, :invalid_request)

  @doc """
  Inserts prepared user rows in one statement, as bulk Scenario setup does, and records one
  `account_created` per user with `creation_source`. Returns the number of inserted users.
  """
  @spec bulk_create_users(Context.t(), [map()], String.t()) ::
          {:ok, non_neg_integer()} | {:error, command_error()}
  def bulk_create_users(%Context{} = context, rows, creation_source)
      when is_list(rows) and is_binary(creation_source) do
    run(:users, fn multi ->
      multi
      |> insert_users_multi({:users, :inserted}, context, rows, creation_source)
      |> Multi.run(:users, fn _repo, changes ->
        {count, _users} = Map.fetch!(changes, {:users, :inserted})
        {:ok, count}
      end)
    end)
  end

  def bulk_create_users(_context, _rows, _creation_source), do: {:error, :invalid_request}

  defp insert_users_multi(multi, name, context, rows, creation_source) do
    multi
    |> Multi.run({name, :created}, fn _repo, _changes -> Mutations.insert_user_rows(rows) end)
    |> Multi.merge(fn changes ->
      {_count, users} = Map.fetch!(changes, {name, :created})

      Enum.reduce(users, Multi.new(), fn user, events ->
        Auditing.append(events, {name, :event, user.id}, fn _changes ->
          created_event(context, :user, user, creation_source, "account:user:#{user.id}:created")
        end)
      end)
    end)
    |> Multi.run(name, fn _repo, changes -> {:ok, Map.fetch!(changes, {name, :created})} end)
  end

  @doc """
  Adds to `multi` the account part of accepting an invitation: `{kind, account, attrs, via}`,
  where `via` is `:password` (the invitation form, which may set a password) or `:sso` (names
  and picture from the identity provider). The invitee proved control of the email with the
  invitation token, so it is the actor of the `account_updated` event. The caller adds the
  enrollment or collaborator change to the same `multi`.
  """
  @spec accept_invitation_multi(
          Multi.t(),
          Multi.name(),
          {kind(), %User{} | %Author{}, map(), :password | :sso}
        ) :: Multi.t()
  def accept_invitation_multi(%Multi{} = multi, name, {kind, %{id: id} = account, attrs, via})
      when kind in [:user, :author] and is_integer(id) and is_map(attrs) and
             via in [:password, :sso] do
    schema = schema(kind)
    context = Context.for_actor(account, source: :ui)

    update_multi(multi, name, context, kind, id, fn locked ->
      case via do
        :password ->
          schema.accept_invitation_changeset(locked, attrs)

        :sso ->
          now = DateTime.utc_now() |> DateTime.truncate(:second)

          locked
          |> Ecto.Changeset.cast(attrs, [:given_name, :family_name, :picture])
          |> Ecto.Changeset.put_change(:invitation_accepted_at, now)
          |> Ecto.Changeset.put_change(:email_confirmed_at, now)
      end
    end)
  end

  def accept_invitation_multi(%Multi{} = multi, name, _args),
    do: Multi.error(multi, name, :invalid_request)

  ## Identity-provider provisioning

  @doc """
  Adds to `multi` the creation or update of an account from identity-provider claims (LTI,
  Assent, or Cognito) or from technical bootstrap, with `context` as actor:
  `Context.for_system(:provider_provisioning)` for providers and
  `Context.for_system(:playwright_setup, source: :scenario)` for Scenarios.

  With `{kind, nil, changeset, creation_source}` the changeset is inserted and
  `account_created` is recorded with `creation_source` (`lti`, `sso`, or `scenario`). With
  `{kind, id, change, creation_source}` the account is locked and `change` (a function from the
  locked account to a changeset) is applied; events are recorded only for fields that changed,
  so a repeated login with the same claims writes nothing.
  """
  @spec provision_account_multi(
          Multi.t(),
          Multi.name(),
          Context.t(),
          {kind(), pos_integer() | nil, Ecto.Changeset.t() | (struct() -> Ecto.Changeset.t()),
           String.t()}
        ) :: Multi.t()
  def provision_account_multi(
        %Multi{} = multi,
        name,
        %Context{} = context,
        {kind, nil, %Ecto.Changeset{} = changeset, creation_source}
      )
      when kind in [:user, :author] and is_binary(creation_source),
      do: create_multi(multi, name, context, kind, changeset, creation_source)

  def provision_account_multi(
        %Multi{} = multi,
        name,
        %Context{} = context,
        {kind, id, change, creation_source}
      )
      when kind in [:user, :author] and is_integer(id) and is_function(change, 1) and
             is_binary(creation_source),
      do: update_multi(multi, name, context, kind, id, change)

  def provision_account_multi(%Multi{} = multi, name, _context, _args),
    do: Multi.error(multi, name, :invalid_request)

  @doc "Runs `provision_account_multi/4` in its own transaction."
  @spec provision_account(Context.t(), {kind(), pos_integer() | nil, term(), String.t()}) ::
          {:ok, %User{} | %Author{}} | {:error, command_error()}
  def provision_account(context, args),
    do: run(:account, &provision_account_multi(&1, :account, context, args))

  ## Linking

  @doc """
  Links the user with ID `user_id` to the author with ID `author_id` and records
  `account_linked` with the previous and resulting `author_id`. `context` is the person who
  links (the signed-in user or author) or the provisioning actor. Linking to the same author
  again writes nothing.
  """
  @spec link_accounts(Context.t(), pos_integer(), pos_integer()) ::
          {:ok, %User{}} | {:error, command_error()}
  def link_accounts(context, user_id, author_id),
    do: run(:account, &link_accounts_multi(&1, :account, context, {user_id, author_id}))

  @doc "Removes the user's author link and records `account_linked` with `author_id` cleared."
  @spec unlink_accounts(Context.t(), pos_integer()) :: {:ok, %User{}} | {:error, command_error()}
  def unlink_accounts(context, user_id),
    do: run(:account, &link_accounts_multi(&1, :account, context, {user_id, nil}))

  @doc "Adds the steps of `link_accounts/3` (or of `unlink_accounts/2` with `nil`) to `multi`."
  @spec link_accounts_multi(
          Multi.t(),
          Multi.name(),
          Context.t(),
          {pos_integer(), pos_integer() | nil}
        ) ::
          Multi.t()
  def link_accounts_multi(%Multi{} = multi, name, %Context{} = context, {user_id, author_id})
      when is_integer(user_id) and (is_integer(author_id) or is_nil(author_id)) do
    update_multi(multi, name, context, :user, user_id, fn user ->
      Ecto.Changeset.change(user, author_id: author_id)
    end)
  end

  def link_accounts_multi(%Multi{} = multi, name, _context, _args),
    do: Multi.error(multi, name, :invalid_request)

  ## Login-provider identities

  @doc """
  Connects a login-provider identity (`"provider"` and `"uid"` in `params`, for example a
  Google account) to `account` and records `account_identity_linked` with the provider name.
  The provider's account identifier is not recorded. `context` must belong to `account`.
  """
  @spec link_identity(Context.t(), %User{} | %Author{}, map()) ::
          {:ok, struct()} | {:error, command_error()}
  def link_identity(context, %schema{} = account, params)
      when schema in [User, Author] and is_map(params) do
    own(context, account, fn kind ->
      run(:identity, fn multi ->
        multi
        |> Multi.run({:identity, :inserted}, fn _repo, _changes ->
          Mutations.insert_identity(account, params)
        end)
        |> Auditing.append({:identity, :event}, fn changes ->
          identity = Map.fetch!(changes, {:identity, :inserted})
          identity_event(context, :account_identity_linked, kind, account, identity.provider)
        end)
        |> Multi.run(:identity, fn _repo, changes ->
          {:ok, Map.fetch!(changes, {:identity, :inserted})}
        end)
      end)
    end)
  end

  def link_identity(_context, _account, _params), do: {:error, :invalid_request}

  @doc """
  Disconnects the given login-provider `identities` of `account` and records one
  `account_identity_unlinked` per provider whose identity was actually removed; identities of
  other accounts are ignored. Returns `{:ok, {count, nil}}` like `Repo.delete_all/1`. `context`
  must belong to `account`; the caller keeps the rule that an account without a password
  cannot remove its last provider.
  """
  @spec unlink_identities(Context.t(), %User{} | %Author{}, [struct()]) ::
          {:ok, {non_neg_integer(), nil}} | {:error, command_error()}
  def unlink_identities(context, %schema{} = account, identities)
      when schema in [User, Author] and is_list(identities) do
    own(context, account, fn kind ->
      run(:identity, fn multi ->
        multi
        |> Multi.run({:identity, :deleted}, fn _repo, _changes ->
          Mutations.delete_identities(kind, account.id, Enum.map(identities, & &1.id))
        end)
        |> Multi.merge(fn changes ->
          case Map.fetch!(changes, {:identity, :deleted}) do
            {0, _} ->
              Multi.new()

            {_count, providers} ->
              providers
              |> Enum.uniq()
              |> Enum.reduce(Multi.new(), fn provider, events ->
                Auditing.append(events, {:identity, :event, provider}, fn _changes ->
                  identity_event(context, :account_identity_unlinked, kind, account, provider)
                end)
              end)
          end
        end)
        |> Multi.run(:identity, fn _repo, changes ->
          {count, _providers} = Map.fetch!(changes, {:identity, :deleted})
          {:ok, {count, nil}}
        end)
      end)
    end)
  end

  def unlink_identities(_context, _account, _identities), do: {:error, :invalid_request}

  ## Sessions

  @typedoc "How the account authenticated before the session was issued."
  @type auth_method :: :password | :sso | :cognito | :lti

  @doc """
  Issues a session token for `account` after it authenticated with `auth_method`, and records
  `user_logged_in` or `author_logged_in` with the method and the token row ID as
  `session_ref`; the token itself is never recorded. `context` must belong to `account`.

  Options: `:scope` (a `%Oli.Delivery.SecureAssessments.Scope{}` for a secure assessment
  session; its section becomes the event's section scope). Returns the token for the caller to
  put in the browser session after commit.
  """
  @spec issue_session(Context.t(), %User{} | %Author{}, auth_method(), keyword()) ::
          {:ok, %{token: binary(), token_id: pos_integer()}} | {:error, command_error()}
  def issue_session(context, account, auth_method, opts \\ []),
    do: run(:session, &issue_session_multi(&1, :session, context, {account, auth_method, opts}))

  @doc "Adds the steps of `issue_session/4` to `multi`, for the LTI launch transaction."
  @spec issue_session_multi(
          Multi.t(),
          Multi.name(),
          Context.t(),
          {%User{} | %Author{}, auth_method(), keyword()}
        ) :: Multi.t()
  def issue_session_multi(
        %Multi{} = multi,
        name,
        %Context{} = context,
        {%schema{id: id} = account, auth_method, opts}
      )
      when schema in [User, Author] and is_integer(id) and
             auth_method in [:password, :sso, :cognito, :lti] and is_list(opts) do
    kind = kind(schema)
    scope = Keyword.get(opts, :scope)

    case {context.actor_type, Map.get(context, :"#{kind}_id")} do
      {^kind, ^id} ->
        multi
        |> Multi.run({name, :token}, fn _repo, _changes ->
          Mutations.insert_session_token(account, scope)
        end)
        |> Auditing.append({name, :event}, fn changes ->
          %{token_id: token_id} = Map.fetch!(changes, {name, :token})

          Auditing.build(context, %{
            event_type: :"#{kind}_logged_in",
            entity: {kind, id, account},
            affected: {kind, id},
            scope: session_scope(scope),
            event_key: "session:#{token_id}:issued",
            details: %{"auth_method" => Atom.to_string(auth_method), "session_ref" => token_id}
          })
        end)
        |> Multi.run(name, fn _repo, changes -> {:ok, Map.fetch!(changes, {name, :token})} end)

      _other_actor ->
        Multi.error(multi, name, :invalid_request)
    end
  end

  def issue_session_multi(%Multi{} = multi, name, _context, _args),
    do: Multi.error(multi, name, :invalid_request)

  @doc """
  Deletes the session `token` when the account signs out, and records `user_logged_out` or
  `author_logged_out` with the token row ID. The token's owner is the actor.

  Returns `{:ok, :absent}` without an event when the token no longer exists (already signed
  out, expired and removed, or revoked by a password change), so repeated or concurrent
  sign-outs record one event. Sessions of technical accounts (guests and hidden preview
  instructors), which were not issued by an authentication, are deleted without an event.

  A sign-out must end the session even when its event cannot be written: if the audited
  transaction fails, the token is deleted without an event, a warning is logged (without the
  token), and `{:ok, :revoked_unaudited}` is returned.
  """
  @spec revoke_session(kind(), binary()) ::
          {:ok, :revoked | :absent | :revoked_unaudited} | {:error, command_error()}
  def revoke_session(kind, token) when kind in [:user, :author] and is_binary(token) do
    case audited_revoke_session(kind, token) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        Logger.warning(
          "Audited sign-out failed; session revoked without an event kind=#{kind} reason=#{revoke_failure(reason)}"
        )

        case Mutations.delete_session_token(kind, token) do
          {:ok, nil} -> {:ok, :absent}
          {:ok, _deleted} -> {:ok, :revoked_unaudited}
        end
    end
  end

  def revoke_session(_kind, _token), do: {:error, :invalid_request}

  defp audited_revoke_session(kind, token) do
    run(:session, fn multi ->
      multi
      |> Multi.run({:session, :deleted}, fn _repo, _changes ->
        Mutations.delete_session_token(kind, token)
      end)
      |> Auditing.append({:session, :event}, fn changes ->
        case Map.fetch!(changes, {:session, :deleted}) do
          nil ->
            :skip

          {_token_id, %User{} = user} when user.guest or user.hidden ->
            :skip

          {token_id, account} ->
            Auditing.build(Context.for_actor(account, source: :ui), %{
              event_type: :"#{kind}_logged_out",
              entity: {kind, account.id, account},
              affected: {kind, account.id},
              event_key: "session:#{token_id}:revoked",
              details: %{"session_ref" => token_id}
            })
        end
      end)
      |> Multi.run(:session, fn _repo, changes ->
        case Map.fetch!(changes, {:session, :deleted}) do
          nil -> {:ok, :absent}
          _deleted -> {:ok, :revoked}
        end
      end)
    end)
  end

  # Logs only error codes, never the token or event values.
  defp revoke_failure(%Auditing.Error{code: code}), do: code
  defp revoke_failure(reason) when is_atom(reason), do: reason
  defp revoke_failure(_reason), do: "other"

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
    |> Multi.run({name, kind}, fn repo, _changes -> lock_row(repo, kind, id, :delete) end)
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

  ## Credentials, confirmation, and recovery

  @doc """
  Changes the password of the signed-in account after checking `current_password`.

  Records `account_updated` with the password redaction marker and, when sessions were open,
  `session_revoked` with how many session tokens were invalidated: like before, every token
  of the account is deleted. `context` must belong to `account` itself. Validation errors,
  including a wrong current password, return the changeset and write nothing.
  """
  @spec change_password(Context.t(), %User{} | %Author{}, String.t(), map()) ::
          {:ok, %User{} | %Author{}} | {:error, command_error()}
  def change_password(context, %schema{} = account, current_password, attrs)
      when schema in [User, Author] and is_map(attrs) do
    own(context, account, fn kind ->
      credential(context, kind, account.id, :account_updated, fn locked ->
        locked
        |> schema.password_changeset(attrs, require_current_password: true)
        |> schema.validate_current_password(current_password)
      end)
    end)
  end

  def change_password(_context, _account, _current_password, _attrs),
    do: {:error, :invalid_request}

  @doc """
  Sets the first password of an account created by a login provider, as `change_password/4`
  does. An account that already has a password returns `{:error, :invalid_request}`.
  """
  @spec create_password(Context.t(), %User{} | %Author{}, map()) ::
          {:ok, %User{} | %Author{}} | {:error, command_error()}
  def create_password(context, %schema{} = account, attrs)
      when schema in [User, Author] and is_map(attrs) do
    own(context, account, fn kind ->
      credential(context, kind, account.id, :account_updated, fn
        %{password_hash: nil} = locked -> schema.password_changeset(locked, attrs)
        _has_password -> {:error, :invalid_request}
      end)
    end)
  end

  def create_password(_context, _account, _attrs), do: {:error, :invalid_request}

  @doc """
  Sets a new password through a recovery link and records `account_credential_recovered`
  (password marker) plus `session_revoked` when sessions were open.

  The caller has already verified the reset token and passes the account it belongs to;
  `context` must belong to that account. Every token of the account is deleted, including the
  reset token, so the link cannot be used again.
  """
  @spec reset_password(Context.t(), %User{} | %Author{}, map()) ::
          {:ok, %User{} | %Author{}} | {:error, command_error()}
  def reset_password(context, %schema{} = account, attrs)
      when schema in [User, Author] and is_map(attrs) do
    own(context, account, fn kind ->
      credential(context, kind, account.id, :account_credential_recovered, fn locked ->
        schema.password_changeset(locked, attrs)
      end)
    end)
  end

  def reset_password(_context, _account, _attrs), do: {:error, :invalid_request}

  @doc """
  Issues a recovery or confirmation link for the account and records
  `account_recovery_requested` with its `recovery_kind`. Returns the encoded token so the
  caller can build the link and send the email after commit; the event never contains the
  token or the link, and it does not claim the email was delivered.

  `recovery_kind` is `:password_reset` (self-service), `:confirmation`, or `:admin_reset_link`
  (an administrator generates or emails a reset link). The actor is the administrator, the
  account itself, or `Context.for_system(:unauthenticated_request)` for self-service requests
  made without signing in.
  """
  @spec request_recovery(
          Context.t(),
          {kind(), %User{} | %Author{}},
          :password_reset | :confirmation | :admin_reset_link
        ) :: {:ok, String.t()} | {:error, command_error()}
  def request_recovery(%Context{} = context, {kind, %{id: id} = account}, recovery_kind)
      when kind in [:user, :author] and is_integer(id) and
             recovery_kind in [:password_reset, :confirmation, :admin_reset_link] do
    run(:recovery, fn multi ->
      multi
      |> Multi.run({:recovery, :token}, fn _repo, _changes ->
        Mutations.insert_email_token(kind, account, token_context(recovery_kind))
      end)
      |> Auditing.append({:recovery, :event}, fn _changes ->
        Auditing.build(context, %{
          event_type: :account_recovery_requested,
          entity: {kind, id, account},
          affected: {kind, id},
          event_key: "account:primary:recovery_requested",
          details: %{"recovery_kind" => Atom.to_string(recovery_kind)}
        })
      end)
      |> Multi.run(:recovery, fn _repo, changes ->
        {:ok, Map.fetch!(changes, {:recovery, :token})}
      end)
    end)
  end

  def request_recovery(_context, _account, _recovery_kind), do: {:error, :invalid_request}

  @doc """
  Confirms the email of the account that owns the confirmation `token` and records
  `account_updated` with the new `email_confirmed_at`. The account proves control of the email
  with the token, so it is the event's actor.

  Returns `:error` for an invalid, expired, or already used token, and when the write fails.
  """
  @spec confirm_email(kind(), String.t()) :: {:ok, %User{} | %Author{}} | :error
  def confirm_email(kind, token) when kind in [:user, :author] and is_binary(token) do
    with {:ok, query} <- token_module(kind).verify_email_token_query(token, "confirm"),
         %{id: id} = account <- Repo.one(query),
         context = Context.for_actor(account, source: :ui),
         {:ok, account} <-
           run(:account, fn multi ->
             schema = schema(kind)

             multi
             |> update_multi(:account, context, kind, id, &schema.confirm_changeset/1)
             |> consume_tokens({:account, :tokens}, kind, id, ["confirm"])
           end) do
      {:ok, account}
    else
      _invalid -> :error
    end
  end

  def confirm_email(_kind, _token), do: :error

  @doc """
  Applies the email change confirmed by `token` to the signed-in `account` and records
  `account_updated` with the new email and confirmation time. `context` must belong to
  `account`. Returns `:error` for an invalid, expired, or already used token.
  """
  @spec confirm_email_change(Context.t(), %User{} | %Author{}, String.t()) :: :ok | :error
  def confirm_email_change(context, %schema{} = account, token)
      when schema in [User, Author] and is_binary(token) do
    kind = kind(schema)
    token_context = "change:#{account.email}"

    with {:ok, query} <- token_module(kind).verify_change_email_token_query(token, token_context),
         %{sent_to: email} <- Repo.one(query),
         {:ok, _account} <-
           own(context, account, fn kind ->
             run(:account, fn multi ->
               multi
               |> update_multi(:account, context, kind, account.id, fn locked ->
                 locked
                 |> schema.email_changeset(%{email: email})
                 |> schema.confirm_changeset()
               end)
               |> consume_tokens({:account, :tokens}, kind, account.id, [token_context])
             end)
           end) do
      :ok
    else
      _invalid -> :error
    end
  end

  def confirm_email_change(_context, _account, _token), do: :error

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

  # Runs `fun` with the account kind when `context` belongs to `account` itself.
  defp own(%Context{} = context, %schema{id: id}, fun) when is_integer(id) do
    kind = kind(schema)

    case {context.actor_type, Map.get(context, :"#{kind}_id")} do
      {^kind, ^id} -> fun.(kind)
      _other_actor -> {:error, :invalid_request}
    end
  end

  defp own(_context, _account, _fun), do: {:error, :invalid_request}

  # Writes a password change, deletes every token of the account, and records the password
  # marker plus the number of session tokens invalidated.
  defp credential(context, kind, id, event_type, change) do
    run(:account, fn multi ->
      multi
      |> Multi.run({:account, :before}, fn repo, _changes -> lock_row(repo, kind, id) end)
      |> Multi.run({:account, :after}, fn _repo, changes ->
        case changes |> Map.fetch!({:account, :before}) |> change.() do
          %Ecto.Changeset{} = changeset -> Mutations.update_account(changeset)
          {:error, reason} -> {:error, reason}
        end
      end)
      |> Multi.run({:account, :revoked}, fn _repo, changes ->
        Mutations.delete_all_tokens(kind, Map.fetch!(changes, {:account, :after}))
      end)
      |> Auditing.append({:account, event_type}, fn changes ->
        account = Map.fetch!(changes, {:account, :after})

        account_event(context, event_type, kind, account, %{"password" => Changes.secret_record()})
      end)
      |> Auditing.append({:account, :session_revoked}, fn changes ->
        case Map.fetch!(changes, {:account, :revoked}) do
          0 ->
            :skip

          count ->
            sessions_revoked_event(context, kind, Map.fetch!(changes, {:account, :after}), count)
        end
      end)
      |> Multi.run(:account, fn _repo, changes ->
        {:ok, Map.fetch!(changes, {:account, :after})}
      end)
    end)
  end

  # Deletes the one-time tokens a command consumed; when none is left, a concurrent request
  # already used them, so this one fails and its change rolls back.
  defp consume_tokens(multi, name, kind, id, contexts) do
    Multi.run(multi, name, fn _repo, _changes ->
      case Mutations.delete_tokens(kind, id, contexts) do
        {:ok, 0} -> {:error, :not_found}
        {:ok, count} -> {:ok, count}
      end
    end)
  end

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

  defp create(actor, kind, %Ecto.Changeset{} = changeset, creation_source)
       when actor == :self or is_struct(actor, Context) do
    run(:account, &create_multi(&1, :account, actor, kind, changeset, creation_source))
  end

  defp create(_actor, _kind, _changeset, _creation_source), do: {:error, :invalid_request}

  defp create_multi(multi, name, actor, kind, changeset, creation_source) do
    multi
    |> Multi.run({name, :created}, fn _repo, _changes -> Mutations.insert_account(changeset) end)
    |> Auditing.append({name, :event}, fn changes ->
      account = Map.fetch!(changes, {name, :created})

      context =
        case actor do
          :self -> Context.for_actor(account, source: :ui)
          %Context{} = context -> context
        end

      created_event(context, kind, account, creation_source, "account:primary:created")
    end)
    |> Multi.run(name, fn _repo, changes -> {:ok, Map.fetch!(changes, {name, :created})} end)
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
      |> put_password_marker(before, updated)
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

  # The password itself is never stored on the struct; a new hash means it changed.
  defp put_password_marker(changes, %{password_hash: same}, %{password_hash: same}), do: changes

  defp put_password_marker(changes, _before, _updated),
    do: Map.put(changes, "password", Changes.secret_record())

  defp group_changes(changes, updated) do
    changes
    |> Enum.group_by(fn {field, _record} -> event_for(field, updated) end)
    |> Enum.map(fn {event_type, records} -> {event_type, Map.new(records)} end)
    |> Enum.sort()
  end

  defp event_for("locked_at", %{locked_at: nil}), do: :account_unlocked
  defp event_for("locked_at", _account), do: :account_locked
  defp event_for(field, _account), do: Map.get(@routed_fields, field, :account_updated)

  # Updates take FOR NO KEY UPDATE, so inserts that only reference the account (session tokens,
  # enrollments, attempts) do not wait for an LTI launch; deletions take FOR UPDATE.
  defp lock_row(repo, kind, id, mode \\ :update),
    do: Command.lock(repo, schema(kind), id, mode)

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

  defp created_event(context, kind, account, creation_source, event_key) do
    Auditing.build(context, %{
      event_type: :account_created,
      entity: {kind, account.id, account},
      affected: {kind, account.id},
      event_key: event_key,
      changes: Changes.diff(nil, account, policy(kind)),
      details: %{"creation_source" => creation_source}
    })
  end

  defp session_scope(%{section_id: section_id}) when is_integer(section_id),
    do: %{section_id: section_id}

  defp session_scope(_scope), do: %{}

  defp identity_event(context, event_type, kind, account, provider) do
    Auditing.build(context, %{
      event_type: event_type,
      entity: {kind, account.id, account},
      affected: {kind, account.id},
      event_key: "account:primary:#{event_type}:#{provider}",
      details: %{"provider" => provider}
    })
  end

  defp sessions_revoked_event(context, kind, account, count) do
    Auditing.build(context, %{
      event_type: :session_revoked,
      entity: {kind, account.id, account},
      affected: {kind, account.id},
      event_key: "account:primary:sessions_revoked",
      details: %{"revoked_count" => count}
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

  # Platform roles are an association, diffed separately by `sync_platform_roles_multi/4`.
  defp policy(:user), do: Map.delete(Fields.user_account(), :platform_roles)
  defp policy(:author), do: Fields.author_account()

  defp schema(:user), do: User
  defp schema(:author), do: Author

  defp token_module(:user), do: Oli.Accounts.UserToken
  defp token_module(:author), do: Oli.Accounts.AuthorToken

  defp token_context(:confirmation), do: "confirm"
  defp token_context(_reset), do: "reset_password"

  defp kind(User), do: :user
  defp kind(Author), do: :author

  defp keys(fields), do: Enum.flat_map(fields, &[&1, Atom.to_string(&1)])

  defp role_uris(roles), do: roles |> Enum.map(& &1.uri) |> Enum.sort()
end
