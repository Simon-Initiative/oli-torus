defmodule Oli.Utils do
  require Logger

  import Ecto.Changeset
  import Ecto.Query, warn: false

  @url_regex ~r/(https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9]+\.[^\s]{2,}|www\.[a-zA-Z0-9]+\.[^\s]{2,})/i

  @doc """
  Normalizes a string by removing all whitespace and replacing it with a single space
  """
  def normalize_whitespace(str) when is_binary(str) do
    str
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  def normalize_whitespace(s), do: s

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

    Oli.Utils.Appsignal.capture_error(msg, metadata)

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

  def confirm_email_if_verified(changeset) do
    if get_change(changeset, :email_verified) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      change(changeset, email_confirmed_at: now)
    else
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

            fn_length = String.length(first_name)
            ln_length = String.length(last_name)

            # Check if the first and last names should be shortened
            {first_name, last_name} =
              case {fn_length + ln_length > 255, fn_length > 127, ln_length > 127} do
                {false, _, _} ->
                  {first_name, last_name}

                {true, true, true} ->
                  {"#{String.slice(first_name, 0, 124)}...",
                   "#{String.slice(last_name, 0, 124)}..."}

                {true, true, false} ->
                  {"#{String.slice(first_name, 0, 124)}...", last_name}

                {true, false, true} ->
                  {first_name, "#{String.slice(last_name, 0, 124)}..."}
              end

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

  def put_email_confirmed_at(changeset) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    Ecto.Changeset.put_change(changeset, :email_confirmed_at, now)
  end

  def lowercase_email(changeset) do
    case changeset.changes[:email] do
      nil -> changeset
      _ -> Ecto.Changeset.update_change(changeset, :email, &String.downcase/1)
    end
  end

  def validate_required_if(%Ecto.Changeset{valid?: false} = changeset, _fields, _condition),
    do: changeset

  def validate_required_if(changeset, fields, condition) when is_function(condition) do
    if condition.(changeset) do
      Ecto.Changeset.validate_required(changeset, fields)
    else
      changeset
    end
  end

  def validate_number_if(
        changeset,
        field,
        condition,
        greater_than_or_equal_to,
        less_than_or_equal_to
      ) do
    if condition.(changeset) do
      Ecto.Changeset.validate_number(
        changeset,
        field,
        greater_than_or_equal_to: greater_than_or_equal_to,
        less_than_or_equal_to: less_than_or_equal_to
      )
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

  def unique_constraint_if(changeset, fields, condition, opts \\ []) do
    if condition.(changeset) do
      Ecto.Changeset.unique_constraint(changeset, fields, opts)
    else
      changeset
    end
  end

  def foreign_key_constraint_if(changeset, field, condition, opts \\ []) do
    if condition.(changeset) do
      Ecto.Changeset.foreign_key_constraint(changeset, field, opts)
    else
      changeset
    end
  end

  def validate_dates_consistency(changeset, start_date_field, end_date_field) do
    changeset =
      validate_change(changeset, start_date_field, fn _, field ->
        # check if the start date is after the end date
        if Timex.compare(field, get_field(changeset, end_date_field)) == 1 do
          [{start_date_field, "must be before the end date"}]
        else
          []
        end
      end)

    validate_change(changeset, end_date_field, fn _, field ->
      # check if the end date is before the start date
      if Timex.compare(field, get_field(changeset, start_date_field)) == -1 do
        [{end_date_field, "must be after the start date"}]
      else
        []
      end
    end)
  end

  @doc """
  Updates specific fields in a given Ecto changeset using a provided function.

  ## Parameters:

  - `changeset`: An Ecto.Changeset that contains the changes we want to apply to.
  - `fields`: A list of fields (atoms) that we want to update within the changeset.
  - `fun`: A function that will be applied to the current value of each specified field in the changeset. This function should accept the current value of the field and return the new value.

  ## Returns:

  - A new Ecto.Changeset with the specified fields updated based on the provided function.

  ## Example:

  Suppose you have a changeset for a User schema and you want to update the fields `:first_name` and `:last_name` to be in uppercase:

      changeset = %Ecto.Changeset{data: %User{first_name: "john", last_name: "doe"}}
      updated_changeset = update_changes(changeset, [:first_name, :last_name], &String.upcase/1)

  The `updated_changeset` will now contain the values "JOHN" for `:first_name` and "DOE" for `:last_name`.

  """
  def update_changes(changeset, fields, fun) do
    Enum.reduce(fields, changeset, fn field, changeset ->
      Ecto.Changeset.update_change(changeset, field, fun)
    end)
  end

  @spec read_json_file(
          binary
          | maybe_improper_list(
              binary | maybe_improper_list(any, binary | []) | char,
              binary | []
            )
        ) :: {:error, atom} | {:ok, false | nil | true | binary | list | number | map}
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
  Ensures a number (integer/float) is a string
  """
  def ensure_number_is_string(value) when is_integer(value), do: Integer.to_string(value)
  def ensure_number_is_string(value) when is_float(value), do: Float.to_string(value)
  def ensure_number_is_string(value), do: value

  @doc """
  Detects all urls in a string and replaces them with hyperlinks.
  """
  def find_and_linkify_urls_in_string(string) do
    Regex.replace(@url_regex, string, fn _, url ->
      absolute_url =
        if is_url_absolute(url) do
          url
        else
          "//" <> url
        end

      "<a href=\"#{absolute_url}\" target=\"_blank\">#{url}</a>"
    end)
  end

  @doc """
  Receives a map with conditions on entity's fields, and returns dynamic conditions to be used in an Ecto query.
  """
  def filter_conditions(filter) do
    Enum.reduce(filter, false, fn {field, value}, conditions ->
      dynamic([entity], field(entity, ^field) == ^value or ^conditions)
    end)
  end

  @doc """
  Creates a temporary directory and calls the given function with the file path as an argument.
  The directory will be deleted after the function returns.

  If type: :file is passed, the function will create a temporary file instead of a directory.
  """
  def use_tmp(func, opts \\ []) do
    # create tmp file
    tmp_path =
      Path.join([
        System.tmp_dir!(),
        uuid()
      ])

    if Keyword.get(opts, :type) == :file do
      File.touch!(tmp_path)
    else
      File.mkdir!(tmp_path)
    end

    # ensure the file will get cleaned up even if the function fails
    result =
      try do
        func.(tmp_path)
      rescue
        e ->
          # cleanup
          File.rm_rf!(tmp_path)

          Logger.error(Exception.format(:error, e, __STACKTRACE__))
          reraise e, __STACKTRACE__
      end

    # cleanup
    File.rm_rf!(tmp_path)

    result
  end

  @doc """
  Converts an atom into a readable string by replacing underscores with empty spaces.
  """
  def stringify_atom(atom), do: atom |> Atom.to_string() |> String.replace("_", " ")

  @doc """
  Returns the value from a nested map given a list of keys. If the value is not found, returns the default value.
  """
  @spec get_in(map :: map, keys :: list, default :: any) :: any
  def get_in(map, keys, default) do
    case get_in(map, keys) do
      nil -> default
      value -> value
    end
  end

  @doc """
  Returns the value passed in.

  ## Examples
  iex> Utils.identity(1)
  1
  """
  @spec identity(any) :: any
  def identity(x), do: x

  @doc """
  Validate the inequality between two numbers

  ## Examples

      validate_greater_than_or_equal(changeset, :from, :to)
      validate_greater_than_or_equal(changeset, :from, :to, allow_equal: true)

  """
  def validate_greater_than_or_equal(changeset, from, to, opts \\ []) do
    {_, from_value} = fetch_field(changeset, from)
    {_, to_value} = fetch_field(changeset, to)
    allow_equal = Keyword.get(opts, :allow_equal, false)

    if compare(from_value, to_value, allow_equal) do
      changeset
    else
      message = "#{to} must be greater than #{from}"
      add_error(changeset, from, message, to_field: to)
    end
  end

  defp compare(f, t, true), do: f <= t
  defp compare(f, t, false), do: f < t
end
