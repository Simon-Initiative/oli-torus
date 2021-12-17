defmodule OliWeb.Common.Table.Common do
  import OliWeb.Common.FormatDateTime

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias OliWeb.Common.Table.ColumnSpec

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
    date(Map.get(item, name), precision: :relative)
  end

  def render_date(assigns, item, %ColumnSpec{name: name}) do
    date(Map.get(item, name), Map.get(assigns, :context))
  end

  def author_preference_date_renderer(%Author{} = author) do
    show_relative_dates = Accounts.get_author_preference(author, :show_relative_dates)

    if show_relative_dates do
      &render_relative_date/3
    else
      &render_date/3
    end
  end
end
