defmodule Oli.Lti.SectionDeepLinkLaunch do
  @moduledoc """
  Authorizes section-local tool configuration and binds a signed tool return to its initiator.

  The controller validates the tool JWT signature before calling `persist_return/4`.
  Torus correlation is verified separately; current access and deployment capability
  are checked again before a selection (the resource configuration chosen in the
  external tool, including URL/custom metadata) is written. A successful request is
  consumed atomically with the selection through the existing LTI nonce store.
  """

  import Ecto.Query

  alias Lti_1p3.DataProviders.EctoProvider.Nonce
  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Lti.{AuthoringLaunch, PlatformExternalTools}
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Revision
  alias Oli.Repo

  @salt "lti-section-request"
  @max_age 1800

  @doc "Selects the admin author when present, otherwise the current delivery user."
  def actor(user, author) do
    case Accounts.is_admin?(author) do
      true -> author
      false -> user
    end
  end

  @doc "Returns the account namespace used to bind login hints and return correlation."
  def actor_type(%Author{}), do: "author"
  def actor_type(%User{}), do: "user"
  def actor_type(_), do: nil

  @doc "Resolves an active tool activity only for an instructor or administrator who may configure it."
  def resolve(actor, section_slug, resource_id) when is_binary(section_slug) do
    with {:ok, resource_id} <- parse_resource_id(resource_id),
         %Section{status: :active} = section <- Sections.get_section_by_slug(section_slug),
         true <- allowed?(actor, section_slug),
         %Revision{activity_type_id: type, deleted: false} = revision <-
           DeliveryResolver.from_resource_id(section_slug, resource_id),
         %{status: :enabled, deep_linking_enabled: true, platform_instance: %{status: :active}} =
           deployment <-
           PlatformExternalTools.get_lti_external_tool_activity_deployment_by(
             activity_registration_id: type
           ) do
      {:ok, section, revision, deployment}
    else
      _ -> {:error, :configuration_unavailable}
    end
  end

  def resolve(_, _, _), do: {:error, :configuration_unavailable}

  @doc "Checks configuration access using a section and deployment already resolved by the caller."
  def can_configure?(actor, %Section{status: :active} = section, %{
        status: :enabled,
        deep_linking_enabled: true,
        platform_instance: %{status: :active}
      }),
      do: allowed?(actor, section.slug)

  def can_configure?(_, _, _), do: false

  @doc "Starts the latest configuration request for a section activity, superseding previous requests."
  def start_request(actor, section_slug, resource_id) do
    with {:ok, section, _, _} <- resolve(actor, section_slug, resource_id) do
      Repo.transaction(fn ->
        lock_section(section.id)

        with {:ok, _, _, deployment} <- resolve(actor, section_slug, resource_id),
             request_id <- Ecto.UUID.generate(),
             value <- pending_value(section.id, resource_id),
             {_count, _} <- Repo.delete_all(from(n in Nonce, where: n.value == ^value)),
             {:ok, _} <- Lti_1p3.Nonces.create_nonce(value, request_id) do
          %{
            section: section,
            deployment: deployment,
            request_id: request_id,
            request_token: sign_request(actor, section, resource_id, deployment, request_id)
          }
        else
          _ -> Repo.rollback(:configuration_unavailable)
        end
      end)
    end
  end

  @doc """
  Invalidates the initiating actor's request without undoing an already committed return.
  The signed actor/route binding permits cancellation after access is revoked or
  the token expires; it cannot save tool configuration. Returns whether completion
  or cancellation won.
  """
  def cancel_request(actor, section_slug, resource_id, token) do
    with %Section{} = section <- Sections.get_section_by_slug(section_slug),
         {:ok, request} <-
           verify_request(
             %{"https://purl.imsglobal.org/spec/lti-dl/claim/data" => token},
             section.id,
             to_string(resource_id),
             :infinity
           ),
         %{id: actor_id} <- actor,
         true <- request["actor_id"] == actor_id and request["actor_type"] == actor_type(actor) do
      Repo.transaction(fn ->
        lock_section(section.id)
        delete_pending(section.id, resource_id, request["request_id"])

        case Repo.exists?(
               from(n in Nonce,
                 where: n.value == ^request["request_id"] and n.domain == "section_deep_linking"
               )
             ) do
          true -> :completed
          false -> :cancelled
        end
      end)
    else
      _ -> {:error, :configuration_unavailable}
    end
  end

  @doc "Signs the initiating account, section, activity, deployment and request identity."
  def sign_request(actor, section, resource_id, deployment, request_id) do
    Phoenix.Token.sign(OliWeb.Endpoint, @salt, %{
      "actor_type" => actor_type(actor),
      "actor_id" => actor.id,
      "section_id" => section.id,
      "resource_id" => to_string(resource_id),
      "deployment_id" => deployment.deployment_id,
      "request_id" => request_id
    })
  end

  @doc """
  Persists a selection (the resource configuration returned by the external tool)
  only for its initiating section/activity after rechecking access and signed correlation.
  Consumes the current pending request atomically with the write; failure rolls back both.
  """
  def persist_return(claims, item, %Section{} = section, resource_id) do
    with {:ok, selection} <- AuthoringLaunch.selection(item),
         {:ok, request} <- verify_request(claims, section.id, to_string(resource_id)) do
      Repo.transaction(fn ->
        # Serialize configuration with other section operations and recheck access inside the transaction.
        lock_section(section.id)

        with :ok <- validate_return(claims, request, section, to_string(resource_id)),
             true <- pending?(section.id, resource_id, request["request_id"]),
             :ok <- consume_request(request["request_id"]),
             {:ok, _} <-
               PlatformExternalTools.upsert_section_resource_deep_link(
                 Map.merge(selection, %{"section_id" => section.id, "resource_id" => resource_id})
               ) do
          delete_pending(section.id, resource_id, request["request_id"])
          request["request_id"]
        else
          false -> Repo.rollback(:invalid_section_return)
          {:error, reason} when is_atom(reason) -> Repo.rollback(reason)
          {:error, _} -> Repo.rollback(:failed_to_create_deep_link)
        end
      end)
    end
  rescue
    _error in [Ecto.ConstraintError, Postgrex.Error] ->
      {:error, :failed_to_create_deep_link}
  end

  # Normalizes route IDs to canonical positive database IDs so alternate textual
  # representations cannot create separate pending requests for one activity.
  defp parse_resource_id(id) when is_binary(id) and byte_size(id) <= 10 do
    with {value, ""} <- Integer.parse(id),
         true <- value > 0 and value <= 2_147_483_647 and Integer.to_string(value) == id do
      {:ok, value}
    else
      _ -> {:error, :configuration_unavailable}
    end
  end

  defp parse_resource_id(id) when is_integer(id) and id > 0 and id <= 2_147_483_647,
    do: {:ok, id}

  defp parse_resource_id(_), do: {:error, :configuration_unavailable}

  # Serializes request start, cancellation and return persistence with other
  # section writes until the caller's transaction completes.
  defp lock_section(id), do: Repo.one(from(s in Section, where: s.id == ^id, lock: "FOR UPDATE"))

  # Identifies the latest pending launch for one section/activity independently of
  # its request UUID, using the leading column of the existing (value, domain) nonce index.
  defp pending_value(section_id, resource_id),
    do: "section_deep_linking_pending:#{section_id}:#{resource_id}"

  # Confirms this return belongs to the latest request rather than one superseded
  # by another configuration launch or invalidated by cancellation.
  defp pending?(section_id, resource_id, request_id) do
    value = pending_value(section_id, resource_id)
    Repo.exists?(from(n in Nonce, where: n.value == ^value and n.domain == ^request_id))
  end

  # Removes only the matching request generation, leaving any newer one intact.
  defp delete_pending(section_id, resource_id, request_id) do
    value = pending_value(section_id, resource_id)
    Repo.delete_all(from(n in Nonce, where: n.value == ^value and n.domain == ^request_id))
  end

  # Applies the account-specific configuration policy: admin authors or users
  # enrolled as instructors in this section.
  defp allowed?(%Author{} = author, _section_slug), do: Accounts.is_admin?(author)
  defp allowed?(%User{} = user, section_slug), do: Sections.is_instructor?(user, section_slug)
  defp allowed?(_, _section_slug), do: false

  # Verifies Torus's signed data claim separately from the tool JWT and binds it
  # to this section/activity. Cancellation may override the age limit without
  # weakening signature or route checks.
  defp verify_request(
         claims,
         section_id,
         resource_id,
         max_age \\ min(@max_age, Lti_1p3.Config.get(:nonce_ttl_sec))
       ) do
    with token when is_binary(token) <-
           claims["https://purl.imsglobal.org/spec/lti-dl/claim/data"],
         {:ok,
          %{
            "section_id" => ^section_id,
            "resource_id" => ^resource_id,
            "request_id" => request_id
          } =
            request} <-
           Phoenix.Token.verify(OliWeb.Endpoint, @salt, token, max_age: max_age),
         true <- is_binary(request_id) and request_id != "" do
      {:ok, request}
    else
      _ -> {:error, :invalid_section_return}
    end
  end

  # Reloads the initiating account and current permissions/deployment, then checks
  # that the tool's issuer, deployment, version and expiry match that context.
  defp validate_return(claims, request, section, resource_id) do
    with actor <- load_actor(request),
         {:ok, _, _, deployment} <- resolve(actor, section.slug, resource_id),
         true <- deployment.deployment_id == request["deployment_id"],
         true <- claims["iss"] == deployment.platform_instance.client_id,
         true <-
           claims["https://purl.imsglobal.org/spec/lti/claim/deployment_id"] ==
             deployment.deployment_id,
         true <- claims["https://purl.imsglobal.org/spec/lti/claim/version"] == "1.3.0",
         expiry when is_integer(expiry) <- claims["exp"],
         true <- expiry > System.system_time(:second) do
      :ok
    else
      _ -> {:error, :invalid_section_return}
    end
  end

  # Resolves the signed account namespace so equal author/user IDs cannot identify
  # the wrong initiating account.
  defp load_actor(%{"actor_type" => "author", "actor_id" => id}) when is_integer(id),
    do: Accounts.get_author(id)

  defp load_actor(%{"actor_type" => "user", "actor_id" => id}) when is_integer(id),
    do: Accounts.get_user(id, preload: [])

  defp load_actor(_), do: nil

  # Records successful use through the nonce store's uniqueness constraint.
  # The caller's transaction makes this marker and the tool configuration atomic.
  defp consume_request(request_id) do
    case Lti_1p3.Nonces.create_nonce(request_id, "section_deep_linking") do
      {:ok, _} ->
        :ok

      {:error, %Lti_1p3.DataProviderError{reason: :unique_constraint_violation}} ->
        {:error, :request_already_used}

      {:error, _} ->
        {:error, :failed_to_create_deep_link}
    end
  end
end
