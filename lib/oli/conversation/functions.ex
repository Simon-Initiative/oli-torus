defmodule Oli.Conversation.Functions do
  import Oli.Conversation.Common
  import Ecto.Query, warn: false

  alias OliWeb.Router.Helpers, as: Routes

  @lookup_table %{
    "avg_score_for" => "Elixir.Oli.Conversation.Functions.avg_score_for",
    "up_next" => "Elixir.Oli.Conversation.Functions.up_next",
    "relevant_course_content" => "Elixir.Oli.Conversation.Functions.relevant_course_content",
    "get_section_information" => "Elixir.Oli.Conversation.Functions.get_section_information"
  }

  @functions [
    %{
      name: "up_next",
      description:
        "Returns the next scheduled lessons in the course as a list of objects with the following keys: title, url, due_date, num_attempts_taken",
      parameters: %{
        type: "object",
        properties: %{
          current_user_id: %{
            type: "integer",
            description: "The current student's user id"
          },
          section_id: %{
            type: "integer",
            description: "The current course section's id"
          }
        },
        required: ["current_user_id", "section_id"]
      }
    },
    %{
      name: "avg_score_for",
      description:
        "Returns average score across all scored assessments, as a floating point number between 0 and 1, for a given user and section",
      parameters: %{
        type: "object",
        properties: %{
          current_user_id: %{
            type: "integer",
            description: "The current student's user id"
          },
          section_id: %{
            type: "integer",
            description: "The current course section's id"
          }
        },
        required: ["current_user_id", "section_id"]
      }
    },
    %{
      name: "relevant_course_content",
      description: """
      Useful when a question asked by a student cannot be adequately answered by the context of the current lesson.
      Allows the retrieval of relevant course content from other lessons in the course based on the
      student's question. Returns an array of course lessons with the following keys: title, url, content.
      """,
      parameters: %{
        type: "object",
        properties: %{
          student_input: %{
            type: "string",
            description: "The student question or input"
          },
          section_id: %{
            type: "integer",
            description: "The current course section's id"
          }
        },
        required: ["student_input", "section_id"]
      }
    },
    %{
      name: "get_section_information",
      description: """
      Useful when a question asked by a student cannot be adequately answered by the context of the current lesson.
      Allows the retrieval of general course information based on the student's question.
      For a given course section return the following information:
      - instructors: name and email
      - layout: all modules and units
      - content: titles for all the pages
      """,
      parameters: %{
        type: "object",
        properties: %{
          section_id: %{
            type: "integer",
            description: "The current course section's id"
          }
        },
        required: ["section_id"]
      }
    }
  ]

  @doc """
  Takes a function name as a string in the form of "Elixir.ModuleName.function_name" and a
  map of arguments, executes that function with the arguments and prepares the returned
  result for sending back to an LLM based agent.
  """
  def call(name, arguments_as_map) do
    full_name = Map.get(@lookup_table, name)

    if full_name == nil do
      raise "Invalid function name: #{name}"
    end

    case String.split(full_name, ".") do
      parts when is_list(parts) ->
        module_parts = Enum.take(parts, Enum.count(parts) - 1)
        name = Enum.at(parts, -1) |> String.to_existing_atom()

        result =
          Enum.join(module_parts, ".")
          |> String.to_existing_atom()
          |> apply(name, [arguments_as_map])

        case result do
          result when is_binary(result) -> result
          result when is_map(result) -> Jason.encode!(result)
          result when is_list(result) -> Jason.encode!(%{result: result})
          result -> Kernel.to_string(result)
        end

      _ ->
        raise "Invalid function name: #{full_name}"
    end
  end

  def functions, do: @functions

  def total_token_length,
    do: Enum.reduce(@functions, 0, fn f, acc -> acc + estimate_token_length(f) end)

  def avg_score_for(%{"current_user_id" => user_id, "section_id" => section_id}) do
    Oli.Delivery.Metrics.avg_score_for(section_id, user_id, nil)
  end

  def up_next(%{"current_user_id" => user_id, "section_id" => section_id}) do
    get_next_activities_for_student(section_id, user_id)
  end

  def relevant_course_content(%{"student_input" => input, "section_id" => section_id}) do
    section = Oli.Delivery.Sections.get_section!(section_id)

    case Oli.Search.Embeddings.most_relevant_pages(input, section_id) do
      {:ok, relevant_pages} ->
        Enum.map(relevant_pages, fn page ->
          revision = Oli.Resources.get_revision!(page.revision_id)

          content =
            Enum.map(page.chunks, fn chunk ->
              chunk.content
            end)
            |> Enum.join("\n\n")

          %{
            title: page.title,
            url: Routes.page_delivery_url(OliWeb.Endpoint, :page, section.slug, revision.slug),
            content: content
          }
        end)

      e ->
        e
    end
  end

  def get_next_activities_for_student(section_id, user_id) do
    section = Oli.Delivery.Sections.get_section!(section_id)
    student_pages_query = Oli.Delivery.Sections.get_student_pages(section.slug, user_id)

    ras =
      Oli.Delivery.Attempts.Core.get_resource_accesses(section.slug, user_id)
      |> Enum.reduce(%{}, fn ra, acc -> Map.put(acc, ra.resource_id, ra) end)

    query =
      from(sp in subquery(student_pages_query),
        where:
          sp.graded == true and
            not is_nil(sp.end_date) and
            sp.end_date >= ^DateTime.utc_now() and
            sp.resource_type_id == ^Oli.Resources.ResourceType.get_id_by_type("page"),
        limit: 2
      )

    query
    |> Oli.Repo.all()
    |> Enum.map(fn page ->
      %{
        title: page.title,
        url: Routes.page_delivery_path(OliWeb.Endpoint, :page, section.slug, page.slug),
        due_date: page.end_date,
        num_attempts_taken:
          Map.get(ras, page.resource_id, %{resource_attempts_count: 0}).resource_attempts_count
      }
    end)
  end

  def get_section_information(%{"section_id" => section_id}),
    do: Oli.Delivery.Sections.get_section_prompt_info(section_id)
end
