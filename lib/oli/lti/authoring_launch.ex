defmodule Oli.Lti.AuthoringLaunch do
  @moduledoc "Validates authoring Deep Linking handoffs and saves through the existing activity editor."

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Authoring.Editing.Utils
  alias Oli.Authoring.Locks
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Lti.PlatformExternalTools.LtiExternalToolActivityDeployment
  alias Oli.Lti.PlatformExternalTools.LtiSectionResourceDeepLink
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.ResourceType
  alias Oli.Resources.Revision

  @doc "Resolves an active tool activity for an accepted collaborator or administrator."
  @spec resolve(%Author{} | nil, String.t(), pos_integer() | String.t()) ::
          {:ok, %Revision{}, %LtiExternalToolActivityDeployment{}} | {:error, :unavailable}
  def resolve(author, project, activity) do
    with %Author{} <- author,
         {:ok, activity} <- resource_id(activity),
         %{status: :active} <- Course.get_project_by_slug(project),
         true <-
           Accounts.is_admin?(author) or not is_nil(Course.get_author_project(project, author.id)),
         %{activity_type_id: type, deleted: false} = revision <-
           AuthoringResolver.from_resource_id(project, activity),
         %{status: :enabled, platform_instance: %{status: :active}} = deployment <-
           PlatformExternalTools.get_lti_external_tool_activity_deployment_by(
             activity_registration_id: type
           ) do
      {:ok, revision, deployment}
    else
      _ -> {:error, :unavailable}
    end
  end

  @doc "Captures the current activity and owned editor lock after pending edits have been saved."
  @spec start_request(
          %Author{} | nil,
          String.t(),
          pos_integer() | String.t(),
          pos_integer() | String.t()
        ) ::
          {:ok,
           %{
             revision: %Revision{},
             deployment: %LtiExternalToolActivityDeployment{},
             request_id: String.t(),
             request: map(),
             request_token: String.t()
           }}
          | {:error, :unavailable}
  def start_request(author, project, activity, lock_id) do
    with {:ok, lock_id} <- resource_id(lock_id),
         {:ok, revision, %{deep_linking_enabled: true} = deployment} <-
           resolve(author, project, activity),
         %{id: publication_id} <- Publishing.project_working_publication(project),
         %{locked_by_id: author_id} = lock <-
           Publishing.get_published_resource(publication_id, lock_id),
         true <- author_id == author.id and not Locks.expired_or_empty?(lock),
         true <- valid_lock?(project, revision, lock_id) do
      request = %{
        "author_id" => author.id,
        "project" => project,
        "activity" => to_string(revision.resource_id),
        "deployment_id" => deployment.deployment_id,
        "request_id" => Ecto.UUID.generate(),
        "publication_id" => publication_id,
        "revision_id" => revision.id,
        "lock_id" => lock_id,
        "fingerprint" => fingerprint(revision)
      }

      {:ok,
       %{
         revision: revision,
         deployment: deployment,
         request_id: request["request_id"],
         request: request,
         request_token: Phoenix.Token.sign(OliWeb.Endpoint, "lti-authoring-request", request)
       }}
    else
      _ -> {:error, :unavailable}
    end
  end

  @doc "Checks the initiating author/activity and current editor state before OIDC authorization."
  def validate_request(author, project, activity, token) do
    with {:ok, request} <- verify_token("lti-authoring-request", token, 1800),
         true <- associated?(author, project, activity, request),
         {:ok, _, _} <- current_context(author, request) do
      {:ok, request}
    else
      _ -> {:error, :invalid_request}
    end
  end

  @doc "Checks a signature-validated tool response against its initiating authoring request."
  def validate_return(claims) when is_map(claims) do
    with {:ok, request} <-
           verify_token(
             "lti-authoring-request",
             claims["https://purl.imsglobal.org/spec/lti-dl/claim/data"],
             1800
           ),
         %Author{} = author <- Accounts.get_author(request["author_id"]),
         {:ok, _, deployment} <- current_context(author, request),
         true <- claims["iss"] == deployment.platform_instance.client_id,
         true <-
           claims["https://purl.imsglobal.org/spec/lti/claim/deployment_id"] ==
             deployment.deployment_id,
         true <- claims["https://purl.imsglobal.org/spec/lti/claim/version"] == "1.3.0",
         exp when is_integer(exp) <- claims["exp"],
         true <- exp > System.system_time(:second) do
      {:ok, request}
    else
      _ -> {:error, :invalid_return}
    end
  end

  def validate_return(_), do: {:error, :invalid_return}

  @doc "Signs the validated selection for the editor without persisting activity changes."
  def result_token(request, selection),
    do:
      Phoenix.Token.sign(OliWeb.Endpoint, "lti-authoring-result", %{
        "request" => request,
        "selection" => selection
      })

  @doc "Validates a result token and its current author/activity/editor association."
  def validate_result(author, project, activity, token) do
    with {:ok, %{"request" => request, "selection" => item}} <-
           verify_token("lti-authoring-result", token, 600),
         true <- associated?(author, project, activity, request),
         {:ok, _, _} <- current_context(author, request),
         {:ok, selected} <- selection(item) do
      {:ok, request, selected}
    else
      _ -> {:error, :invalid_result}
    end
  end

  @doc "Submits a signed selection through the existing editor transaction, lock and revision lifecycle."
  @spec save_result(%Author{} | nil, String.t(), pos_integer() | String.t(), String.t()) ::
          {:ok, %Revision{}} | {:error, term()}
  def save_result(author, project, activity, token) do
    with {:ok, request, _} <- validate_result(author, project, activity, token) do
      ActivityEditor.edit(project, request["lock_id"], activity, author.email, %{
        "deep_link_result" => token
      })
    end
  rescue
    _error in [Ecto.ConstraintError, Postgrex.Error] -> {:error, :save_failed}
  end

  defp current_context(author, request) do
    with {:ok, revision, %{deep_linking_enabled: true} = deployment} <-
           resolve(author, request["project"], request["activity"]),
         %{id: publication_id} <- Publishing.project_working_publication(request["project"]),
         true <-
           publication_id == request["publication_id"] and
             deployment.deployment_id == request["deployment_id"],
         %{locked_by_id: author_id} = lock <-
           Publishing.get_published_resource(publication_id, request["lock_id"]),
         true <- author_id == author.id and not Locks.expired_or_empty?(lock),
         true <- valid_lock?(request["project"], revision, request["lock_id"]),
         true <-
           revision.id == request["revision_id"] and
             fingerprint(revision) == request["fingerprint"] do
      {:ok, revision, deployment}
    else
      _ -> {:error, :stale_selection}
    end
  end

  defp valid_lock?(_project, %{resource_id: lock_id, scope: :banked}, lock_id), do: true

  defp valid_lock?(project, revision, lock_id) do
    case AuthoringResolver.from_resource_id(project, lock_id) do
      %{deleted: false, content: content} = page ->
        ResourceType.is_page(page) and
          MapSet.member?(Utils.activity_references(content), revision.resource_id)

      _ ->
        false
    end
  end

  # Draft edits can retain their revision ID; compare persisted fields without changing ordinary revision policy.
  defp fingerprint(revision) do
    revision
    |> Map.take([:content, :title, :objectives, :tags, :learning_model_parameters])
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode64()
  end

  defp associated?(%Author{id: id}, project, activity, request),
    do:
      request["author_id"] == id and request["project"] == project and
        request["activity"] == to_string(activity)

  defp associated?(_, _, _, _), do: false

  defp verify_token(salt, token, max_age) when is_binary(token),
    do: Phoenix.Token.verify(OliWeb.Endpoint, salt, token, max_age: max_age)

  defp verify_token(_, _, _), do: {:error, :invalid_token}

  defp resource_id(id) when is_integer(id) and id > 0 and id <= 9_223_372_036_854_775_807,
    do: {:ok, id}

  defp resource_id(id) when is_binary(id) and byte_size(id) <= 19 do
    with {value, ""} <- Integer.parse(id),
         true <-
           value > 0 and value <= 9_223_372_036_854_775_807 and Integer.to_string(value) == id do
      {:ok, value}
    else
      _ -> {:error, :invalid_resource}
    end
  end

  defp resource_id(_), do: {:error, :invalid_resource}

  @doc "Extracts portable resource-link fields and preserves custom metadata without reinterpretation."
  @spec selection(term()) :: {:ok, map()} | {:error, :invalid_selection}
  defdelegate selection(item), to: LtiSectionResourceDeepLink
end
