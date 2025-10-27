defmodule Oli.GoogleDocsImport.TestHelpers do
  @moduledoc """
  Utilities for working with Google Docs importer fixtures during testing.
  """

  alias HTTPoison.Response
  alias Oli.Test.MockHTTP

  @fixtures_dir __DIR__
  @default_headers [{"content-type", "text/markdown; charset=UTF-8"}]
  @ignored_files MapSet.new(["README.md"])

  @doc """
  Returns a sorted list of available fixture names (without directory prefixes).
  """
  def available_fixtures do
    @fixtures_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".md"))
    |> Enum.reject(&MapSet.member?(@ignored_files, &1))
    |> Enum.sort()
  end

  @doc """
  Resolves the absolute path for the given fixture name (with or without extension).
  """
  def fixture_path(name) when is_atom(name), do: fixture_path(Atom.to_string(name))

  def fixture_path(name) when is_binary(name) do
    basename =
      case String.ends_with?(name, ".md") do
        true -> name
        false -> name <> ".md"
      end

    Path.join(@fixtures_dir, basename)
  end

  @doc """
  Loads the fixture as a map containing `:name`, `:path`, `:metadata`, and `:body`.

  Front matter is expected to be defined between leading and trailing `---` delimiters.
  """
  def load_fixture(name) do
    path = fixture_path(name)
    content = File.read!(path)
    {metadata, body} = split_front_matter(content)

    %{
      name: Path.basename(path),
      path: path,
      metadata: metadata,
      body: body
    }
  end

  @doc """
  Sets an expectation on `Oli.Test.MockHTTP` to return the Markdown body for the given `file_id`.

  Additional options:
    * `:status` – defaults to 200.
    * `:response_headers` – defaults to text/markdown headers.
    * `:body_override` – override the body returned instead of the fixture body.
    * `:error` – when present, the expectation returns `{:error, reason}`.
  """
  def expect_markdown_fetch(file_id, fixture_name, opts \\ []) do
    url = markdown_export_url(file_id)
    response = build_response(fixture_name, opts)

    Mox.expect(MockHTTP, :get, fn ^url, _headers, _opts -> response end)
  end

  @doc """
  Constructs the Google Docs Markdown export URL for the given `file_id`.
  """
  def markdown_export_url(file_id) do
    "https://docs.google.com/document/d/#{file_id}/export?format=md"
  end

  defp build_response(fixture_name, opts) do
    case Keyword.fetch(opts, :error) do
      {:ok, reason} ->
        {:error, reason}

      :error ->
        do_build_success_response(fixture_name, opts)
    end
  end

  defp do_build_success_response(fixture_name, opts) do
    %{body: body} = load_fixture(fixture_name)

    body =
      case Keyword.fetch(opts, :body_override) do
        {:ok, override} -> override
        :error -> body
      end

    status = Keyword.get(opts, :status, 200)
    headers = Keyword.get(opts, :response_headers, @default_headers)

    {:ok, %Response{status_code: status, headers: headers, body: body}}
  end

  defp split_front_matter(<<"---\n", rest::binary>>) do
    case String.split(rest, "\n---\n", parts: 2) do
      [front, body] ->
        {parse_front_matter(front), body}

      _ ->
        {%{}, <<"---\n", rest::binary>>}
    end
  end

  defp split_front_matter(content), do: {%{}, content}

  defp parse_front_matter(front) do
    front
    |> String.split("\n", trim: true)
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ":", parts: 2) do
        [key, value] ->
          Map.put(acc, String.trim(key), String.trim(value))

        _ ->
          acc
      end
    end)
  end
end
