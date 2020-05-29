defmodule Oli.Grading.Adapters.LtiV2GradeServices do
  @behaviour Oli.Grading.LtiGradeService

  alias Oli.Delivery.Sections

  def product_family_code() do
    # this adapter is not associated with any particular platform product family
    "any"
  end

  def supported_methods() do
    [
      "get_lineitems",
      "add_lineitem",
      "get_lineitem",
      "change_lineitem",
      "remove_lineitem",
      "get_lineitem_results",
      "add_lineitem_score",
    ]
  end

  def basic_launch(_lti_params) do
    # this adapter doesnt require any additional information from launch, do nothing
    nil
  end

  def get_lineitems(context_id, query_params \\ %{}) do
    {lineitems_url, token} = get_lineitems_url_and_token(context_id)
    url = url_with_query("#{lineitems_url}", query_params)

    authenticated_fetch(:get, token, url)
  end

  def add_lineitem(context_id, lineitem) do
    {lineitems_url, token} = get_lineitems_url_and_token(context_id)
    body = Jason.encode!(lineitem)

    authenticated_fetch(:post, token, lineitems_url, body)
  end

  def get_lineitem(context_id, lineitem_id) do
    {lineitems_url, token} = get_lineitems_url_and_token(context_id)
    url = "#{lineitems_url}/#{lineitem_id}"

    authenticated_fetch(:get, token, url)
  end

  def change_lineitem(context_id, lineitem_id, lineitem) do
    {lineitems_url, token} = get_lineitems_url_and_token(context_id)
    url = "#{lineitems_url}/#{lineitem_id}"
    body = Jason.encode!(lineitem)

    authenticated_fetch(:put, token, url, body)
  end

  def remove_lineitem(context_id, lineitem_id) do
    {lineitems_url, token} = get_lineitems_url_and_token(context_id)
    url = "#{lineitems_url}/#{lineitem_id}"

    authenticated_fetch(:delete, token, url)
  end

  def get_lineitem_results(context_id, lineitem_id, query_params \\ %{}) do
    {lineitems_url, token} = get_lineitems_url_and_token(context_id)
    url = url_with_query("#{lineitems_url}/#{lineitem_id}/results", query_params)

    authenticated_fetch(:get, token, url)
  end

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
