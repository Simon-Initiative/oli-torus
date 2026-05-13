defmodule Oli.InstructorDashboard.Email.LinkValidator do
  @moduledoc """
  Shared link validation for email content. A URL is safe iff it is a
  relative path that resolves to a real `OliWeb.Router` route — no
  scheme, no host, no `..` segments.

  Implements the OWASP Unvalidated-Redirects allowlist pattern for
  internal-only destinations. No Hex library covers
  (relative-only + resolves-to-real-router-route): Phoenix.HTML's
  `valid_destination?/1` is private and only rejects `javascript:`;
  `html_sanitize_ex` operates on rendered HTML strings, not Slate JSON.

  Refs:
    * https://cheatsheetseries.owasp.org/cheatsheets/Unvalidated_Redirects_and_Forwards_Cheat_Sheet.html
    * https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html
  """

  alias Oli.Resources.PageContent

  @spec valid_internal_path?(any()) :: boolean()
  def valid_internal_path?(url) when is_binary(url) do
    uri = URI.parse(url)

    cond do
      not is_nil(uri.scheme) -> false
      not is_nil(uri.host) -> false
      is_nil(uri.path) -> false
      not String.starts_with?(uri.path, "/") -> false
      String.contains?(uri.path, "..") -> false
      true -> Phoenix.Router.route_info(OliWeb.Router, "GET", uri.path, "_") != :error
    end
  end

  def valid_internal_path?(_), do: false

  @doc """
  Walks a Slate JSON body, returns deduplicated URLs from `%{"type" => "a"}`
  nodes whose `href` is not a valid internal path.
  """
  @spec collect_unsafe_links([map()]) :: [String.t()]
  def collect_unsafe_links(body_slate) when is_list(body_slate) do
    %{"model" => body_slate}
    |> PageContent.flat_filter(&match?(%{"type" => "a"}, &1))
    |> Enum.map(&Map.get(&1, "href", ""))
    |> Enum.uniq()
    |> Enum.reject(&valid_internal_path?/1)
  end

  def collect_unsafe_links(_), do: []
end
