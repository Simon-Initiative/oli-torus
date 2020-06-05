defmodule Oli.Grading.LtiGradeServices do
  @moduledoc """
  Implements LTI 1.3 Grade Services
  """

  alias Oli.Delivery.Sections

  @type context_id :: String.t()
  @type lineitem_id :: String.t()
  @type query_params ::%{optional(String.t()) => String.t() | integer()}

  @typedoc """
  %{
    # Lineitem unique identifier
    "id" => String.t(),

    # Maximum possible score
    "scoreMaximum" => float(),

    # Label to use in the Tool Consumer UI (Gradebook)
    "label" => String.t(),

    # Additional information about the line item; may be used by the tool to identify line items
    # attached to the same resource or resource link (example: grade, originality, participation)
    # maxLength: 256
    "tag" => String.t(),

    # Tool resource identifier for which this line item is receiving scores from
    "resourceId" => String.t(),

    # Id of the tool platform's resource link to which this line item is attached to
    "resourceLinkId" => String.t(),

    "submission" => %{
      # Date and time in ISO 8601 format when a submission can start being submitted by learner
      "startDateTime" => String.t(),

      # Date and time in ISO 8601 format when a submission can last be submitted by learner
      "endDateTime" => String.t(),
  }
  """
  @type lineitem :: %{required(String.t()) => String.t() | float()}

  @typedoc """
  %{
    # Recipient of the score, usually a student. Must be present when publishing a score update
    # through Scores.POST operation.
    "userId" => String.t(),

    # Current score received in the tool for this line item and user, in scale with scoreMaximum
    "scoreGiven" => String.t(),

    # Maximum possible score for this result; It must be present if scoreGiven is present.
    "scoreMaximum" => String.t(),

    # Comment visible to the student about this score.
    "comment" => String.t(),

    # Date and time in ISO 8601 format when the score was modified in the tool. Should use subsecond precision.
    "timestamp" => String.t(),

    # Indicate to the tool platform the status of the user towards the activity's completion.
    "activityProgress" => String.t(),

    # Indicate to the platform the status of the grading process, including allowing to inform when
    # human intervention is needed. A value other than FullyGraded may cause the tool platform to
    # ignore the scoreGiven value if present.
    "gradingProgress" => String.t(),
  }
  """
  @type score :: %{required(String.t()) => String.t()}

  @spec get_lineitems(context_id(), query_params()) :: any()
  def get_lineitems(context_id, query_params \\ %{}) do
    {lineitems_url, token} = get_lineitems_url_and_token(context_id)
    url = url_with_query("#{lineitems_url}", query_params)

    authenticated_fetch(:get, token, url)
  end

  @spec add_lineitem(context_id(), lineitem()) :: any()
  def add_lineitem(context_id, lineitem) do
    {lineitems_url, token} = get_lineitems_url_and_token(context_id)
    body = Jason.encode!(lineitem)

    authenticated_fetch(:post, token, lineitems_url, body)
  end

  @spec get_lineitem(context_id(), lineitem_id()) :: any()
  def get_lineitem(context_id, lineitem_id) do
    {lineitems_url, token} = get_lineitems_url_and_token(context_id)
    url = "#{lineitems_url}/#{lineitem_id}"

    authenticated_fetch(:get, token, url)
  end

  @spec change_lineitem(context_id(), lineitem_id(), lineitem()) :: any()
  def change_lineitem(context_id, lineitem_id, lineitem) do
    {lineitems_url, token} = get_lineitems_url_and_token(context_id)
    url = "#{lineitems_url}/#{lineitem_id}"
    body = Jason.encode!(lineitem)

    authenticated_fetch(:put, token, url, body)
  end

  @spec remove_lineitem(context_id(), lineitem_id()) :: any()
  def remove_lineitem(context_id, lineitem_id) do
    {lineitems_url, token} = get_lineitems_url_and_token(context_id)
    url = "#{lineitems_url}/#{lineitem_id}"

    authenticated_fetch(:delete, token, url)
  end

  @spec get_lineitem_results(context_id(), lineitem_id(), query_params()) :: any()
  def get_lineitem_results(context_id, lineitem_id, query_params \\ %{}) do
    {lineitems_url, token} = get_lineitems_url_and_token(context_id)
    url = url_with_query("#{lineitems_url}/#{lineitem_id}/results", query_params)

    authenticated_fetch(:get, token, url)
  end

  @spec add_lineitem_score(context_id(), lineitem_id(), score()) :: any()
  def add_lineitem_score(context_id, lineitem_id, score) do
    {lineitems_url, token} = get_lineitems_url_and_token(context_id)
    url = "#{lineitems_url}/#{lineitem_id}/scores"
    body = Jason.encode!(score)

    authenticated_fetch(:post, token, url, body)
  end

  defp authenticated_fetch(method, token, url, body \\ "", headers \\ [], allow_token_refresh \\ true) do
    # get an initial token if token is nil
    token = case token do
      nil -> refresh_token()
      token -> token
    end

    full_headers = [
      "Authorization": "Bearer #{token}",
      "Accept": "Application/json; Charset=utf-8"]
    ++ headers

    result = case method do
      :get ->
        HTTPoison.get(url, full_headers)
      :post ->
        HTTPoison.post(url, body, full_headers)
      :put ->
        HTTPoison.put(url, body, full_headers)
      :delete ->
        HTTPoison.delete(url, full_headers)
    end

    case result do
      {:ok, %HTTPoison.Response{status_code: 401} = response} when allow_token_refresh ->
        # the response will contain WWW-Authenticate header to indicate a token refresh is required
        case Enum.find(response.headers, fn {key, _value} -> key == "WWW-Authenticate" end) do
          nil ->
            {:ok, response}
          _ ->
            # get a new token and try again
            token = refresh_token()
            authenticated_fetch(method, token, url, body, headers, false)
        end
      other_result ->
        other_result
    end
  end

  defp refresh_token() do
    # TODO: implement me
  end

  defp get_lineitems_url_and_token(context_id) do
    case Sections.get_section_by(context_id: context_id) do
      nil ->
        {:error, "Section does not exist for context_id #{context_id}"}
      section ->
        {section.lti_lineitems_url, section.lti_lineitems_token}
    end
  end

  defp url_with_query(url, query_params),
    do: "#{url}#{build_query_str(query_params)}"

  defp build_query_str(query_params) do
    ""
    |> serialize_param(query_params, "limit")
    |> serialize_param(query_params, "page")
    |> serialize_param(query_params, "resource_link_id")
    |> serialize_param(query_params, "tag")
    |> serialize_param(query_params, "resource_id")
    |> finalize_query_str()
  end

  defp serialize_param(acc, query_params, name) do
    case query_params do
      %{^name => value} ->
        acc <> "&#{name}=#{value}"
      _ ->
        acc
    end
  end

  defp finalize_query_str(acc), do: Regex.replace(~r/^&/, acc, "?")

end
