defmodule Oli.Utils do
  require Logger

  import Ecto.Changeset

  @urlRegex ~r/(https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9]+\.[^\s]{2,}|www\.[a-zA-Z0-9]+\.[^\s]{2,})/i

  @doc """
  Generates a random hex string of the given length
  """
  def random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.encode16() |> binary_part(0, length)
  end

  @doc """
  Logs an error message with a unique identifier. Returns a tuple with the unique identifier
  and a user focused error message that contains a unique identifier for support. This unique
  identifier is included in the server side log message so it can be found quickly.

  Takes in a short message (msg) describing the error (this will be displayed to a user) and
  an optional metadata object (metadata) which will be kernel inspected in the server side log.
  Metadata is not exposed in the user facing error message.
  """
  def log_error(msg, metadata \\ nil) do
    error_id = uuid() |> String.upcase()

    metadata_str =
      case metadata do
        nil ->
          ""

        metadata ->
          ": #{inspect(metadata)}"
      end

    Logger.error("##{error_id} #{msg}#{metadata_str}")

    error_msg = "#{msg}. Please try again or contact support with issue ##{error_id}."

    {error_id, error_msg}
  end

  @doc """
  Returns the specified value if not nil, otherwise returns the default value
  """
  def value_or(value, default_value) do
    case value do
      nil ->
        default_value

      value ->
        value
    end
  end

  def has_non_empty_value(v) do
    !is_nil(v) and v != ""
  end

  @doc """
  Renders the specified view template with inner content in the do: block
  """
  def render(view, template, assigns, do: content) do
    Phoenix.View.render(view, template, Map.put(assigns, :inner_content, content))
  end

  def snake_case_to_friendly(input) when is_atom(input) do
    input
    |> Atom.to_string()
    |> snake_case_to_friendly()
  end

  def snake_case_to_friendly(snake_input) do
    String.split(snake_input, "_")
    |> Enum.map(fn word -> String.capitalize(word) end)
    |> Enum.join(" ")
  end

  @doc """
  Traps a nil and wraps it in an {:error, _} tuple, otherwise passes thru
  the non-nil result as {:ok, result}
  """
  def trap_nil(result, description_tag \\ :not_found) do
    case result do
      nil -> {:error, {description_tag}}
      _ -> {:ok, result}
    end
  end

  def maybe_create_unique_sub(changeset) do
    case changeset do
      # if changeset is valid and doesn't have a name in changes or data, derive name from given_name and family_name
      %Ecto.Changeset{valid?: true, changes: changes, data: data} ->
        case {Map.get(changes, :sub), Map.get(data, :sub)} do
          {nil, nil} ->
            sub = UUID.uuid4()

            Ecto.Changeset.put_change(changeset, :sub, sub)

          _ ->
            changeset
        end

      _ ->
        changeset
    end
  end

  def maybe_name_from_given_and_family(changeset) do
    case changeset do
      # here we try to derive a full display name using changes or data for name
      # using the fields :name, :given_name and :family_name.
      #
      # if changeset is valid and doesn't have a name in changes, but there is a change
      # for given_name or family_name, then derive name from given_name and family_name
      %Ecto.Changeset{valid?: true, changes: changes, data: data} ->
        case {
          Map.has_key?(changes, :name),
          Map.has_key?(changes, :given_name) or Map.has_key?(changes, :family_name)
        } do
          {false, true} ->
            first_name =
              Map.get(changes, :given_name)
              |> value_or(Map.get(data, :given_name))
              |> value_or("")

            last_name =
              Map.get(changes, :family_name)
              |> value_or(Map.get(data, :family_name))
              |> value_or("")

            name =
              "#{first_name} #{last_name}"
              |> String.trim()

            Ecto.Changeset.put_change(changeset, :name, name)

          _ ->
            changeset
        end

      _ ->
        changeset
    end
  end

  def lowercase_email(changeset) do
    Ecto.Changeset.update_change(changeset, :email, &String.downcase/1)
  end

  def validate_required_if(changeset, fields, condition) do
    if condition.(changeset) do
      Ecto.Changeset.validate_required(changeset, fields)
    else
      changeset
    end
  end

  def validate_acceptance_if(changeset, field, condition, message \\ "must be accepted") do
    if condition.(changeset) do
      Ecto.Changeset.validate_acceptance(changeset, field, message: message)
    else
      changeset
    end
  end

  def validate_dates_consistency(changeset, start_date_field, end_date_field) do
    validate_change(changeset, start_date_field, fn _, field ->
      # check if the start date is after the end date
      if Timex.compare(field, get_field(changeset, end_date_field)) == 1 do
        [{start_date_field, "must be before the end date"}]
      else
        []
      end
    end)
  end

  def read_json_file(filename) do
    with {:ok, body} <- File.read(filename), {:ok, json} <- Poison.decode(body), do: {:ok, json}
  end

  def positive_or_nil(num) do
    if num > 0 do
      num
    else
      nil
    end
  end

  @doc """
  Returns the base url for torus using the application endpoint configuration
  """
  def get_base_url() do
    url_config = Application.fetch_env!(:oli, OliWeb.Endpoint)[:url]

    port =
      case Keyword.get(url_config, :port, 80) do
        80 -> ""
        443 -> ""
        p -> ":#{p}"
      end

    "https://#{Keyword.get(url_config, :host, "localhost")}#{port}"
  end

  @doc """
  Returns true if the given URL is absolute
  """
  def is_url_absolute(url) do
    String.match?(url, ~r/^(?:[a-z]+:)?\/\//i)
  end

  @doc """
  Returns the given url or path ensuring it is absolute. If a relative path is given, then
  the configured base url will be prepended
  """
  def ensure_absolute_url(nil), do: ""

  def ensure_absolute_url(url) do
    if is_url_absolute(url) do
      url
    else
      get_base_url() <> ensure_prepended_slash(url)
    end
  end

  defp ensure_prepended_slash(url) do
    if String.starts_with?(url, "/") do
      url
    else
      "/#{url}"
    end
  end

  @doc """
  Generates a shortened v4 UUID encoded as base57
  """
  def uuid() do
    {:ok, uuid} = ShortUUID.encode(UUID.uuid4())
    uuid
  end

  @doc """
  Zip up the given filename and content tuples
  """
  def zip(filename_content_tuples, zip_filename) do
    {:ok, {_filename, data}} =
      :zip.create(
        zip_filename,
        filename_content_tuples,
        [:memory]
      )

    data
  end

  # ensure that the JSON that we write to files is nicely formatted
  def pretty(map) do
    Jason.encode_to_iodata!(map)
    |> Jason.Formatter.pretty_print()
  end

  @doc """
  Converts a map with string keys into a map with atom keys.
  """
  def atomize_keys(map) do
    for {key, val} <- map, into: %{}, do: {String.to_atom(key), val}
  end

  @doc """
  Converts a string to a boolean.
  """
  def string_to_boolean("true"), do: true
  def string_to_boolean(_bool), do: false

  @doc """
  Detects all urls in a string and replaces them with hyperlinks.
  """
  def find_and_linkify_urls_in_string(string) do
    Regex.replace(@urlRegex, string, fn _, url ->
      absolute_url =
        if is_url_absolute(url) do
          url
        else
          "//" <> url
        end

      "<a href=\"#{absolute_url}\" target=\"_blank\">#{url}</a>"
    end)
  end

end
