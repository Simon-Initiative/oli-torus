defmodule Oli.Lti.AuthoringLaunch do
  @moduledoc "Helpers for the authoring deep-link prototype's request and result handoff."
  alias Oli.Accounts
  alias Oli.Authoring.Course
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Publishing.AuthoringResolver

  @doc "Resolves a tool activity only when the author can access its active project."
  def resolve(author, project_slug, activity_id) do
    with %Accounts.Author{} <- author,
         %{status: :active} = project <- Course.get_project_by_slug(project_slug),
         true <- Accounts.can_access?(author, project),
         %{activity_type_id: type} = revision <-
           AuthoringResolver.from_resource_id(project_slug, activity_id),
         %{status: :enabled} = deployment <-
           PlatformExternalTools.get_lti_external_tool_activity_deployment_by(
             activity_registration_id: type
           ) do
      {:ok, revision, deployment}
    else
      _ -> {:error, :unavailable}
    end
  end

  @doc "Signs the author, activity, and tool correlation returned unchanged by the tool."
  def sign_request(author, project, activity, deployment, request_id) do
    Phoenix.Token.sign(OliWeb.Endpoint, "lti-authoring-request", %{
      "author_id" => author.id,
      "project" => project,
      "activity" => activity,
      "deployment_id" => deployment.deployment_id,
      "request_id" => request_id
    })
  end

  @doc "Checks a validated tool JWT against the signed initiating request and current access."
  def validate_return(claims) do
    with token when is_binary(token) <-
           claims["https://purl.imsglobal.org/spec/lti-dl/claim/data"],
         {:ok, request} <-
           Phoenix.Token.verify(OliWeb.Endpoint, "lti-authoring-request", token, max_age: 1800),
         author <- Accounts.get_author(request["author_id"]),
         {:ok, _, deployment} <- resolve(author, request["project"], request["activity"]),
         true <-
           deployment.deep_linking_enabled and
             deployment.deployment_id == request["deployment_id"],
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

  @doc "Extracts the portable fields of one resource link for the activity content."
  def selection(%{"type" => "ltiResourceLink"} = item) do
    url = item["url"]
    custom = item["custom"]
    valid_url = is_nil(url) or (is_binary(url) and URI.parse(url).scheme in ["https", "http"])

    case valid_url and (is_nil(custom) or is_map(custom)) and
           Enum.all?(["title", "text"], &(is_nil(item[&1]) or is_binary(item[&1]))) do
      true -> {:ok, Map.take(item, ["type", "url", "custom", "title", "text"])}
      false -> {:error, :invalid_selection}
    end
  end
end
