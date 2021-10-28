defmodule OliWeb.Common.Table.Common do
  alias OliWeb.Common.Table.ColumnSpec

  alias Oli.Accounts
  alias Oli.Accounts.Author

  def sort_date(direction, spec) do
    {fn r ->
       case Map.get(r, spec.name) do
         nil ->
           0

         d ->
           DateTime.to_unix(d)
       end
     end, direction}
  end

  def render_relative_date(_, item, %ColumnSpec{name: name}) do
    case Map.get(item, name) do
      nil -> ""
      d -> Timex.format!(d, "{relative}", :relative)
    end
  end

  def render_short_date(_, item, %ColumnSpec{name: name}) do
    case Map.get(item, name) do
      nil -> ""
      d -> Timex.format!(d, "%Y-%m-%d", :strftime)
    end
  end

  def author_preference_date_renderer(%Author{} = author) do
    show_relative_dates = Accounts.get_author_preference(author, :show_relative_dates)

    if show_relative_dates do
      &render_relative_date/3
    else
      &render_short_date/3
    end
  end
end
