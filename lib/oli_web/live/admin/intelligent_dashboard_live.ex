defmodule OliWeb.Admin.IntelligentDashboardLive do
  use OliWeb, :live_view

  import Ecto.Query, warn: false

  alias Oli.GenAI.Completions.Message
  alias Oli.GenAI.Execution
  alias Oli.GenAI.Completions.ServiceConfig
  alias Oli.Repo
  alias OliWeb.Common.Breadcrumb

  @upload_keys [:upload_1, :upload_2, :upload_3, :upload_4, :upload_5]
  @description_fields [
    :description_1,
    :description_2,
    :description_3,
    :description_4,
    :description_5
  ]
  @form_fields @description_fields ++ [:prompt_template]

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def mount(_, _session, socket) do
    form_data = default_form_data()

    socket =
      socket
      |> assign(breadcrumbs: breadcrumb())
      |> assign(response: nil, assembled_prompt: nil, busy: false, csv_cache: %{})
      |> assign_form(form_data)
      |> allow_upload(:upload_1, accept: ~w(.csv), max_entries: 1)
      |> allow_upload(:upload_2, accept: ~w(.csv), max_entries: 1)
      |> allow_upload(:upload_3, accept: ~w(.csv), max_entries: 1)
      |> allow_upload(:upload_4, accept: ~w(.csv), max_entries: 1)
      |> allow_upload(:upload_5, accept: ~w(.csv), max_entries: 1)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-6">
      <div class="mb-6">
        <h1 class="text-3xl font-bold mb-2">Intelligent Dashboard (Prototype)</h1>
        <p class="text-gray-600">
          Upload up to five CSVs, describe each dataset, and provide a prompt. Use
          <code>#{"\#{data}"}</code>
          to inject the CSV data into the prompt.
        </p>
      </div>

      <.form for={@form} phx-change="update" phx-submit="go" multipart>
        <div class="space-y-4">
          <%= for idx <- 1..5 do %>
            <% upload_key = upload_field(idx) %>
            <div class="flex flex-col gap-4 md:flex-row md:items-start">
              <div class="flex-1">
                <label class="block text-sm font-medium mb-1">CSV {idx}</label>
                <.live_file_input upload={@uploads[upload_key]} class="form-control" />
                <%= for entry <- @uploads[upload_key].entries do %>
                  <div class="text-xs text-gray-500 mt-1">{entry.client_name}</div>
                <% end %>
                <%= if cached = @csv_cache[upload_key] do %>
                  <div class="text-xs text-gray-500 mt-1">Cached: {cached.filename}</div>
                <% end %>
              </div>
              <div class="flex-1">
                <.input
                  field={@form[description_field(idx)]}
                  type="text"
                  label={"Descriptor #{idx}"}
                  placeholder="e.g., Quiz averages by section"
                />
              </div>
            </div>
          <% end %>
        </div>

        <div class="mt-6">
          <.input
            field={@form[:prompt_template]}
            type="textarea"
            label="Prompt (use \#{data})"
            rows="8"
            placeholder="Write your LLM prompt here"
            style="resize: both; max-width: none;"
            phx-update="ignore"
          />
        </div>

        <div class="mt-4 flex items-center gap-3">
          <button
            type="submit"
            class="btn btn-primary"
            phx-disable-with="Running..."
            disabled={@busy}
          >
            Go
          </button>
          <button
            type="button"
            class="btn btn-outline-secondary"
            phx-click="clear_data"
            disabled={@busy}
          >
            Clear data
          </button>
          <span :if={@busy} class="text-sm text-gray-500">Running...</span>
        </div>
      </.form>

      <div class="mt-8">
        <h2 class="text-xl font-semibold mb-2">LLM Response</h2>
        <pre class="bg-gray-50 border rounded p-4 whitespace-pre-wrap">
          {if @response in [nil, ""], do: "No response yet.", else: @response}
        </pre>
      </div>
    </div>
    """
  end

  def handle_event("update", %{"dashboard" => params}, socket) do
    form_data = socket.assigns.form_data |> Map.merge(cast_form_params(params))
    {:noreply, assign_form(socket, form_data)}
  end

  def handle_event("go", %{"dashboard" => params}, socket) do
    form_data = socket.assigns.form_data |> Map.merge(cast_form_params(params))
    prompt_template = Map.get(params, "prompt_template", form_data.prompt_template || "")
    form_data = Map.put(form_data, :prompt_template, prompt_template)

    case assemble_prompt(socket, form_data, prompt_template) do
      {:ok, prompt, csv_cache} ->
        send(self(), {:run_prompt, prompt})

        {:noreply,
         socket
         |> assign_form(form_data)
         |> assign(response: nil, assembled_prompt: prompt, busy: true, csv_cache: csv_cache)}

      {:error, message, csv_cache} ->
        {:noreply,
         socket
         |> assign_form(form_data)
         |> assign(busy: false, csv_cache: csv_cache)
         |> put_flash(:error, message)}
    end
  end

  def handle_event("clear_data", _params, socket) do
    cleared_form_data =
      Enum.reduce(@description_fields, socket.assigns.form_data, fn field, acc ->
        Map.put(acc, field, "")
      end)

    socket =
      socket
      |> clear_uploads()
      |> assign_form(cleared_form_data)
      |> assign(csv_cache: %{})

    {:noreply, socket}
  end

  def handle_info({:run_prompt, prompt}, socket) do
    case generate_response(prompt, socket.assigns.current_author) do
      {:ok, response} ->
        {:noreply, assign(socket, response: response, busy: false)}

      {:error, message} ->
        {:noreply,
         socket
         |> assign(response: message, busy: false)
         |> put_flash(:error, message)}
    end
  end

  defp default_form_data do
    %{
      description_1: "",
      description_2: "",
      description_3: "",
      description_4: "",
      description_5: "",
      prompt_template: ~S"""
      You are an expert learning engineer and instructor dashboard analyst. You will be given 1-5 datasets exported from an LMS/assessment system. Each dataset is presented as:

      - A descriptor line explaining what it is
      - A Markdown table containing the data

      Your job is to produce an actionable instructional insight. You must be precise, avoid speculation, and cite the dataset(s) and column names you used.

      ### What you have

      #{data}

      ### Output requirements

      Produce one instructional insight or recommendation total, expressed in one sentence (or at most two short sentences).
      The insight should be the highest-impact finding an instructor or admin should act on right now.

      When forming the insight, consider (implicitly -- do not enumerate):

      - Patterns across datasets (performance, attempts, hints, timing, engagement).
      - Evidence from specific dataset descriptors and column names.
      - Whether the issue concerns students, groups, concepts, or engagement behaviors.
      - What concrete instructor action would most directly address the issue.

      #### Required constraints

      - The sentence must reference one dataset descriptor (e.g. "video usage") or one course content location (e.g. "Module 5")
      - Do not include bullet points, headings, or multiple recommendations.
      - Do not explain your reasoning step-by-step.
      - If evidence is suggestive but not definitive, label it clearly as Inference within the sentence.
      - If no meaningful insight can be supported by the data, say so explicitly in one sentence.

      #### Example format (illustrative only)

      "Students with repeated low correctness despite high attempt counts in Module 6 should receive targeted intervention on this unit, as it suggests trial-and-error behavior rather than conceptual mastery."

      #### Rules

      - Do not invent facts not supported by the tables.
      - If you make an inference, label it explicitly as Inference and explain the supporting evidence.
      - Prefer specific statements over generic advice.
      - If there are multiple datasets, you should cross-reference them (e.g., connect performance to engagement).
      - If a dataset is empty or clearly incomplete, note it and proceed with what you have.
      - If very little student data is present, it is fine to state "There is no specific recommendation at this point in time, as there isn't enough student data"

      Begin now.
      """
    }
  end

  defp assign_form(socket, form_data) do
    params = stringify_keys(form_data)
    assign(socket, form_data: form_data, form: to_form(params, as: :dashboard))
  end

  defp cast_form_params(params) do
    Enum.reduce(@form_fields, %{}, fn field, acc ->
      key = Atom.to_string(field)

      if Map.has_key?(params, key) do
        Map.put(acc, field, Map.get(params, key))
      else
        acc
      end
    end)
  end

  defp assemble_prompt(socket, form_data, prompt_template) do
    {sections, errors, csv_cache} = consume_csv_sections(socket, form_data)

    cond do
      errors != [] ->
        {:error, Enum.reverse(errors) |> Enum.join("; "), csv_cache}

      sections == [] ->
        {:error, "Attach at least one CSV file.", csv_cache}

      true ->
        data_section = Enum.join(sections, "\n\n")
        {:ok, build_prompt(to_string(prompt_template), data_section), csv_cache}
    end
  end

  defp consume_csv_sections(socket, form_data) do
    Enum.reduce(1..5, {[], [], socket.assigns.csv_cache || %{}}, fn idx,
                                                                    {sections, errors, cache} ->
      upload_key = upload_field(idx)
      {_, in_progress} = Phoenix.LiveView.uploaded_entries(socket, upload_key)

      if in_progress != [] do
        {sections, ["CSV #{idx} upload still in progress" | errors], cache}
      else
        {done_entries, _} = Phoenix.LiveView.uploaded_entries(socket, upload_key)

        cond do
          done_entries != [] ->
            results =
              consume_uploaded_entries(socket, upload_key, fn %{path: path}, entry ->
                case csv_to_markdown(path) do
                  {:ok, markdown} -> {:ok, %{entry: entry, markdown: markdown}}
                  {:error, reason} -> {:ok, %{entry: entry, error: reason}}
                end
              end)

            Enum.reduce(results, {sections, errors, cache}, fn result,
                                                               {acc_sections, acc_errors,
                                                                acc_cache} ->
              if Map.has_key?(result, :error) do
                message = "CSV #{idx} (#{result.entry.client_name}): #{result.error}"
                {acc_sections, [message | acc_errors], acc_cache}
              else
                descriptor = descriptor_for(idx, form_data, result.entry)
                section = [descriptor, "", result.markdown] |> Enum.join("\n")

                updated_cache =
                  Map.put(acc_cache, upload_key, %{
                    filename: filename_from_entry(result.entry),
                    markdown: result.markdown
                  })

                {acc_sections ++ [section], acc_errors, updated_cache}
              end
            end)

          Map.has_key?(cache, upload_key) ->
            cached = cache[upload_key]
            descriptor = descriptor_for(idx, form_data, cached.filename)
            section = [descriptor, "", cached.markdown] |> Enum.join("\n")
            {sections ++ [section], errors, cache}

          true ->
            {sections, errors, cache}
        end
      end
    end)
  end

  defp descriptor_for(idx, form_data, entry) do
    value = form_data |> Map.get(description_field(idx), "") |> to_string()
    value = String.trim(value)
    filename = filename_from_entry(entry)

    cond do
      value != "" -> value
      filename in [nil, ""] -> "Dataset #{idx}"
      true -> filename
    end
  end

  defp build_prompt(prompt_template, data_section) do
    placeholder = "\#{data}"

    cond do
      data_section == "" ->
        prompt_template

      prompt_template == "" ->
        data_section

      String.contains?(prompt_template, placeholder) ->
        String.replace(prompt_template, placeholder, data_section)

      true ->
        String.trim_trailing(prompt_template) <> "\n\n" <> data_section
    end
  end

  defp csv_to_markdown(path) do
    case parse_csv_rows(path) do
      {:error, reason} ->
        {:error, "CSV parse error: #{inspect(reason)}"}

      [] ->
        {:ok, "_(empty CSV)_"}

      [header | rows] ->
        {normalized_header, normalized_rows} = normalize_rows(header, rows)

        if normalized_header == [] do
          {:ok, "_(empty CSV)_"}
        else
          {:ok, render_markdown_table(normalized_header, normalized_rows)}
        end
    end
  end

  defp parse_csv_rows(path) do
    path
    |> File.stream!()
    |> CSV.decode()
    |> Enum.reduce_while([], fn
      {:ok, row}, acc -> {:cont, [row | acc]}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      rows -> Enum.reverse(rows)
    end
  end

  defp normalize_rows(header, rows) do
    max_len =
      [length(header) | Enum.map(rows, &length/1)]
      |> Enum.max()

    {
      pad_row(header, max_len),
      Enum.map(rows, &pad_row(&1, max_len))
    }
  end

  defp pad_row(row, max_len) do
    row ++ List.duplicate("", max_len - length(row))
  end

  defp render_markdown_table(header, rows) do
    header_line = "| " <> Enum.map_join(header, " | ", &escape_md/1) <> " |"
    separator = "| " <> Enum.map_join(header, " | ", fn _ -> "---" end) <> " |"

    body_lines =
      Enum.map(rows, fn row ->
        "| " <> Enum.map_join(row, " | ", &escape_md/1) <> " |"
      end)

    ([header_line, separator] ++ body_lines)
    |> Enum.join("\n")
  end

  defp escape_md(value) do
    value
    |> to_string()
    |> String.replace("|", "\\|")
    |> String.replace("\r", " ")
    |> String.replace("\n", " ")
  end

  defp generate_response(prompt, author) do
    case fetch_service_config() do
      nil ->
        {:error, "No GenAI service config is available."}

      service_config ->
        request_ctx = %{
          request_type: :generate,
          feature: :intelligent_dashboard,
          author_id: author && author.id
        }

        case Execution.generate(
               request_ctx,
               [Message.new(:user, prompt)],
               [],
               service_config
             ) do
          {:ok, response} ->
            {:ok, normalize_response(response)}

          {:error, reason} ->
            {:error, "GenAI error: #{inspect(reason)}"}
        end
    end
  end

  defp fetch_service_config do
    Repo.one(
      from sc in ServiceConfig,
        order_by: sc.id,
        limit: 1,
        preload: [:primary_model, :secondary_model, :backup_model]
    )
  end

  defp normalize_response(response) when is_binary(response), do: response

  defp normalize_response(%{"choices" => [%{"message" => %{"content" => content}} | _]})
       when is_binary(content) do
    content
  end

  defp normalize_response(%{"choices" => [%{"message" => %{"content" => nil}} | _]}) do
    "(No text content returned by model)"
  end

  defp normalize_response(%{"choices" => [%{"message" => message} | _]}) do
    "Unexpected response format: #{inspect(message)}"
  end

  defp normalize_response(response), do: inspect(response)

  defp breadcrumb do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{link: "", full_title: "Intelligent Dashboard"})
      ]
  end

  defp upload_field(idx), do: Enum.at(@upload_keys, idx - 1)
  defp description_field(idx), do: Enum.at(@description_fields, idx - 1)
  defp filename_from_entry(%{client_name: name}), do: name
  defp filename_from_entry(name) when is_binary(name), do: name
  defp filename_from_entry(_), do: nil

  defp clear_uploads(socket) do
    Enum.reduce(@upload_keys, socket, fn upload_key, acc_socket ->
      entries = acc_socket.assigns.uploads[upload_key].entries

      Enum.reduce(entries, acc_socket, fn entry, inner_socket ->
        cancel_upload(inner_socket, upload_key, entry.ref)
      end)
    end)
  end

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {Atom.to_string(key), value} end)
  end
end
