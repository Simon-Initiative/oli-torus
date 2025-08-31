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
    VerifyDirective,
    UserDirective,
    EnrollDirective,
    InstitutionDirective,
    UpdateDirective,
    CustomizeDirective
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
      root: parse_node(project_data["root"])
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

  defp parse_directive(%{"verify" => verify_data}) do
    %VerifyDirective{
      to: verify_data["to"],
      structure: parse_node(verify_data["structure"]),
      assertions: verify_data["assertions"] || []
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
         "verify",
         "user",
         "enroll",
         "institution",
         "update",
         "customize"
       ] do
      raise "Unrecognized directive: '#{key}'. Valid directives are: project, section, product, remix, manipulate, publish, verify, user, enroll, institution, update, customize"
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
             "verify",
             "user",
             "enroll",
             "institution",
             "update",
             "customize"
           ] ->
        [parse_directive(%{key => value})]

      {key, _value} ->
        raise "Unrecognized directive: '#{key}'. Valid directives are: project, section, product, remix, manipulate, publish, verify, user, enroll, institution, update, customize"
    end)
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
end
