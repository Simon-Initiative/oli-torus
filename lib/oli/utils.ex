defmodule Oli.Utils do
  @doc """
  Generates a random hex string of the given length
  """
  def random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.encode16() |> binary_part(0, length)
  end

  def generate_error_id() do
    random_string(8)
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

  def snake_case_to_friendly(snake_input) do
    String.split(snake_input, "_")
    |> Enum.map(fn word -> String.capitalize(word) end)
    |> Enum.join(" ")
  end

  def format_datetime(datetime) do
    ampm = if datetime.hour < 13, do: "AM", else: "PM"
    hour = if datetime.hour < 13, do: datetime.hour, else: datetime.hour - 12
    minute = if datetime.minute < 10, do: "#{datetime.minute}0", else: datetime.minute
    "#{datetime.month}/#{datetime.day}/#{datetime.year} #{hour}:#{minute} #{ampm}"
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
      # if changeset is valid and doesn't have a name in changes or data, derive name from given_name and family_name
      %Ecto.Changeset{valid?: true, changes: changes, data: data} ->
        case {Map.get(changes, :name), Map.get(data, :name)} do
          {nil, nil} ->
            name =
              "#{Map.get(changes, :given_name) |> value_or(Map.get(data, :given_name)) |> value_or("")} #{Map.get(changes, :family_name) |> value_or(Map.get(data, :family_name)) |> value_or("")}"
              |> String.trim()

            Ecto.Changeset.put_change(changeset, :name, name)

          _ ->
            changeset
        end

      _ ->
        changeset
    end
  end

  def normalize_name(name, given_name, family_name) do
    case {has_non_empty_value(name), has_non_empty_value(given_name), has_non_empty_value(family_name)} do
      {_, true, true} -> "#{family_name}, #{given_name}"
      {false, false, true} -> family_name
      {true, _, _} -> name
      _ -> "Unknown"
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
end
