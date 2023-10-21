defmodule OliWeb.Import.CSVImportView do
  use OliWeb, :live_view

  alias Oli.Repo
  alias OliWeb.Common.{Breadcrumb}
  alias Oli.Accounts.Author

  alias OliWeb.Router.Helpers, as: Routes

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb()
    |> breadcrumb()
  end

  def breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "NG23 Import CSV",
          link: ""
        })
      ]
  end

  defp ingest_file(author) do
    "_imports/#{author.id}-import.csv"
  end

  def mount(
        %{"project_slug" => project_slug},
        %{"current_author_id" => author_id},
        socket
      ) do
    author = Repo.get(Author, author_id)
    ingest_file = ingest_file(author)

    if File.exists?(ingest_file) do
      pid = self()

      Task.async(fn ->
        process_rows(pid, project_slug, ingest_file)
        send(pid, {:finished})
      end)

      {:ok,
       assign(socket,
         breadcrumbs: set_breadcrumbs(),
         author: author,
         finished: false,
         results: []
       )}
    else
      {:ok,
       Phoenix.LiveView.redirect(socket, to: Routes.ingest_path(OliWeb.Endpoint, :index_csv))}
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <%= for r <- @results do %>
        <p>Row #<%= r.row_num %> - <%= r.result %></p>
      <% end %>

      <%= if @finished do %>
        <p>Finished!</p>
      <% end %>
    </div>
    """
  end

  def handle_event("hide_overview", _, socket) do
    {:noreply, assign(socket, show_feature_overview: false)}
  end

  defp process_rows(pid, project_slug, ingest_file) do

    to_content = fn content ->
      children = String.split(content, "|")
      |> Enum.map(fn p -> to_paragraph(p) end)

      %{
        children: children
      }
    end

    File.stream!(ingest_file)
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.with_index(0)
    |> Enum.map(fn {{:ok, [_type, _title, slug, duration_minutes, poster_image, intro_video, intro_content]}, row_num} ->

      if row_num > 0 do

        revision = Oli.Publishing.AuthoringResolver.from_revision_slug(project_slug, slug)

        has_change? = duration_minutes != "" or poster_image != "" or intro_video != "" or intro_content != ""

        if has_change? do
          change = %{
            duration_minutes: if duration_minutes != "" do String.to_integer(duration_minutes) else nil end,
            poster_image: if poster_image != "" do poster_image else nil end,
            intro_video: if intro_video != "" do intro_video else nil end,
            intro_content: if intro_content != "" do to_content.(intro_content) else nil end
          }


          needs_change? = revision.duration_minutes != change.duration_minutes or revision.poster_image != change.poster_image or revision.intro_video != change.intro_video or revision.intro_content != change.intro_content

          if needs_change? do
            case Oli.Resources.update_revision(revision, change) do
              {:ok, _} ->
                IO.inspect change
                send(pid, {:update, row_num, :success})
              {:error, _} ->
                send(pid, {:update, row_num, :failure})
            end
          end

        end

      end
    end)
  end

  defp to_paragraph(text) do
    children =
      case String.contains?(text, "**") do
        false ->
          [%{text: text}]

        true ->
          items = String.split(" " <> text <> " ", "**")

          last = Enum.count(items)

          Enum.with_index(items, 1)
          |> Enum.map(fn {t, i} ->
            # if i is even it is bold

            t =
              case i do
                1 -> String.trim_leading(t)
                ^last -> String.trim_trailing(t)
                _ -> t
              end

            if rem(i, 2) == 0 do
              %{text: t, bold: true}
            else
              %{text: t}
            end
          end)
      end

    %{type: "p", children: children}
  end

  def handle_info({:update, row_num, result}, socket) do
    {:noreply,
     assign(socket,
       results: socket.assigns.results ++ [%{row_num: row_num, result: result}]
     )}
  end

  def handle_info({:finished}, socket) do
    {:noreply,
     assign(socket,
       finished: true
     )}
  end

  def handle_info(_, socket) do
    {:noreply,
     assign(socket,
       finished: true
     )}
  end
end
