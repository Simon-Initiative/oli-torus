defmodule OliWeb.Dev.Mer5257DocsLive do
  @moduledoc """
  Dev-only viewer for MER-5257 (`email_sending` feature) docs. Renders markdown
  files via Earmark and YAML files as raw code blocks. File selection is
  whitelisted from the on-disk directory listing to avoid path traversal.
  """

  use OliWeb, :live_view

  @doc_dir "docs/exec-plans/current/epics/intelligent_dashboard/email_sending"

  @impl true
  def mount(_params, _session, socket) do
    files = list_files()
    selected = Enum.find(files, &(&1 == "gaps.md")) || List.first(files)

    {:ok,
     assign(socket,
       doc_dir: @doc_dir,
       files: files,
       selected: selected,
       body: load(selected)
     )}
  end

  @impl true
  def handle_event("select", %{"file" => file}, socket) do
    safe = if file in socket.assigns.files, do: file, else: socket.assigns.selected
    {:noreply, assign(socket, selected: safe, body: load(safe))}
  end

  def handle_event("reload", _params, socket) do
    files = list_files()

    selected =
      if socket.assigns.selected in files, do: socket.assigns.selected, else: List.first(files)

    {:noreply, assign(socket, files: files, selected: selected, body: load(selected))}
  end

  defp list_files do
    case File.ls(@doc_dir) do
      {:ok, entries} ->
        entries
        |> Enum.filter(fn name ->
          path = Path.join(@doc_dir, name)
          File.regular?(path) and renderable?(name)
        end)
        |> Enum.sort()

      _ ->
        []
    end
  end

  defp renderable?(name) do
    String.ends_with?(name, [".md", ".yml", ".yaml"])
  end

  defp load(nil), do: {:empty, "No files found in #{@doc_dir}."}

  defp load(file) do
    path = Path.join(@doc_dir, file)

    case File.read(path) do
      {:ok, content} ->
        cond do
          String.ends_with?(file, ".md") ->
            try do
              {:html, Earmark.as_html!(content)}
            rescue
              e -> {:code, "Earmark failed: #{Exception.message(e)}\n\n" <> content}
            end

          true ->
            {:code, content}
        end

      {:error, reason} ->
        {:empty, "Failed to read #{file}: #{inspect(reason)}"}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen bg-white text-gray-900">
      <aside class="w-72 shrink-0 border-r border-gray-200 p-4 overflow-y-auto bg-gray-50">
        <h2 class="font-semibold text-base mb-1">MER-5257 — email_sending</h2>
        <p class="text-xs text-gray-500 mb-2 break-all">{@doc_dir}</p>
        <a
          href="https://eliterate.atlassian.net/browse/MER-5257"
          target="_blank"
          class="text-xs text-blue-600 hover:underline block mb-4"
        >
          Open Jira ticket ↗
        </a>

        <ul class="space-y-1">
          <%= for file <- @files do %>
            <li>
              <button
                type="button"
                phx-click="select"
                phx-value-file={file}
                class={[
                  "w-full text-left px-3 py-1.5 rounded text-sm transition-colors",
                  if(file == @selected,
                    do: "bg-blue-600 text-white font-semibold",
                    else: "hover:bg-gray-200 text-gray-800"
                  )
                ]}
              >
                {file}
              </button>
            </li>
          <% end %>
        </ul>

        <button
          type="button"
          phx-click="reload"
          class="mt-6 w-full px-3 py-1.5 bg-gray-200 hover:bg-gray-300 rounded text-sm font-medium"
        >
          ↻ Reload from disk
        </button>

        <p class="text-xs text-gray-400 mt-4 leading-snug">
          Files are read fresh on each click. Edit a file in your editor, then click it again (or Reload) to see changes.
        </p>
      </aside>

      <main class="flex-1 overflow-y-auto">
        <div class="max-w-6xl mx-auto px-8 py-8">
          <header class="mb-6 pb-4 border-b border-gray-200">
            <h1 class="text-xl font-bold">{@selected || "(no file)"}</h1>
          </header>

          <article class="mer-5257-doc">
            <%= case @body do %>
              <% {:html, html} -> %>
                {raw(html)}
              <% {:code, code} -> %>
                <pre class="bg-gray-50 border border-gray-200 p-4 rounded overflow-x-auto text-xs leading-relaxed"><code>{code}</code></pre>
              <% {:empty, msg} -> %>
                <p class="text-gray-500 italic">{msg}</p>
            <% end %>
          </article>
        </div>
      </main>
    </div>

    <style>
      .mer-5257-doc h1 { font-size: 1.5rem; font-weight: 700; margin: 1.5rem 0 1rem; }
      .mer-5257-doc h2 { font-size: 1.25rem; font-weight: 700; margin: 1.5rem 0 0.75rem; padding-bottom: 0.25rem; border-bottom: 1px solid #e5e7eb; }
      .mer-5257-doc h3 { font-size: 1.05rem; font-weight: 600; margin: 1.25rem 0 0.5rem; }
      .mer-5257-doc h4 { font-size: 1rem; font-weight: 600; margin: 1rem 0 0.5rem; }
      .mer-5257-doc p { margin: 0.5rem 0; line-height: 1.65; }
      .mer-5257-doc ul, .mer-5257-doc ol { margin: 0.5rem 0 0.75rem 1.5rem; line-height: 1.65; }
      .mer-5257-doc ul { list-style: disc; }
      .mer-5257-doc ol { list-style: decimal; }
      .mer-5257-doc li { margin: 0.15rem 0; }
      .mer-5257-doc code { background: #f3f4f6; padding: 0.1rem 0.35rem; border-radius: 0.25rem; font-size: 0.85em; }
      .mer-5257-doc pre { background: #f9fafb; border: 1px solid #e5e7eb; padding: 1rem; border-radius: 0.375rem; overflow-x: auto; margin: 0.75rem 0; }
      .mer-5257-doc pre code { background: transparent; padding: 0; font-size: 0.8rem; }
      .mer-5257-doc table { border-collapse: collapse; margin: 0.75rem 0; font-size: 0.875rem; }
      .mer-5257-doc th, .mer-5257-doc td { border: 1px solid #e5e7eb; padding: 0.4rem 0.6rem; text-align: left; vertical-align: top; }
      .mer-5257-doc th { background: #f9fafb; font-weight: 600; }
      .mer-5257-doc th:first-child, .mer-5257-doc td:first-child { min-width: 5rem; white-space: nowrap; }
      .mer-5257-doc a { color: #2563eb; text-decoration: underline; }
      .mer-5257-doc a:hover { color: #1d4ed8; }
      .mer-5257-doc blockquote { border-left: 3px solid #d1d5db; padding-left: 1rem; color: #4b5563; margin: 0.75rem 0; }
      .mer-5257-doc hr { border: none; border-top: 1px solid #e5e7eb; margin: 1.5rem 0; }
      .mer-5257-doc strong { font-weight: 600; }
      .mer-5257-doc em { font-style: italic; }
    </style>
    """
  end
end
