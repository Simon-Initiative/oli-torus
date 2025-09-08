defmodule Oli.Scenarios.DirectiveParser do
  @moduledoc """
  Parses YAML files containing course specification directives.
  Supports a flexible, sequential format where directives are processed in order.
  """

  alias Oli.Scenarios.DirectiveValidator
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
    AnswerQuestionDirective,
    CloneDirective,
    UseDirective,
    HookDirective
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
    # Validate attributes
    allowed_attrs = ["name", "title", "root", "objectives", "tags"]
    case DirectiveValidator.validate_attributes(allowed_attrs, project_data, "project") do
      :ok ->
        %ProjectDirective{
          name: project_data["name"] || project_data["title"],
          title: project_data["title"],
          root: parse_node(project_data["root"]),
          objectives: parse_objectives(project_data["objectives"]),
          tags: parse_tags(project_data["tags"])
        }
      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"clone" => clone_data}) do
    # Validate attributes
    allowed_attrs = ["from", "name", "title"]
    case DirectiveValidator.validate_attributes(allowed_attrs, clone_data, "clone") do
      :ok ->
        %CloneDirective{
          from: clone_data["from"],
          name: clone_data["name"],
          title: clone_data["title"]
        }
      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"section" => section_data}) do
    # Validate attributes
    allowed_attrs = ["name", "title", "from", "type", "registration_open"]
    case DirectiveValidator.validate_attributes(allowed_attrs, section_data, "section") do
      :ok ->
        %SectionDirective{
          name: section_data["name"] || section_data["title"],
          title: section_data["title"],
          from: section_data["from"],
          type: parse_section_type(section_data["type"]),
          registration_open: Map.get(section_data, "registration_open", true)
        }
      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"product" => product_data}) do
    # Validate attributes
    allowed_attrs = ["name", "title", "from"]
    case DirectiveValidator.validate_attributes(allowed_attrs, product_data, "product") do
      :ok ->
        %ProductDirective{
          name: product_data["name"] || product_data["title"],
          title: product_data["title"],
          from: product_data["from"]
        }
      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"remix" => remix_data}) do
    # Validate attributes
    allowed_attrs = ["from", "resource", "section", "to"]
    case DirectiveValidator.validate_attributes(allowed_attrs, remix_data, "remix") do
      :ok ->
        %RemixDirective{
          from: remix_data["from"],
          resource: remix_data["resource"],
          section: remix_data["section"],
          to: remix_data["to"]
        }
      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"manipulate" => manipulate_data}) do
    # Validate attributes
    allowed_attrs = ["to", "ops"]
    case DirectiveValidator.validate_attributes(allowed_attrs, manipulate_data, "manipulate") do
      :ok ->
        %ManipulateDirective{
          to: manipulate_data["to"],
          ops: manipulate_data["ops"] || []
        }
      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"publish" => publish_data}) do
    # Validate attributes
    allowed_attrs = ["to", "description"]
    case DirectiveValidator.validate_attributes(allowed_attrs, publish_data, "publish") do
      :ok ->
        %PublishDirective{
          to: publish_data["to"],
          description: publish_data["description"]
        }
      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"assert" => assert_data}) do
    # Validate attributes
    allowed_attrs = ["structure", "resource", "progress", "proficiency", "assertions"]
    case DirectiveValidator.validate_attributes(allowed_attrs, assert_data, "assert") do
      :ok ->
        %AssertDirective{
          structure: parse_structure_assertion(assert_data["structure"]),
          resource: parse_resource_assertion(assert_data["resource"]),
          progress: parse_progress_assertion(assert_data["progress"]),
          proficiency: parse_proficiency_assertion(assert_data["proficiency"]),
          assertions: assert_data["assertions"]
        }
      {:error, msg} ->
        raise msg
    end
  end
  
  # Support "verify" as an alias for "assert" for backward compatibility
  defp parse_directive(%{"verify" => verify_data}) do
    # If verify has a "to" and "structure" field, convert to assert format
    {assert_data, allowed_attrs} = if Map.has_key?(verify_data, "to") && Map.has_key?(verify_data, "structure") do
      # Legacy format with "to" at top level
      {%{"structure" => Map.merge(verify_data["structure"], %{"to" => verify_data["to"]})},
       ["to", "structure", "resource", "progress", "proficiency", "assertions"]}
    else
      # Standard format
      {verify_data, ["structure", "resource", "progress", "proficiency", "assertions"]}
    end
    
    # Validate attributes
    case DirectiveValidator.validate_attributes(allowed_attrs, verify_data, "verify") do
      :ok ->
        %AssertDirective{
          structure: parse_structure_assertion(assert_data["structure"]),
          resource: parse_resource_assertion(assert_data["resource"]),
          progress: parse_progress_assertion(assert_data["progress"]),
          proficiency: parse_proficiency_assertion(assert_data["proficiency"]),
          assertions: assert_data["assertions"]
        }
      {:error, msg} ->
        raise msg
    end
  end
  
  defp parse_directive(%{"update" => update_data}) do
    # Validate attributes
    allowed_attrs = ["from", "to"]
    case DirectiveValidator.validate_attributes(allowed_attrs, update_data, "update") do
      :ok ->
        %UpdateDirective{
          from: update_data["from"],
          to: update_data["to"]
        }
      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"customize" => customize_data}) do
    # Validate attributes
    allowed_attrs = ["to", "ops"]
    case DirectiveValidator.validate_attributes(allowed_attrs, customize_data, "customize") do
      :ok ->
        %CustomizeDirective{
          to: customize_data["to"],
          ops: customize_data["ops"] || []
        }
      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"user" => user_data}) do
    # Validate attributes
    allowed_attrs = ["name", "type", "email", "given_name", "family_name"]
    case DirectiveValidator.validate_attributes(allowed_attrs, user_data, "user") do
      :ok ->
        %UserDirective{
          name: user_data["name"],
          type: parse_user_type(user_data["type"]),
          email: user_data["email"] || "#{user_data["name"]}@test.edu",
          given_name: user_data["given_name"] || user_data["name"],
          family_name: user_data["family_name"] || "Test"
        }
      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"enroll" => enroll_data}) do
    # Validate attributes
    allowed_attrs = ["user", "section", "role"]
    case DirectiveValidator.validate_attributes(allowed_attrs, enroll_data, "enroll") do
      :ok ->
        %EnrollDirective{
          user: enroll_data["user"],
          section: enroll_data["section"],
          role: parse_enrollment_role(enroll_data["role"])
        }
      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"institution" => inst_data}) do
    # Validate attributes
    allowed_attrs = ["name", "country_code", "institution_email", "institution_url"]
    case DirectiveValidator.validate_attributes(allowed_attrs, inst_data, "institution") do
      :ok ->
        %InstitutionDirective{
          name: inst_data["name"],
          country_code: inst_data["country_code"] || "US",
          institution_email: inst_data["institution_email"] || "admin@#{inst_data["name"]}.edu",
          institution_url: inst_data["institution_url"] || "http://#{inst_data["name"]}.edu"
        }
      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"create_activity" => activity_data}) do
    # Validate attributes
    allowed_attrs = ["project", "title", "virtual_id", "scope", "type", "content", "objectives", "tags"]
    case DirectiveValidator.validate_attributes(allowed_attrs, activity_data, "create_activity") do
      :ok ->
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
      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"edit_page" => edit_data}) do
    # Validate attributes
    allowed_attrs = ["project", "page", "content"]
    case DirectiveValidator.validate_attributes(allowed_attrs, edit_data, "edit_page") do
      :ok ->
        %EditPageDirective{
          project: edit_data["project"],
          page: edit_data["page"],
          content: edit_data["content"]
        }
      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"view_practice_page" => view_data}) do
    # Validate attributes
    allowed_attrs = ["student", "section", "page"]
    case DirectiveValidator.validate_attributes(allowed_attrs, view_data, "view_practice_page") do
      :ok ->
        %ViewPracticePageDirective{
          student: view_data["student"],
          section: view_data["section"],
          page: view_data["page"]
        }
      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"answer_question" => answer_data}) do
    # Validate attributes
    allowed_attrs = ["student", "section", "page", "activity_virtual_id", "response"]
    case DirectiveValidator.validate_attributes(allowed_attrs, answer_data, "answer_question") do
      :ok ->
        %AnswerQuestionDirective{
          student: answer_data["student"],
          section: answer_data["section"],
          page: answer_data["page"],
          activity_virtual_id: answer_data["activity_virtual_id"],
          response: answer_data["response"]
        }
      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"use" => use_data}) do
    # Validate attributes
    allowed_attrs = ["file"]
    case DirectiveValidator.validate_attributes(allowed_attrs, use_data, "use") do
      :ok ->
        %UseDirective{
          file: use_data["file"]
        }
      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"hook" => hook_data}) do
    # Validate attributes
    allowed_attrs = ["function"]
    case DirectiveValidator.validate_attributes(allowed_attrs, hook_data, "hook") do
      :ok ->
        %HookDirective{
          function: hook_data["function"]
        }
      {:error, msg} ->
        raise msg
    end
  end

  # Handle single unrecognized directive
  defp parse_directive(map) when is_map(map) and map_size(map) == 1 do
    [{key, _value}] = Enum.to_list(map)

    if key not in [
         "project",
         "clone",
         "section",
         "product",
         "remix",
         "manipulate",
         "publish",
         "assert",
         "verify",
         "user",
         "enroll",
         "institution",
         "update",
         "customize",
         "create_activity",
         "edit_page",
         "view_practice_page",
         "answer_question",
         "use",
         "hook"
       ] do
      raise "Unrecognized directive: '#{key}'. Valid directives are: project, clone, section, product, remix, manipulate, publish, assert, verify, user, enroll, institution, update, customize, create_activity, edit_page, view_practice_page, answer_question, use, hook"
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
             "clone",
             "section",
             "product",
             "remix",
             "manipulate",
             "publish",
             "assert",
             "verify",
             "user",
             "enroll",
             "institution",
             "create_activity",
             "edit_page",
             "view_practice_page",
             "answer_question",
             "update",
             "customize",
             "use",
             "hook"
           ] ->
        [parse_directive(%{key => value})]

      {key, _value} ->
        raise "Unrecognized directive: '#{key}'. Valid directives are: project, clone, section, product, remix, manipulate, publish, assert, verify, user, enroll, institution, update, customize, create_activity, edit_page, view_practice_page, answer_question, use, hook"
    end)
  end

  defp parse_structure_assertion(nil), do: nil
  defp parse_structure_assertion(data) when is_map(data) do
    case DirectiveValidator.validate_assertion_attributes(:structure, data) do
      :ok ->
        %{
          to: data["to"],
          root: parse_node(data["root"])
        }
      {:error, msg} ->
        raise msg
    end
  end
  
  defp parse_resource_assertion(nil), do: nil
  defp parse_resource_assertion(data) when is_map(data) do
    case DirectiveValidator.validate_assertion_attributes(:resource, data) do
      :ok ->
        %{
          to: data["to"],
          target: data["target"],
          resource: data["resource"]
        }
      {:error, msg} ->
        raise msg
    end
  end
  
  defp parse_progress_assertion(nil), do: nil
  defp parse_progress_assertion(data) when is_map(data) do
    case DirectiveValidator.validate_assertion_attributes(:progress, data) do
      :ok ->
        %{
          section: data["section"],
          progress: parse_float(data["progress"]),
          page: data["page"],
          container: data["container"],
          student: data["student"]
        }
      {:error, msg} ->
        raise msg
    end
  end
  
  defp parse_proficiency_assertion(nil), do: nil
  defp parse_proficiency_assertion(data) when is_map(data) do
    case DirectiveValidator.validate_assertion_attributes(:proficiency, data) do
      :ok ->
        %{
          section: data["section"],
          objective: data["objective"],
          bucket: data["bucket"],
          value: if(data["value"], do: parse_float(data["value"]), else: nil),
          student: data["student"],
          page: data["page"],
          container: data["container"]
        }
      {:error, msg} ->
        raise msg
    end
  end

  # Parse node structures (for project and verification structures)
  defp parse_node(nil), do: nil

  defp parse_node(%{"root" => root_data}) do
    # Validate the wrapper
    case DirectiveValidator.validate_node_attributes(%{"root" => root_data}) do
      :ok -> parse_node(root_data)
      {:error, msg} -> raise msg
    end
  end

  defp parse_node(%{"page" => title} = data) do
    case DirectiveValidator.validate_node_attributes(data) do
      :ok -> %Node{type: :page, title: title}
      {:error, msg} -> raise msg
    end
  end

  defp parse_node(%{"container" => title, "children" => children} = data) do
    case DirectiveValidator.validate_node_attributes(data) do
      :ok ->
        %Node{
          type: :container,
          title: title,
          children: Enum.map(children, &parse_node/1)
        }
      {:error, msg} -> raise msg
    end
  end

  defp parse_node(%{"container" => title} = data) do
    case DirectiveValidator.validate_node_attributes(data) do
      :ok -> %Node{type: :container, title: title, children: []}
      {:error, msg} -> raise msg
    end
  end

  defp parse_node(%{"children" => children} = data) do
    case DirectiveValidator.validate_node_attributes(data) do
      :ok ->
        %Node{
          type: :container,
          title: "root",
          children: Enum.map(children, &parse_node/1)
        }
      {:error, msg} -> raise msg
    end
  end
  
  defp parse_node(data) when is_map(data) do
    # Unknown node structure
    case DirectiveValidator.validate_node_attributes(data) do
      {:error, msg} -> raise msg
      _ -> raise "Invalid node structure"
    end
  end

  # Parse objectives structure
  defp parse_objectives(nil), do: nil
  defp parse_objectives(objectives) when is_list(objectives) do
    Enum.map(objectives, &parse_objective/1)
  end

  defp parse_objective(objective) when is_binary(objective) do
    # Simple string - parent objective with no children
    case DirectiveValidator.validate_objective(objective) do
      :ok -> %{title: objective, children: []}
      {:error, msg} -> raise msg
    end
  end
  
  defp parse_objective(objective) when is_map(objective) do
    # Map should have exactly one key-value pair where key is the title and value is the children
    case DirectiveValidator.validate_objective(objective) do
      :ok ->
        [{title, children}] = Map.to_list(objective)
        %{title: title, children: children}
      {:error, msg} ->
        raise msg
    end
  end
  
  defp parse_objective(objective) do
    case DirectiveValidator.validate_objective(objective) do
      {:error, msg} -> raise msg
      _ -> raise "Invalid objective format"
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
