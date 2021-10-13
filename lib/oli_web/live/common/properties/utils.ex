defmodule OliWeb.Common.Properties.Utils do
  def date(d) do
    case d do
      nil -> ""
      d -> Timex.format!(d, "%Y-%m-%d", :strftime)
    end
  end

  def boolean(b) do
    if b do
      "True"
    else
      "False"
    end
  end
end
