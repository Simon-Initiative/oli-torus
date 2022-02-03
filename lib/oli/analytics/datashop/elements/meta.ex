defmodule Oli.Analytics.Datashop.Elements.Meta do
  @moduledoc """
  <meta>
    <user_id>t.stark+0@avengers.com</user_id>
    <session_id>6c6d381e-1598-4924-9b60-30dce843e417</session_id>
    <time>2020-06-29 13:34</time>
    <time_zone>GMT</time_zone>
  </meta>
  """
  import XmlBuilder
  import Oli.Utils

  def setup(%{date: date, sub: sub, email: nil}), do: setup(%{date: date, user_id: sub})
  def setup(%{date: date, email: email}), do: setup(%{date: date, user_id: email})

  def setup(%{date: date, user_id: user_id}) do
    element(:meta, %{}, [
      element(:user_id, user_id),
      element(:session_id, uuid()),
      element(:time, format_date(date)),
      element(:time_zone, "GMT")
    ])
  end

  # Datashop only accepts certain date formats. We're not really using the date/timing curves,
  # so not a lot of thought was put into this part
  defp format_date(date) do
    {:ok, time} = Timex.format(date, "{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s}")
    time
  end
end
