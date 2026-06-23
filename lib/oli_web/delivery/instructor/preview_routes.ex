defmodule OliWeb.Delivery.Instructor.PreviewRoutes do
  @moduledoc """
  Route helpers for instructor preview surfaces.
  """

  use OliWeb, :verified_routes

  def lesson_path(section_slug, revision_slug, params \\ [])

  def lesson_path(section_slug, revision_slug, params) when params in [[], %{}],
    do: ~p"/sections/#{section_slug}/preview/lesson/#{revision_slug}"

  def lesson_path(section_slug, revision_slug, params),
    do: ~p"/sections/#{section_slug}/preview/lesson/#{revision_slug}?#{params}"

  def learn_path(section_slug, params \\ [])

  def learn_path(section_slug, params) when params in [[], %{}],
    do: ~p"/sections/#{section_slug}/preview/learn"

  def learn_path(section_slug, params),
    do: ~p"/sections/#{section_slug}/preview/learn?#{params}"

  def page_path(section_slug, revision_slug, params \\ [])

  def page_path(section_slug, revision_slug, params) when params in [[], %{}],
    do: ~p"/sections/#{section_slug}/preview/page/#{revision_slug}"

  def page_path(section_slug, revision_slug, params),
    do: ~p"/sections/#{section_slug}/preview/page/#{revision_slug}?#{params}"

  def container_path(section_slug, revision_slug, params \\ [])

  def container_path(section_slug, revision_slug, params) when params in [[], %{}],
    do: ~p"/sections/#{section_slug}/preview/container/#{revision_slug}"

  def container_path(section_slug, revision_slug, params),
    do: ~p"/sections/#{section_slug}/preview/container/#{revision_slug}?#{params}"

  def resource_path(section_slug, descriptor, params \\ [])

  def resource_path(section_slug, %{"type" => "container", "slug" => slug}, params),
    do: container_path(section_slug, slug, params)

  def resource_path(section_slug, %{"type" => "page", "slug" => slug}, params),
    do: lesson_path(section_slug, slug, params)

  def resource_path(_section_slug, nil, _params), do: nil

  def update_learn_path(request_path, section_slug, params \\ %{}) do
    params =
      params
      |> Enum.into(%{})
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
      |> Map.new()

    case URI.parse(request_path || "") do
      %URI{path: path, query: query} ->
        if path in ["/sections/#{section_slug}/preview/learn", "/sections/#{section_slug}/learn"] do
          current_params = Plug.Conn.Query.decode(query || "")
          learn_path(section_slug, Map.merge(current_params, stringify_keys(params)))
        else
          learn_path(section_slug, stringify_keys(params))
        end

      _ ->
        learn_path(section_slug, stringify_keys(params))
    end
  end

  defp stringify_keys(params) do
    Map.new(params, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end
end
