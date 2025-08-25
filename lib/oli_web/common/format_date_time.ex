defmodule OliWeb.Common.FormatDateTime do
  alias Oli.Accounts
  alias OliWeb.Common.SessionContext

  import Oli.Utils, only: [value_or: 2]

  @utc_timezone "Etc/UTC"

  @doc """
  Returns a human readable formatted duration
  """
  def duration(%Timex.Duration{} = duration) do
    Timex.format_duration(duration, :humanized)
  end

  def duration(from, to) do
    Timex.diff(from, to, :milliseconds)
    |> Timex.Duration.from_milliseconds()
    |> Timex.format_duration(:humanized)
  end

  @doc """
  Converts a datetime to a specific timezone based on a user's session or specified timezone
  and returns an ISO 8601 formatted string.

  This session timezone information is fetched from the browser when Torus is loaded for the first time.

  ## Examples
      # date can be given a %Plug.Conn{}, %SessionContext{} or local_tz string to localize the datetime
      iex> date(datetime, conn)
      "December 31, 2021 at 11:59:59 PM"

      iex> date(datetime, ctx)
      "December 31, 2021 at 11:59:59 PM"

      iex> date(datetime, "America/New_York")
      "December 31, 2021 at 11:59:59 PM"

      # if any of these are nil or omitted, the timezone will be displayed in UTC
      iex> date(datetime, nil)
      "January 1, 2022 at 4:59:59 AM UTC"

      iex> date(datetime)
      "January 1, 2022 at 4:59:59 AM UTC"

      # additionally, conn or ctx can be provided as opts along with any other format_datetime opts
      iex> date(datetime, conn: conn, precision: :date)
      "January 1, 2022"

      iex> date(datetime, ctx: ctx, precision: :relative)
      "8 minutes ago"
  """
  def date(datetime, opts \\ [])

  # date helpers to easily pass in only a conn or context struct
  def date(datetime, %Plug.Conn{} = conn) do
    date(datetime, SessionContext.init(conn))
  end

  def date(datetime, %SessionContext{} = ctx),
    do: date(datetime, ctx: ctx)

  def date(datetime, local_tz) when is_binary(local_tz), do: date(datetime, local_tz: local_tz)

  def date(datetime, nil), do: date(datetime)

  def date(nil, _opts), do: ""

  def date(datetime, opts) when is_list(opts) do
    maybe_ctx_conn_or_local_tz =
      Keyword.get(opts, :ctx)
      |> value_or(Keyword.get(opts, :conn))
      |> value_or(Keyword.get(opts, :local_tz))
      |> value_or(nil)

    case maybe_ctx_conn_or_local_tz do
      %Plug.Conn{} = conn ->
        date(datetime, Keyword.merge(opts, ctx: SessionContext.init(conn)))

      _ ->
        opts =
          case maybe_ctx_conn_or_local_tz do
            %SessionContext{author: author} ->
              Keyword.put_new(opts, :author, author)

            _ ->
              opts
          end

        datetime
        |> maybe_localized_datetime(maybe_ctx_conn_or_local_tz)
        |> format_datetime(opts)
    end
  end

  @doc """
  Converts a datetime to a specific timezone based on a user's session.
  This session timezone information is fetched from the browser when Torus is loaded for the first time.

  If NaiveDateTime is given it is assumed to be utc
  """
  def maybe_localized_datetime(%NaiveDateTime{} = naive_date, nil),
    do: {:not_localized, Timex.to_datetime(naive_date, @utc_timezone)}

  def maybe_localized_datetime(%NaiveDateTime{} = naive_date, %SessionContext{local_tz: local_tz}) do
    naive_date
    |> Timex.to_datetime(@utc_timezone)
    |> maybe_localized_datetime(local_tz)
  end

  def maybe_localized_datetime(%DateTime{} = datetime, nil), do: {:not_localized, datetime}

  def maybe_localized_datetime(%DateTime{} = datetime, %SessionContext{local_tz: local_tz}),
    do: maybe_localized_datetime(datetime, local_tz)

  def maybe_localized_datetime(%DateTime{} = datetime, local_tz) when local_tz == @utc_timezone,
    do: {:not_localized, datetime}

  def maybe_localized_datetime(%DateTime{} = datetime, local_tz) when is_binary(local_tz) do
    # ensure timezone is a valid
    if Timex.Timezone.exists?(local_tz) do
      Timex.Timezone.convert(datetime, Timex.Timezone.get(local_tz, Timex.now()))
    else
      datetime
    end
  end

  def maybe_localized_datetime(%Date{} = date, opts) do
    maybe_localized_datetime(Timex.to_datetime(date), opts)
  end

  @doc """
  Formats a datetime by converting it to a string. If the timezone attached is UTC, then
  it is assumed this datetime has not been localized and the timezone is included.

  Precision of the datetime can be set to :date, :minutes (default) or :relative

  ## Examples
      iex> format_datetime(datetime)
      "December 31, 2021 at 11:59 PM MST"

      iex> format_datetime({:not_localized, datetime})
      "December 31, 2021 at 5:59 AM UTC"

      iex> format_datetime(datetime, show_timezone: false)
      "December 31, 2021 at 11:59 PM"

      iex> format_datetime(datetime, precision: :date)
      "December 31, 2021 UTC"

      iex> format_datetime(datetime, precision: :seconds)
      "December 31, 2021 at 11:59:59 PM UTC"

      iex> format_datetime(datetime, precision: :relative)
      "5 hours ago"

      # author has preference show_relative_dates set to true
      iex> format_datetime(datetime, author: author)
      "8 minutes ago"
  """
  def format_datetime(maybe_localized_datetime, opts \\ [])

  def format_datetime(nil, _opts), do: ""

  def format_datetime({:not_localized, %DateTime{} = datetime}, opts) do
    opts = Keyword.put(opts, :show_timezone, true)
    format_datetime(datetime, opts)
  end

  def format_datetime(%DateTime{} = datetime, opts) do
    author = Keyword.get(opts, :author)

    precision =
      Keyword.get(opts, :precision)
      |> value_or(author_format_preference(author))
      |> value_or(:minutes)

    show_timezone = Keyword.get(opts, :show_timezone, false)

    maybe_timezone =
      if show_timezone do
        " {Zabbr}"
      else
        ""
      end

    # TODO: we likely want to be using Oli.Cldr.Date.to_string/2 here instead
    # once we have a way to pass in the locale
    case precision do
      :date ->
        Timex.format!(datetime, "{Mfull} {D}, {YYYY}#{maybe_timezone}")

      :day ->
        Timex.format!(datetime, "{WDshort}, {D}#{maybe_timezone}")

      :minutes ->
        Timex.format!(datetime, "{Mfull} {D}, {YYYY} {h12}:{m} {AM}#{maybe_timezone}")

      :seconds ->
        Timex.format!(datetime, "{Mfull} {D}, {YYYY} {h12}:{m}:{s} {AM}#{maybe_timezone}")

      :relative ->
        Timex.format!(datetime, "{relative}", :relative)

      :simple_iso8601 ->
        Timex.format!(datetime, "{ISOdate}T{h24}:{m}")
    end
  end

  @doc """
  Converts a datestring to a UTC datetime, assuming the input date is in the given timezone.

  ## Examples
      iex> datestring_to_utc_datetime("2022-05-18T12:35", "US/Arizona")
      ~U[2022-05-18 19:35:00Z]
  """
  def datestring_to_utc_datetime(date, _) when is_nil(date) or date == "" or not is_binary(date),
    do: nil

  def datestring_to_utc_datetime(date_string, %SessionContext{local_tz: local_tz}) do
    datestring_to_utc_datetime(date_string, local_tz)
  end

  def datestring_to_utc_datetime(date_string, local_tz) do
    date_string
    |> Timex.parse!("{ISO:Extended}")
    |> Timex.to_datetime(local_tz)
    |> DateTime.shift_zone(@utc_timezone)
    |> elem(1)
  end

  @doc """
  Converts a date/time value to a localized DateTime struct.

  ## Examples
    iex> convert_datetime(~U[2022-06-22 13:58:23Z], "America/Montevideo")
    #DateTime<2022-06-22 10:58:23.316111-03:00 -03 America/Montevideo>

    iex> convert_datetime(~U[2022-06-22 13:58:23Z], %SessionContext{local_tz: "America/Montevideo"})
    #DateTime<2022-06-22 10:58:23.316111-03:00 -03 America/Montevideo>
  """
  def convert_datetime(date, _) when is_nil(date) or date == "", do: nil

  def convert_datetime(datetime, %SessionContext{local_tz: local_tz}),
    do: convert_datetime(datetime, local_tz)

  def convert_datetime(datetime, timezone), do: Timex.to_datetime(datetime, timezone)

  @doc """
  Returns the UTC timezone.
  """
  def default_timezone, do: @utc_timezone

  defp author_format_preference(nil), do: nil

  defp author_format_preference(author) do
    # get_author_preference expects author preferences to already be preloaded
    if Accounts.get_author_preference(author, :show_relative_dates) do
      :relative
    else
      nil
    end
  end

  @doc """
  Returns an author or users preferred timezone or the browser_timezone if none is set.
  Author takes precedence over user. If browser_timezone is nil, then UTC is returned.
  Fallback order: Author/User timezone -> Section timezone -> Browser timezone -> UTC
  """
  def tz_preference_or_default(author, user, section \\ nil, browser_timezone) do
    cond do
      not is_nil(author) ->
        Accounts.get_author_preference(
          author,
          :timezone,
          get_section_or_browser_tz(section, browser_timezone)
        )

      not is_nil(user) ->
        Accounts.get_user_preference(
          user,
          :timezone,
          get_section_or_browser_tz(section, browser_timezone)
        )

      true ->
        get_section_or_browser_tz(section, browser_timezone)
    end
  end

  defp get_section_or_browser_tz(section, browser_timezone) do
    cond do
      not is_nil(browser_timezone) ->
        browser_timezone

      not is_nil(section) and Map.has_key?(section, :timezone) and not is_nil(section.timezone) ->
        section.timezone

      true ->
        @utc_timezone
    end
  end

  def to_formatted_datetime(datetime, ctx, format \\ "{WDshort} {Mshort} {D}, {YYYY}")

  def to_formatted_datetime(nil, _ctx, _format), do: "Not yet scheduled"

  def to_formatted_datetime(datetime, ctx, format) do
    if is_binary(datetime) do
      datetime
      |> to_datetime
      |> parse_datetime(ctx, format)
    else
      parse_datetime(datetime, ctx, format)
    end
  end

  defp to_datetime(nil), do: "Not yet scheduled"

  defp to_datetime(string_datetime) do
    {:ok, datetime, _} = DateTime.from_iso8601(string_datetime)

    datetime
  end

  @doc """
  Parses a DateTime (UTC) considering the given context to localize it,
  and formats it using the given format string.

  ## Examples
    iex> parse_datetime(~U[2023-11-17 12:25:31.887855Z], %SessionContext{local_tz: "America/Montevideo"})
    "Fri Nov 17, 2023"

    iex> parse_datetime(~U[2023-11-17 12:25:31.887855Z], %SessionContext{local_tz: "America/Montevideo"}, "{YYYY}-{0M}-{D}")
    "2023-11-17"
  """

  def parse_datetime(datetime, ctx, format_string \\ "{WDshort} {Mshort} {D}, {YYYY}") do
    datetime
    |> convert_datetime(ctx)
    |> Timex.format!(format_string)
  end
end
