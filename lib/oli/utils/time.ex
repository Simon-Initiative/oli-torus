defmodule Oli.Utils.Time do
  alias Oli.Accounts
  alias Oli.Accounts.Author

  import Oli.Utils, only: [value_or: 2]

  def now() do
    {:ok, datetime} = DateTime.now("Etc/UTC")
    datetime
  end

  def one_minute, do: 60
  def one_hour, do: one_minute() * 60
  def one_day, do: one_hour() * 24
  def one_week, do: one_day() * 7

  @doc """
  Returns a human readable formatted duration
  """
  def duration(from, to) do
    Timex.diff(from, to, :milliseconds)
    |> Timex.Duration.from_milliseconds()
    |> Timex.format_duration(:humanized)
  end

  @doc """
  Converts a datetime to a specific timezone based on a user's session or specified timezone
  and returns an ISO 8601 formatted string.

  This session timezone information is set and updated on the timezone api call every time a
  page is loaded.

  ## Examples
      iex> date(datetime, conn)
      "December 31, 2021 at 11:59:59 PM"

      iex> date(datetime, "America/New_York")
      "December 31, 2021 at 11:59:59 PM"

      iex> date(datetime, nil)
      "January 1, 2022 at 4:59:59 AM UTC"

      iex> date(datetime)
      "January 1, 2022 at 4:59:59 AM UTC"

      iex> date(datetime, conn, precision: :date)
      "January 1, 2022"

      iex> date(datetime, conn, precision: :relative)
      "8 minutes ago"
  """
  def date(datetime, opts \\ [])

  def date(datetime, %Plug.Conn{assigns: assigns} = conn) do
    case Map.get(assigns, :current_author) do
      %Author{} = author ->
        date(datetime, conn: conn, author: author)

      _ ->
        date(datetime, conn: conn)
    end
  end

  def date(datetime, local_tz) when is_binary(local_tz), do:
    date(datetime, local_tz: local_tz)

  def date(nil, _opts), do: ""

  def date(datetime, opts) do
    maybe_conn_or_local_tz = Keyword.get(opts, :conn, Keyword.get(opts, :local_tz))

    datetime
    |> maybe_localized_datetime(maybe_conn_or_local_tz)
    |> format_datetime(opts)
  end

  @doc """
  Converts a datetime to a specific timezone based on a user's session. This
  session timezone information is set and updated on the timezone api call every
  time a page is loaded.
  """
  def maybe_localized_datetime(%DateTime{} = datetime, %Plug.Conn{} = conn),
    do: maybe_localized_datetime(datetime, Plug.Conn.get_session(conn, "local_tz"))

  def maybe_localized_datetime(%DateTime{} = datetime, nil), do: datetime

  def maybe_localized_datetime(%DateTime{} = datetime, timezone) when is_binary(timezone) do
    # ensure timezone is a valid
    if Timex.Timezone.exists?(timezone) do
      {:localized, Timex.Timezone.convert(datetime, Timex.Timezone.get(timezone, Timex.now()))}
    else
      datetime
    end
  end

  @doc """
  Formats a datetime by converting it to a string. If the timezone attached is UTC, then
  it is assumed this datetime has not been localized and the timezone is included.

  Precision of the datetime can be set to :date, :minutes, or :minutes (default)

  ## Examples
      iex> dt(datetime)
      "December 31, 2021 at 11:59:59 PM UTC"

      iex> dt({:localized, datetime_utc})
      "December 31, 2021 at 11:59:59 PM"

      iex> dt({:localized, datetime}, precision: :date)
      "December 31, 2021"

      iex> dt({:localized, datetime}, precision: :minutes)
      "December 31, 2021 at 11:59 PM"

      iex> dt({:localized, datetime}, precision: :relative)
      "8 minutes ago"

      iex> dt(datetime, :relative)
      "5 hours ago"

      # author has preference show_relative_dates set to true
      iex> dt(datetime, author: author)
      "8 minutes ago"
  """
  def format_datetime(maybe_localized_datetime, opts \\ [])

  def format_datetime(nil, _opts), do: ""

  def format_datetime({:localized, %DateTime{} = datetime}, opts) do
    # default to showing no timezone if the datetime has been localized
    format_datetime(datetime, Keyword.put_new(opts, :show_timezone, false))
  end

  def format_datetime(%DateTime{} = datetime, opts) do
    author = Keyword.get(opts, :author)

    precision =
      Keyword.get(opts, :precision)
      |> value_or(author_format_preference(author))
      |> value_or(:minutes)

    show_timezone = Keyword.get(opts, :show_timezone, true)

    # show the timezone if the datetime hasnt been converted to a local timezone
    maybe_timezone =
      if show_timezone do
        " {Zabbr}"
      else
        ""
      end

    case precision do
      :date ->
        Timex.format!(datetime, "{Mfull} {D}, {YYYY}#{maybe_timezone}")

      :minutes ->
        Timex.format!(datetime, "{Mfull} {D}, {YYYY} at {h12}:{m} {AM}#{maybe_timezone}")

      :seconds ->
        Timex.format!(datetime, "{Mfull} {D}, {YYYY} at {h12}:{m}:{s} {AM}#{maybe_timezone}")

      :relative ->
        Timex.format!(datetime, "{relative}", :relative)
    end
  end

  defp author_format_preference(nil), do: nil

  defp author_format_preference(author) do
    if Accounts.get_author_preference(author, :show_relative_dates) do
      :relative
    else
      nil
    end
  end
end
