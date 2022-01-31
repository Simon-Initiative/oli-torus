defmodule OliWeb.Common.FormatDateTime do
  alias Oli.Accounts
  alias OliWeb.Common.SessionContext

  import Oli.Utils, only: [value_or: 2]

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
      # date can be given a %Plug.Conn{}, %SessionContext{} or local_tz string to localize the datetime
      iex> date(datetime, conn)
      "December 31, 2021 at 11:59:59 PM"

      iex> date(datetime, context)
      "December 31, 2021 at 11:59:59 PM"

      iex> date(datetime, "America/New_York")
      "December 31, 2021 at 11:59:59 PM"

      # if any of these are nil or omitted, the timezone will be displayed in UTC
      iex> date(datetime, nil)
      "January 1, 2022 at 4:59:59 AM UTC"

      iex> date(datetime)
      "January 1, 2022 at 4:59:59 AM UTC"

      # additionally, conn or context can be provided as opts along with any other format_datetime opts
      iex> date(datetime, conn: conn, precision: :date)
      "January 1, 2022"

      iex> date(datetime, context: context, precision: :relative)
      "8 minutes ago"
  """
  def date(datetime, opts \\ [])

  # date helpers to easily pass in only a conn or context struct
  def date(datetime, %Plug.Conn{} = conn) do
    date(datetime, SessionContext.init(conn))
  end

  def date(datetime, %SessionContext{} = context),
    do: date(datetime, context: context)

  def date(datetime, local_tz) when is_binary(local_tz), do: date(datetime, local_tz: local_tz)

  def date(datetime, nil), do: date(datetime)

  def date(nil, _opts), do: ""

  def date(datetime, opts) when is_list(opts) do
    maybe_context_conn_or_local_tz =
      Keyword.get(opts, :context)
      |> value_or(Keyword.get(opts, :conn))
      |> value_or(Keyword.get(opts, :local_tz))

    case maybe_context_conn_or_local_tz do
      %Plug.Conn{} = conn ->
        date(datetime, Keyword.merge(opts, context: SessionContext.init(conn)))

      _ ->
        opts =
          case maybe_context_conn_or_local_tz do
            %SessionContext{author: author} ->
              Keyword.put_new(opts, :author, author)

            _ ->
              opts
          end

        datetime
        |> maybe_localized_datetime(maybe_context_conn_or_local_tz)
        |> format_datetime(opts)
    end
  end

  @doc """
  Converts a datetime to a specific timezone based on a user's session. This
  session timezone information is set and updated on the timezone api call every
  time a page is loaded.

  If NaiveDateTime is given it is assumed to be utc
  """
  def maybe_localized_datetime(%NaiveDateTime{} = naive_date, nil),
    do: Timex.to_datetime(naive_date, "Etc/UTC")

  def maybe_localized_datetime(%DateTime{} = datetime, nil), do: datetime

  def maybe_localized_datetime(%DateTime{} = datetime, %SessionContext{local_tz: local_tz}),
    do: maybe_localized_datetime(datetime, local_tz)

  def maybe_localized_datetime(%DateTime{} = datetime, local_tz) when is_binary(local_tz) do
    # ensure timezone is a valid
    if Timex.Timezone.exists?(local_tz) do
      {:localized, Timex.Timezone.convert(datetime, Timex.Timezone.get(local_tz, Timex.now()))}
    else
      datetime
    end
  end

  @doc """
  Formats a datetime by converting it to a string. If the timezone attached is UTC, then
  it is assumed this datetime has not been localized and the timezone is included.

  Precision of the datetime can be set to :date, :minutes (default) or :relative

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
    # get_author_preference expects author preferences to already be preloaded
    if Accounts.get_author_preference(author, :show_relative_dates) do
      :relative
    else
      nil
    end
  end
end
