defmodule OliWeb.Common.Utils do
  import OliWeb.Common.FormatDateTime

  alias Oli.Accounts.{User, Author}
  alias OliWeb.Common.SessionContext

  def name(%User{guest: true}) do
    "Guest Student"
  end

  def name(%User{} = user) do
    name(user.name, user.given_name, user.family_name)
  end

  def name(%Author{} = author) do
    name(author.name, author.given_name, author.family_name)
  end

  def name(name, given_name, family_name) do
    case {has_value(name), has_value(given_name), has_value(family_name)} do
      {_, true, true} -> "#{family_name}, #{given_name}"
      {false, false, true} -> family_name
      {true, _, _} -> name
      _ -> "Unknown"
    end
  end

  def render_date(item, attr_name, %SessionContext{} = ctx) do
    opts = [ctx: ctx, show_timezone: false]
    render_date_with_opts(item, attr_name, opts)
  end

  def render_date(item, attr_name, %Plug.Conn{} = conn) do
    opts = [conn: conn, show_timezone: false]
    render_date_with_opts(item, attr_name, opts)
  end

  def render_relative_date(item, attr_name, ctx) do
    opts = [ctx: ctx, precision: :relative]
    render_date_with_opts(item, attr_name, opts)
  end

  @spec render_precise_date(map, any, any) :: binary
  def render_precise_date(item, attr_name, ctx) do
    opts = [ctx: ctx, precision: :minutes]
    render_date_with_opts(item, attr_name, opts)
  end

  def render_date_with_opts(item, attr_name, opts), do: date(Map.get(item, attr_name), opts)

  @doc """
    Rounds up a grading score to two significant figures.
    For numbers with no decimals, or non-significant zeros after the comma, it keeps only one zero

    ## Examples
    iex> format_score(200.0)
    200.0

    iex> format_score(120.2333)
    120.23

    iex> format_score(88.00)
    88.0

    iex> format_score(78.479)
    78.48

    iex> format_score(0.0)
    0.0
  """
  @spec format_score(float) :: float
  def format_score(score) when is_float(score) do
    Float.round(score, 2)
  end

  def format_score(score) when is_integer(score) do
    score
  end

  def format_score(score) when is_nil(score) do
    "-"
  end

  defp has_value(v) do
    !is_nil(v) and v != ""
  end

  def render_version(edition, major, minor) do
    "v#{edition}.#{major}.#{minor}"
  end

  @doc """
    Given a datetime range defined by a start date and an end date, it returns a datetime string that defines a limit (min or max) for one of the dates based on the other.
    This limit is used to restrict the possible values that can be selected in a datetime input.

    A restriction for the datetime input is added if the date that is being edited was nil before, so it is not possible to calculate a time distance.
    The time limit does not work well in some browsers, allowing the user to select a time that is not valid. That is why for this particular case we don't allow start and end dates to be equal.
    Depending on the case, we add or substract a day to the limit to achieve that.

    If the date was not nil, we don't need to set a limit since we can calculate the time distance accordingly.

    ## Examples
    iex> datetime_input_limit(:start_date, %{start_date: nil, end_date: ~U[2023-09-06 13:28:00Z]}, %{SessionContext.init() | local_tz: "America/Montevideo"})
    "2023-09-05T10:28"

    iex> datetime_input_limit(:start_date, %{start_date: ~U[2023-09-01 13:28:00Z], end_date: ~U[2023-09-06 13:28:00Z]}, %{SessionContext.init() | local_tz: "America/Montevideo"})
    ""

    iex> datetime_input_limit(:end_date, %{start_date: ~U[2023-09-02 13:28:00Z], end_date: nil}, %{SessionContext.init() | local_tz: "America/Montevideo"})
    "2023-09-03T10:28"

    iex> datetime_input_limit(:end_date, %{start_date: ~U[2023-09-02 13:28:00Z], end_date: ~U[2023-09-03 13:28:00Z]}, %{SessionContext.init() | local_tz: "America/Montevideo"})
    ""
  """

  def datetime_input_limit(
        :start_date,
        %{start_date: nil = _old_start_date, end_date: end_date},
        ctx
      )
      when not is_nil(end_date) do
    end_date
    |> convert_datetime(ctx)
    |> DateTime.add(-1, :day)
    |> format_datetime(precision: :simple_iso8601)
  end

  def datetime_input_limit(:start_date, _settings, _ctx), do: ""

  def datetime_input_limit(
        :end_date,
        %{start_date: start_date, end_date: nil = _old_end_date},
        ctx
      )
      when not is_nil(start_date) do
    start_date
    |> convert_datetime(ctx)
    |> DateTime.add(1, :day)
    |> format_datetime(precision: :simple_iso8601)
  end

  def datetime_input_limit(:end_date, _settings, _ctx), do: ""

  @doc """
  Preserves the time distance between the start and end dates when one of them is changed, and returns the new start and end dates and an atom indicating which date was updated to preserve the distance.

  If the new start date (end date) or the existing end date (start date) are nil, we don't need to preserve the distance.
  If the new start date (end date) is before (after) the existing end date (start date), we don't need to preserve the distance.

  iex> maybe_preserve_dates_distance(:start_date, ~U[2023-09-04 13:28:00Z], %{start_date: ~U[2023-09-01 13:28:00Z], end_date: ~U[2023-09-02 13:28:00Z]})
  {~U[2023-09-04 13:28:00Z], ~U[2023-09-05 13:28:00Z], :end_date}

  iex> maybe_preserve_dates_distance(:end_date, nil, %{start_date: ~U[2023-09-01 13:28:00Z], end_date: ~U[2023-09-02 13:28:00Z]})
  {~U[2023-09-01 13:28:00Z], nil, nil}
  """
  def maybe_preserve_dates_distance(:start_date, new_start_date, %{end_date: end_date})
      when is_nil(new_start_date) or is_nil(end_date) do
    {new_start_date, end_date, nil}
  end

  def maybe_preserve_dates_distance(:start_date, new_start_date, setting) do
    case DateTime.compare(new_start_date, setting.end_date) do
      :lt ->
        {new_start_date, setting.end_date, nil}

      _gt_or_eq ->
        # Calculate previous time difference and apply it to the new end date
        diff = DateTime.diff(setting.end_date, setting.start_date)
        new_end_date = DateTime.add(new_start_date, diff)

        {new_start_date, new_end_date, :end_date}
    end
  end

  def maybe_preserve_dates_distance(:end_date, new_end_date, %{start_date: start_date})
      when is_nil(new_end_date) or is_nil(start_date) do
    {start_date, new_end_date, nil}
  end

  def maybe_preserve_dates_distance(:end_date, new_end_date, setting) do
    case DateTime.compare(new_end_date, setting.start_date) do
      :gt ->
        {setting.start_date, new_end_date, nil}

      _lt_or_eq ->
        # Calculate previous time difference and apply it to the new start date
        diff = DateTime.diff(setting.start_date, setting.end_date)
        new_start_date = DateTime.add(new_end_date, diff)

        {new_start_date, new_end_date, :start_date}
    end
  end

  @doc """
  Checks if a given URL is a YouTube video.

  ## Examples

      iex> is_youtube_video?("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      true

      iex> is_youtube_video?("https://youtu.be/dQw4w9WgXcQ")
      true

      iex> is_youtube_video?("https://www.example.com/video.mp4")
      false
  """
  def is_youtube_video?(video_url),
    do: String.contains?(video_url, "youtube.com") or String.contains?(video_url, "youtu.be")

  @doc """
  Converts a YouTube video URL to a YouTube preview image URL.

  ## Examples

      iex> convert_to_youtube_image_url("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg"

      iex> convert_to_youtube_image_url("https://youtu.be/dQw4w9WgXcQ")
      "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg"

      iex> convert_to_youtube_image_url("https://www.example.com/video.mp4")
      nil
  """
  def convert_to_youtube_image_url(video_url) do
    regex = ~r/^.*(youtu\.be\/|v\/|u\/\w\/|embed\/|watch\?v=|&v=)([^#&?]*).*/

    case Regex.run(regex, video_url) do
      [_, _, video_id] when byte_size(video_id) == 11 ->
        "https://img.youtube.com/vi/#{video_id}/hqdefault.jpg"

      _ ->
        nil
    end
  end

  @doc """
    Extracts the text for a feedback item from an attempt.
  """
  def extract_feedback_text(activity_attempts) do
    activity_attempts
    |> Enum.flat_map(&extract_from_activity_attempt/1)
  end

  defp extract_from_activity_attempt(%{part_attempts: part_attempts}) do
    part_attempts
    |> Enum.flat_map(&extract_from_part_attempt/1)
  end

  defp extract_from_part_attempt(%{feedback: %{"content" => content}}) do
    content
    |> Enum.map(&extract_text/1)
  end

  defp extract_from_part_attempt(%{feedback: nil}), do: []

  defp extract_text(%{"children" => children}) do
    children
    |> Enum.map(& &1["text"])
    |> Enum.join(" ")
  end
end
