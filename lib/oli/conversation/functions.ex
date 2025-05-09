defmodule Oli.Conversation.Functions do
  import Oli.Conversation.Common
  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Section, SectionResourceDepot}
  alias Oli.Resources.ResourceType
  alias OliWeb.Router.Helpers, as: Routes

  @lookup_table %{
    "avg_score_for" => "Elixir.Oli.Conversation.Functions.avg_score_for",
    "up_next" => "Elixir.Oli.Conversation.Functions.up_next",
    "relevant_course_content" => "Elixir.Oli.Conversation.Functions.relevant_course_content",
    "course_sequence" => "Elixir.Oli.Conversation.Functions.course_sequence"
  }

  @functions [
    %{
      name: "course_sequence",
      description: """
      Returns the full sequence of units, modules, sections and learning pages in this course as a
      list of objects with the following keys: [resource_id, title, url, is_page, graded, level] where
      resource_id is the unique identifier of the page or container, and
      title is the title of the page or container, url is the url to the page, is_page is a boolean
      indicating if the object is a page or a container, graded is a boolean indicating if the
      page is graded or is practice, and level is the level of the page or container in the hierarchy.
      The level is a number starting from 1 for the first level of the hierarchy.
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
    },
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
      Allows the retrieval of relevant course content from other lessons in the course based on the student's question.
      Returns an object with the following keys:
        - relevant_pages: Pages that may be relevant regarding to the student's question
        - instructors: Name and email for the instructors of this course
        - layout: The name of all modules and units for this course
        - content: The title of all the pages of this course
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

  def course_sequence(%{"section_id" => section_id}) do
    section = Oli.Delivery.Sections.get_section!(section_id)

    Oli.Delivery.Sections.SectionResourceDepot.get_delivery_resolver_full_hierarchy(section)
    |> Oli.Delivery.Hierarchy.flatten_hierarchy()
    |> Enum.map(fn node ->
      %{
        url: Routes.page_delivery_url(OliWeb.Endpoint, :page, section.slug, node.revision.slug),
        title: node.revision.title,
        is_page: node.revision.resource_type_id == Oli.Resources.ResourceType.id_for_page(),
        level: node.numbering.level,
        graded: node.revision.graded
      }
    end)
  end

  def relevant_course_content(%{"student_input" => input, "section_id" => section_id}) do
    section = Oli.Delivery.Sections.get_section!(section_id)

    relevant_pages =
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

        _e ->
          []
      end

    section_id
    |> get_section_prompt_info()
    |> Map.put(:relevant_pages, relevant_pages)
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

  defp get_section_prompt_info(section_id) do
    %Section{customizations: customizations} = section = Oli.Repo.get(Section, section_id)

    {containers, pages} =
      section_id
      |> SectionResourceDepot.get_section_resources_by_type_ids([
        ResourceType.id_for_container(),
        ResourceType.id_for_page()
      ])
      |> Enum.split_with(&(&1.resource_type_id == ResourceType.id_for_container()))

    instructors =
      section.slug
      |> Sections.fetch_instructors()
      |> Enum.map(&%{name: &1.name, email: &1.email})

    content = Enum.map(pages, & &1.title)

    layout =
      containers
      |> Enum.sort_by(&{&1.numbering_level, &1.numbering_index})
      |> Enum.map(fn c ->
        label =
          Sections.get_container_label_and_numbering(
            c.numbering_level,
            c.numbering_index,
            customizations
          )

        "#{label}: #{c.title}"
      end)

    %{
      instructors: instructors,
      layout: layout,
      content: content
    }
  end
end
