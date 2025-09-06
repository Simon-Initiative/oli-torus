defmodule Oli.Scenarios.DirectiveParser do
  @moduledoc """
  Parses YAML files containing course specification directives.
  Supports a flexible, sequential format where directives are processed in order.
  """

  alias Oli.Scenarios.DirectiveTypes.{
    ProjectDirective,
    SectionDirective,
    ProductDirective,
    RemixDirective,
    ManipulateDirective,
    PublishDirective,
    AssertDirective,
    UserDirective,
    EnrollDirective,
    InstitutionDirective,
    UpdateDirective,
    CustomizeDirective,
    ActivityDirective,
    EditPageDirective,
    ViewPracticePageDirective,
    AnswerQuestionDirective
  }

  alias Oli.Scenarios.Types.Node

  @doc """
  Loads and parses a YAML file containing course specification directives.
  Returns a list of parsed directives in the order they appear.
  """
  def load_file!(path) do
    path
    |> File.read!()
    |> parse_yaml!()
  end

  @doc """
  Parses YAML content into a list of directives.
  """
  def parse_yaml!(yaml_content) do
    yaml_content
    |> YamlElixir.read_from_string!()
    |> parse_directives()
  end

  defp parse_directives(data) when is_list(data) do
    Enum.map(data, &parse_directive/1)
  end

  defp parse_directives(data) when is_map(data) do
    # Handle single directive or convert map to list of directives
    if Map.has_key?(data, "directives") do
      parse_directives(data["directives"])
    else
      # Legacy format - convert to list
      [parse_directive(data)]
    end
  end

  # Parse individual directive based on its type
  defp parse_directive(%{"project" => project_data}) do
    %ProjectDirective{
      name: project_data["name"] || project_data["title"],
      title: project_data["title"],
      root: parse_node(project_data["root"]),
      objectives: parse_objectives(project_data["objectives"]),
      tags: parse_tags(project_data["tags"])
    }
  end

  defp parse_directive(%{"section" => section_data}) do
    %SectionDirective{
      name: section_data["name"] || section_data["title"],
      title: section_data["title"],
      from: section_data["from"],
      type: parse_section_type(section_data["type"]),
      registration_open: Map.get(section_data, "registration_open", true)
    }
  end

  defp parse_directive(%{"product" => product_data}) do
    %ProductDirective{
      name: product_data["name"] || product_data["title"],
      title: product_data["title"],
      from: product_data["from"]
    }
  end

  defp parse_directive(%{"remix" => remix_data}) do
    %RemixDirective{
      from: remix_data["from"],
      resource: remix_data["resource"],
      section: remix_data["section"],
      to: remix_data["to"]
    }
  end

  defp parse_directive(%{"manipulate" => manipulate_data}) do
    %ManipulateDirective{
      to: manipulate_data["to"],
      ops: manipulate_data["ops"] || []
    }
  end

  defp parse_directive(%{"publish" => publish_data}) do
    %PublishDirective{
      to: publish_data["to"],
      description: publish_data["description"]
    }
  end

  defp parse_directive(%{"assert" => assert_data}) do
    %AssertDirective{
      structure: parse_structure_assertion(assert_data["structure"]),
      resource: parse_resource_assertion(assert_data["resource"]),
      progress: parse_progress_assertion(assert_data["progress"]),
      proficiency: parse_proficiency_assertion(assert_data["proficiency"]),
      assertions: assert_data["assertions"]
    }
  end
  
  defp parse_directive(%{"update" => update_data}) do
    %UpdateDirective{
      from: update_data["from"],
      to: update_data["to"]
    }
  end

  defp parse_directive(%{"customize" => customize_data}) do
    %CustomizeDirective{
      to: customize_data["to"],
      ops: customize_data["ops"] || []
    }
  end

  defp parse_directive(%{"user" => user_data}) do
    %UserDirective{
      name: user_data["name"],
      type: parse_user_type(user_data["type"]),
      email: user_data["email"] || "#{user_data["name"]}@test.edu",
      given_name: user_data["given_name"] || user_data["name"],
      family_name: user_data["family_name"] || "Test"
    }
  end

  defp parse_directive(%{"enroll" => enroll_data}) do
    %EnrollDirective{
      user: enroll_data["user"],
      section: enroll_data["section"],
      role: parse_enrollment_role(enroll_data["role"])
    }
  end

  defp parse_directive(%{"institution" => inst_data}) do
    %InstitutionDirective{
      name: inst_data["name"],
      country_code: inst_data["country_code"] || "US",
      institution_email: inst_data["institution_email"] || "admin@#{inst_data["name"]}.edu",
      institution_url: inst_data["institution_url"] || "http://#{inst_data["name"]}.edu"
    }
  end

  defp parse_directive(%{"create_activity" => activity_data}) do
    %ActivityDirective{
      project: activity_data["project"],
      title: activity_data["title"],
      virtual_id: activity_data["virtual_id"],
      scope: activity_data["scope"] || "embedded",
      type: activity_data["type"],
      content: activity_data["content"],
      objectives: activity_data["objectives"],
      tags: activity_data["tags"]
    }
  end

  defp parse_directive(%{"edit_page" => edit_data}) do
    %EditPageDirective{
      project: edit_data["project"],
      page: edit_data["page"],
      content: edit_data["content"]
    }
  end

  defp parse_directive(%{"view_practice_page" => view_data}) do
    %ViewPracticePageDirective{
      student: view_data["student"],
      section: view_data["section"],
      page: view_data["page"]
    }
  end

  defp parse_directive(%{"answer_question" => answer_data}) do
    %AnswerQuestionDirective{
      student: answer_data["student"],
      section: answer_data["section"],
      page: answer_data["page"],
      activity_virtual_id: answer_data["activity_virtual_id"],
      response: answer_data["response"]
    }
  end

  # Handle single unrecognized directive
  defp parse_directive(map) when is_map(map) and map_size(map) == 1 do
    [{key, _value}] = Enum.to_list(map)

    if key not in [
         "project",
         "section",
         "product",
         "remix",
         "manipulate",
         "publish",
         "assert",
         "user",
         "enroll",
         "institution",
         "update",
         "customize",
         "create_activity",
         "edit_page",
         "view_practice_page",
         "answer_question"
       ] do
      raise "Unrecognized directive: '#{key}'. Valid directives are: project, section, product, remix, manipulate, publish, assert, user, enroll, institution, update, customize, create_activity, edit_page, view_practice_page, answer_question"
    else
      # This shouldn't happen as specific handlers above should match first
      raise "Internal error: unhandled directive '#{key}'"
    end
  end

  # Handle multiple directives in a single map (for complex YAML structures)
  defp parse_directive(map) when is_map(map) do
    Enum.flat_map(map, fn
      {key, value}
      when key in [
             "project",
             "section",
             "product",
             "remix",
             "manipulate",
             "publish",
             "assert",
             "user",
             "enroll",
             "institution",
             "create_activity",
             "edit_page",
             "view_practice_page",
             "answer_question",
             "update",
             "customize"
           ] ->
        [parse_directive(%{key => value})]

      {key, _value} ->
        raise "Unrecognized directive: '#{key}'. Valid directives are: project, section, product, remix, manipulate, publish, assert, user, enroll, institution, update, customize, create_activity, edit_page, view_practice_page, answer_question"
    end)
  end

  defp parse_structure_assertion(nil), do: nil
  defp parse_structure_assertion(data) when is_map(data) do
    %{
      to: data["to"],
      root: parse_node(data["root"])
    }
  end
  
  defp parse_resource_assertion(nil), do: nil
  defp parse_resource_assertion(data) when is_map(data) do
    %{
      to: data["to"],
      target: data["target"],
      resource: data["resource"]
    }
  end
  
  defp parse_progress_assertion(nil), do: nil
  defp parse_progress_assertion(data) when is_map(data) do
    %{
      section: data["section"],
      progress: parse_float(data["progress"]),
      page: data["page"],
      container: data["container"],
      student: data["student"]
    }
  end
  
  defp parse_proficiency_assertion(nil), do: nil
  defp parse_proficiency_assertion(data) when is_map(data) do
    %{
      section: data["section"],
      objective: data["objective"],
      bucket: data["bucket"],
      value: if(data["value"], do: parse_float(data["value"]), else: nil),
      student: data["student"],
      page: data["page"],
      container: data["container"]
    }
  end

  # Parse node structures (for project and verification structures)
  defp parse_node(nil), do: nil

  defp parse_node(%{"root" => root_data}) do
    parse_node(root_data)
  end

  defp parse_node(%{"page" => title}) do
    %Node{type: :page, title: title}
  end

  defp parse_node(%{"container" => title, "children" => children}) do
    %Node{
      type: :container,
      title: title,
      children: Enum.map(children, &parse_node/1)
    }
  end

  defp parse_node(%{"container" => title}) do
    %Node{type: :container, title: title, children: []}
  end

  defp parse_node(%{"children" => children}) do
    %Node{
      type: :container,
      title: "root",
      children: Enum.map(children, &parse_node/1)
    }
  end

  # Parse objectives structure
  defp parse_objectives(nil), do: nil
  defp parse_objectives(objectives) when is_list(objectives) do
    Enum.map(objectives, &parse_objective/1)
  end

  defp parse_objective(objective) when is_binary(objective) do
    # Simple string - parent objective with no children
    %{title: objective, children: []}
  end
  
  defp parse_objective(objective) when is_map(objective) do
    # Map should have exactly one key-value pair where key is the title and value is the children
    case Map.to_list(objective) do
      [{title, children}] when is_binary(title) and is_list(children) ->
        # Simple format: {"Objective Title" => ["child1", "child2"]}
        %{title: title, children: children}
      [{_, _}] ->
        # Any other single key-value pair is invalid
        raise "Invalid objective format. Use either a string for simple objectives or {\"Title\": [children]} for objectives with sub-objectives"
      _ ->
        # Multiple keys or other structures are invalid
        raise "Invalid objective format. Use either a string for simple objectives or {\"Title\": [children]} for objectives with sub-objectives"
    end
  end

  # Parse tags - just a flat list of strings
  defp parse_tags(nil), do: nil
  defp parse_tags(tags) when is_list(tags), do: tags
  
  # Helper functions for parsing enum values
  defp parse_section_type(nil), do: :enrollable
  defp parse_section_type("enrollable"), do: :enrollable
  defp parse_section_type("open_and_free"), do: :open_and_free
  defp parse_section_type(type) when is_atom(type), do: type

  defp parse_user_type(nil), do: :student
  defp parse_user_type("author"), do: :author
  defp parse_user_type("instructor"), do: :instructor
  defp parse_user_type("student"), do: :student
  defp parse_user_type(type) when is_atom(type), do: type

  defp parse_enrollment_role(nil), do: :student
  defp parse_enrollment_role("instructor"), do: :instructor
  defp parse_enrollment_role("student"), do: :student
  defp parse_enrollment_role(role) when is_atom(role), do: role
  
  defp parse_float(nil), do: 0.0
  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value / 1.0
  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> 0.0
    end
  end
end
