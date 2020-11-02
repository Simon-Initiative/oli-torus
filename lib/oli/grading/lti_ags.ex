defmodule Oli.Grading.LTI_AGS do

  @moduledoc """
  Implementation of LTI Assignment and Grading Services (LTI AGS) version 2.0.

  For information on the standard, see:
  https://www.imsglobal.org/spec/lti-ags/v2p0/

  This module contains no dependencies on attempts, resources, or any other delivery specific construct.
  """

  @lti_ags_claim_url "https://purl.imsglobal.org/spec/lti-ags/claim/endpoint"
  @lineitem_scope_url "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem"
  @scores_scope_url "https://purl.imsglobal.org/spec/lti-ags/scope/score"

  alias Oli.Grading.Score
  alias Oli.Grading.LineItem

  @doc """
  Post a score to an existing line item.
  """
  def post_score(%Score{} = score, %LineItem{} = line_item) do

    url = "#{line_item.id}/scores"
    body = Jason.encode(score)
    headers = [{"Content-Type", "application/json"}]

    with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <- HTTPoison.post(url, body, headers),
      {:ok, result} <- Jason.decode(body)
    do
      {:ok, result}
    else
      _ -> {:error, "Error posting score"}
    end

  end

  @doc """
  Creates a line item for a resource id, if one does not exist.  Whether or not the
  line item is created or already exists, this function returns a line item struct wrapped
  in a {:ok, line_item} tuple.  On error, returns a {:error, error} tuple.
  """
  def fetch_or_create_line_item(line_items_service_url, resource_id, score_maximum, label) do

    # Grade passback 2.0 lineitems endpoint allows a GET request with a query
    # param filter.  We use that to request only the lineitem that corresponds
    # to this particular resource_id.  "resource_id", from grade passback 2.0
    # perspective is simply an identifier that the tool uses for a lineitem and its use
    # here as a Torus "resource_id" is strictly coincidence.
    request_url = "#{line_items_service_url}?resource_id=#{resource_id}"

    with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <- HTTPoison.get(request_url),
      {:ok, result} <- Jason.decode(body)
    do
      case result do
        [] -> create_line_item(line_items_service_url, resource_id, score_maximum, label)
        [line_item] -> {:ok, line_item}
      end
    else
      _ -> {:error, "Error retrieving existing line items"}
    end

  end

  @doc """
  Creates a line item for a resource id. Tthis function returns a line item struct wrapped
  in a {:ok, line_item} tuple.  On error, returns a {:error, error} tuple.
  """
  def create_line_item(line_items_service_url, resource_id, score_maximum, label) do

    line_item = %LineItem{
      scoreMaximum: score_maximum,
      resourceId: resource_id,
      label: label
    }

    body = Jason.encode([line_item])
    headers = [{"Content-Type", "application/json"}]

    with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <- HTTPoison.post(line_items_service_url, body, headers),
      {:ok, result} <- Jason.decode(body)
    do
      {:ok, %LineItem{
        id: Map.get(result, "id"),
        scoreMaximum: Map.get(result, "scoreMaximum"),
        resourceId: Map.get(result, "resource_id"),
        label: Map.get(result, "label"),
      }}
    else
      _ -> {:error, "Error creating new line item"}
    end

  end

  @doc """
  Returns true if grade passback service is enabled with the necessary scopes. The
  necessary scopes are the lineitem scope to read all lineitems and create new ones
  and the scores scope, to be able to post new scores. Also verifies that the lineitems
  endpoint is present.
  """
  def grade_passback_enabled?(lti_launch_params) do

    case Map.get(lti_launch_params, @lti_ags_claim_url) do
      nil -> false
      config ->


        Map.has_key?(config, "lineitems") and has_scope?(config, @lineitem_scope_url) and has_scope?(config, @scores_scope_url)
    end

  end

  @doc """
  Returns the lineitems URL from LTI launch params. If not present returns nil.
  """
  def get_line_items_url(lti_launch_params) do
    Map.get(lti_launch_params, @lti_ags_claim_url, %{}) |> Map.get("lineitems")
  end

  @doc """
  Returns true if the LTI AGS claim has a particular scope url, false if it does not.
  """
  def has_scope?(lti_ags_claim, scope_url) do

    case Map.get(lti_ags_claim, "scope", [])
    |> Enum.find(nil, fn url -> scope_url == url end) do
      nil -> false
      _ -> true
    end

  end


end
