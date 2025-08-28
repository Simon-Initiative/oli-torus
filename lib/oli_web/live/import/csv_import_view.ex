defmodule OliWeb.Import.CSVImportView do
  use OliWeb, :live_view

  alias Oli.Repo
  alias OliWeb.Common.{Breadcrumb}
  alias Oli.Accounts.Author

  alias OliWeb.Router.Helpers, as: Routes

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

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
    project = Oli.Authoring.Course.get_project_by_slug(project_slug)
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
         project: project,
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
        <p class={if r.result == :failure, do: "text-danger"}>
          Row #{r.row_num} - {r.result}
        </p>
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
      # if content is valid JSON, parse it and return the parsed content
      # otherwise, content is treated as plain text and converted to a paragraph
      case Jason.decode(content) do
        {:ok, content} ->
          content

        {:error, _} ->
          plaintext_to_paragraph(content)
      end
    end

    File.stream!(ingest_file)
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.with_index(0)
    |> Enum.map(fn {{:ok,
                     [
                       _type,
                       _title,
                       slug,
                       duration_minutes,
                       poster_image,
                       intro_video,
                       intro_content
                     ]}, row_num} ->
      if row_num > 0 do
        case Oli.Publishing.AuthoringResolver.from_revision_slug(project_slug, slug) do
          nil ->
            send(pid, {:update, row_num, :failure})

          revision ->
            has_change? =
              duration_minutes != "" or poster_image != "" or intro_video != "" or
                intro_content != ""

            if has_change? do
              change = %{
                duration_minutes:
                  if duration_minutes != "" do
                    String.to_integer(duration_minutes)
                  else
                    nil
                  end,
                poster_image:
                  if poster_image != "" do
                    poster_image
                  else
                    nil
                  end,
                intro_video:
                  if intro_video != "" do
                    intro_video
                  else
                    nil
                  end,
                intro_content:
                  if intro_content != "" do
                    to_content.(intro_content)
                  else
                    nil
                  end
              }

              needs_change? =
                revision.duration_minutes != change.duration_minutes or
                  revision.poster_image != change.poster_image or
                  revision.intro_video != change.intro_video or
                  revision.intro_content != change.intro_content

              if needs_change? do
                case Oli.Resources.update_revision(revision, change) do
                  {:ok, _} ->
                    send(pid, {:update, row_num, :success})

                  {:error, _} ->
                    send(pid, {:update, row_num, :failure})
                end
              end
            end
        end
      end
    end)
  end

  defp plaintext_to_paragraph(text) do
    %{type: "p", children: [%{text: text}]}
  end

  def handle_info({:update, row_num, result}, socket) do
    {:noreply,
     assign(socket,
       results: socket.assigns.results ++ [%{row_num: row_num, result: result}]
     )}
  end

  def handle_info({:finished}, socket) do
    socket.assigns.project
    |> Oli.Delivery.Sections.get_sections_by_base_project()
    |> Enum.each(&Oli.Delivery.Sections.SectionCache.clear(&1.slug))

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
