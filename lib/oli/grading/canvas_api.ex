defmodule Oli.Grading.CanvasApi do

  alias Oli.Delivery.Sections
  alias Oli.Accounts

  def handle_basic_launch(lti_params, user) do
    context_id = lti_params["context_id"]

    case Sections.get_section_by(context_id: context_id) do
      nil -> nil
      section ->
        # capture required canvas specific information from lti launch
        %{protocol: protocol, host: host, port: port} = get_url_parts(lti_params["launch_presentation_return_url"])
        canvas_url = "#{protocol}#{host}#{port}"
        canvas_id = lti_params["custom_canvas_course_id"]

        # update section record with canvas_url
        Sections.update_section(section, %{canvas_url: canvas_url, canvas_id: canvas_id})

        canvas_user_id = lti_params["custom_canvas_user_id"]
        Accounts.update_user(user, %{canvas_id: canvas_user_id})
    end
  end

  def get_assignments(section) do
    %{canvas_url: url, canvas_token: token, canvas_id: canvas_id} = section
    url = "#{url}/api/v1/courses/#{canvas_id}/assignments"

    fetch_all_pages(url, token)
  end

  def create_assignment(section, assignment) do
    %{canvas_url: url, canvas_token: token, canvas_id: canvas_id} = section
    url = "#{url}/api/v1/courses/#{canvas_id}/assignments"
    body = Jason.encode!(%{"assignment" => assignment})

    authenticated_fetch(:post, token, url, body, ["content-type": "application/json; charset=utf-8"])
  end

  def delete_assignment(section, assignment_id) do
    %{canvas_url: url, canvas_token: token, canvas_id: course_id} = section
    url = "#{url}/api/v1/courses/#{course_id}/assignments/#{assignment_id}"

    authenticated_fetch(:delete, token, url)
  end

  def submit_score(section, assignment_id, user_id, score) do
    %{canvas_url: url, canvas_token: token, canvas_id: course_id} = section
    url = "#{url}/api/v1/courses/#{course_id}/assignments/#{assignment_id}/submissions/#{user_id}"
    body = Jason.encode!(%{"submission" => %{ "posted_grade" => score}})

    authenticated_fetch(:put, token, url, body, ["content-type": "application/json; charset=utf-8"])
  end

  def submit_grade_data(section, grade_data) do
    %{canvas_url: url, canvas_token: token, canvas_id: course_id} = section
    url = "#{url}/api/v1/courses/#{course_id}/submissions/update_grades"
    body = Jason.encode!(%{"grade_data" => grade_data})

    authenticated_fetch(:put, token, url, body, ["content-type": "application/json; charset=utf-8"])
  end

  defp authenticated_fetch(method, token, url, body \\ "", headers \\ [], allow_token_refresh \\ true) do
    # get an initial token if token is nil
    token = case token do
      nil -> refresh_token()
      token -> token
    end

    full_headers = [
      "Authorization": "Bearer #{token}",
      "Accept": "application/json; charset=utf-8"]
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
    # refresh token is not supported by this implementation yet. It assumes the token given is
    # valid and does not expire
    throw "API token is either missing or invalid. This canvas API implementation does not support token refresh. "
      <> "Please generate and configure a non-expiring token from canvas before using"
  end

  defp get_url_parts(url) do
    captures = Regex.named_captures(~r/(?<protocol>https?)?[:\/\/]*(?<host>[^\/:]+)(?<port>:[^\/:]+)?/, url)
    protocol = case captures do
      %{"protocol" => protocol} ->
        "#{protocol}://"
      _ ->
        ""
    end
    host = case captures do
      %{"host" => host} ->
        host
      _ ->
        ""
    end
    port = case captures do
      %{"port" => port} ->
        port
      _ ->
        ""
    end

    %{protocol: protocol, host: host, port: port}
  end

  # recursive function that fetches the page at the url given and checks the response
  # for more pages. If another page is available, it recursively fetches that page until
  # there are no more pages
  defp fetch_all_pages(page_url, canvas_token, acc \\ []) do
    case authenticated_fetch(:get, canvas_token, page_url) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200} = res} ->
        assignments = body |> Jason.decode!
        acc = assignments ++ acc

        case next_page_url(res) do
          nil ->
            # no more pages to go, return acc
            acc
          next_url ->
            fetch_all_pages(next_url, canvas_token, acc)
        end
      other_response ->
        other_response
    end
  end

  # parses the next page url in the response header, if it exists
  defp next_page_url(res) do
    case Enum.find(res.headers, fn {key, _} -> key == "link" end) do
      nil -> nil
      {_, link} ->
        # parse next page link from Link header returned
        rel_links = String.split(link, ",")
        next_rel_link =
          rel_links
          |> Enum.map(fn rel_link ->
            # e.g. <http://canvas.edu/api/v1/courses/1/custom_columns?page=2&per_page=10>; rel="next"
            rel_link
            |> String.split(";")
            |> Enum.map(fn s -> String.trim(s) end)
          end)
          |> Enum.find(fn [_link, rel] -> rel == "rel=\"next\"" end)

        case next_rel_link do
          [link, _rel] ->
            # strip off the leading < and trailing >
            String.slice(link, 1, String.length(link) - 2)
          _ -> nil
        end
    end
  end

end
