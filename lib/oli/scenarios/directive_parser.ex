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
    VisitPageDirective,
    StartAttemptDirective,
    GateDirective,
    TimeDirective,
    AnswerQuestionDirective,
    CertificateDirective,
    DiscussionPostDirective,
    ClassNoteDirective,
    CompleteScoredPageDirective,
    FinalizeAttemptDirective,
    StudentExceptionDirective,
    CertificateActionDirective,
    CloneDirective,
    UseDirective,
    CollaboratorDirective,
    MediaDirective,
    BibliographyDirective,
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
    allowed_attrs = ["name", "title", "root", "objectives", "tags", "slug", "visibility"]

    case DirectiveValidator.validate_attributes(allowed_attrs, project_data, "project") do
      :ok ->
        %ProjectDirective{
          name: project_data["name"] || project_data["title"],
          title: project_data["title"],
          root: parse_node(project_data["root"]),
          objectives: parse_objectives(project_data["objectives"]),
          tags: parse_tags(project_data["tags"]),
          slug: project_data["slug"],
          visibility: parse_visibility(project_data["visibility"])
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
    allowed_attrs = [
      "name",
      "title",
      "from",
      "type",
      "registration_open",
      "slug",
      "open_and_free",
      "requires_enrollment"
    ]

    case DirectiveValidator.validate_attributes(allowed_attrs, section_data, "section") do
      :ok ->
        %SectionDirective{
          name: section_data["name"] || section_data["title"],
          title: section_data["title"],
          from: section_data["from"],
          type: parse_section_type(section_data["type"]),
          registration_open: Map.get(section_data, "registration_open", true),
          slug: section_data["slug"],
          open_and_free: parse_boolean(section_data["open_and_free"], false, "open_and_free"),
          requires_enrollment:
            parse_boolean(section_data["requires_enrollment"], false, "requires_enrollment")
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
    allowed_attrs = [
      "structure",
      "resource",
      "progress",
      "proficiency",
      "certificate",
      "gating",
      "prologue",
      "gradebook",
      "review_attempt",
      "activity_attempt",
      "assertions"
    ]

    case DirectiveValidator.validate_attributes(allowed_attrs, assert_data, "assert") do
      :ok ->
        %AssertDirective{
          structure: parse_structure_assertion(assert_data["structure"]),
          resource: parse_resource_assertion(assert_data["resource"]),
          progress: parse_progress_assertion(assert_data["progress"]),
          proficiency: parse_proficiency_assertion(assert_data["proficiency"]),
          certificate: parse_certificate_assertion(assert_data["certificate"]),
          gating: parse_gating_assertion(assert_data["gating"]),
          prologue: parse_prologue_assertion(assert_data["prologue"]),
          gradebook: parse_gradebook_assertion(assert_data["gradebook"]),
          review_attempt: parse_review_attempt_assertion(assert_data["review_attempt"]),
          activity_attempt: parse_activity_attempt_assertion(assert_data["activity_attempt"]),
          assertions: assert_data["assertions"]
        }

      {:error, msg} ->
        raise msg
    end
  end

  # Support "verify" as an alias for "assert" for backward compatibility
  defp parse_directive(%{"verify" => verify_data}) do
    # If verify has a "to" and "structure" field, convert to assert format
    {assert_data, allowed_attrs} =
      if Map.has_key?(verify_data, "to") && Map.has_key?(verify_data, "structure") do
        # Legacy format with "to" at top level
        {%{"structure" => Map.merge(verify_data["structure"], %{"to" => verify_data["to"]})},
         [
           "to",
           "structure",
           "resource",
           "progress",
           "proficiency",
           "certificate",
           "gating",
           "prologue",
           "gradebook",
           "review_attempt",
           "activity_attempt",
           "assertions"
         ]}
      else
        # Standard format
        {verify_data,
         [
           "structure",
           "resource",
           "progress",
           "proficiency",
           "certificate",
           "gating",
           "prologue",
           "gradebook",
           "review_attempt",
           "activity_attempt",
           "assertions"
         ]}
      end

    # Validate attributes
    case DirectiveValidator.validate_attributes(allowed_attrs, verify_data, "verify") do
      :ok ->
        %AssertDirective{
          structure: parse_structure_assertion(assert_data["structure"]),
          resource: parse_resource_assertion(assert_data["resource"]),
          progress: parse_progress_assertion(assert_data["progress"]),
          proficiency: parse_proficiency_assertion(assert_data["proficiency"]),
          certificate: parse_certificate_assertion(assert_data["certificate"]),
          gating: parse_gating_assertion(assert_data["gating"]),
          prologue: parse_prologue_assertion(assert_data["prologue"]),
          gradebook: parse_gradebook_assertion(assert_data["gradebook"]),
          review_attempt: parse_review_attempt_assertion(assert_data["review_attempt"]),
          activity_attempt: parse_activity_attempt_assertion(assert_data["activity_attempt"]),
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
    allowed_attrs = [
      "name",
      "type",
      "email",
      "given_name",
      "family_name",
      "password",
      "system_role",
      "can_create_sections",
      "email_verified"
    ]

    case DirectiveValidator.validate_attributes(allowed_attrs, user_data, "user") do
      :ok ->
        %UserDirective{
          name: user_data["name"],
          type: parse_user_type(user_data["type"]),
          email: user_data["email"] || "#{user_data["name"]}@test.edu",
          given_name: user_data["given_name"] || user_data["name"],
          family_name: user_data["family_name"] || "Test",
          password: user_data["password"],
          system_role: parse_system_role(user_data["system_role"]),
          can_create_sections: parse_can_create_sections(user_data["can_create_sections"]),
          email_verified: parse_email_verified(user_data["email_verified"])
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"enroll" => enroll_data}) do
    # Validate attributes
    allowed_attrs = ["user", "section", "role", "email"]

    case DirectiveValidator.validate_attributes(allowed_attrs, enroll_data, "enroll") do
      :ok ->
        %EnrollDirective{
          user: enroll_data["user"],
          section: enroll_data["section"],
          role: parse_enrollment_role(enroll_data["role"]),
          email: enroll_data["email"]
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
    allowed_attrs = [
      "project",
      "title",
      "virtual_id",
      "scope",
      "type",
      "content_format",
      "content",
      "objectives",
      "tags"
    ]

    case DirectiveValidator.validate_attributes(allowed_attrs, activity_data, "create_activity") do
      :ok ->
        %ActivityDirective{
          project: activity_data["project"],
          title: activity_data["title"],
          virtual_id: activity_data["virtual_id"],
          scope: activity_data["scope"] || "embedded",
          type: activity_data["type"],
          content_format: activity_data["content_format"] || "torusdoc",
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

  defp parse_directive(%{"visit_page" => visit_data}) do
    allowed_attrs = ["student", "section", "page"]

    case DirectiveValidator.validate_attributes(allowed_attrs, visit_data, "visit_page") do
      :ok ->
        %VisitPageDirective{
          student: visit_data["student"],
          section: visit_data["section"],
          page: visit_data["page"]
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"start_attempt" => start_data}) do
    allowed_attrs = ["student", "section", "page", "password", "expect"]

    case DirectiveValidator.validate_attributes(allowed_attrs, start_data, "start_attempt") do
      :ok ->
        %StartAttemptDirective{
          student: start_data["student"],
          section: start_data["section"],
          page: start_data["page"],
          password: start_data["password"],
          expect: parse_start_attempt_expectation(start_data["expect"])
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"gate" => gate_data}) do
    allowed_attrs = [
      "name",
      "section",
      "target",
      "type",
      "source",
      "start",
      "end",
      "minimum_percentage",
      "student",
      "parent",
      "graded_resource_policy"
    ]

    case DirectiveValidator.validate_attributes(allowed_attrs, gate_data, "gate") do
      :ok ->
        %GateDirective{
          name: gate_data["name"],
          section: gate_data["section"],
          target: gate_data["target"],
          type: parse_gate_type(gate_data["type"]),
          source: gate_data["source"],
          start: parse_optional_datetime(gate_data["start"]),
          end: parse_optional_datetime(gate_data["end"]),
          minimum_percentage: parse_optional_float(gate_data["minimum_percentage"]),
          student: gate_data["student"],
          parent: gate_data["parent"],
          graded_resource_policy: parse_optional_gate_policy(gate_data["graded_resource_policy"])
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"time" => time_data}) do
    allowed_attrs = ["at"]

    case DirectiveValidator.validate_attributes(allowed_attrs, time_data, "time") do
      :ok ->
        %TimeDirective{
          at: parse_required_datetime(time_data["at"], "time.at")
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

  defp parse_directive(%{"certificate" => certificate_data}) do
    allowed_attrs = ["target", "enabled", "thresholds", "design"]

    case DirectiveValidator.validate_attributes(allowed_attrs, certificate_data, "certificate") do
      :ok ->
        %CertificateDirective{
          target: certificate_data["target"],
          enabled: parse_boolean(certificate_data["enabled"], true, "enabled"),
          thresholds: parse_certificate_thresholds(certificate_data["thresholds"]),
          design: parse_certificate_design(certificate_data["design"])
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"discussion_post" => discussion_post_data}) do
    allowed_attrs = ["student", "section", "body"]

    case DirectiveValidator.validate_attributes(
           allowed_attrs,
           discussion_post_data,
           "discussion_post"
         ) do
      :ok ->
        %DiscussionPostDirective{
          student: discussion_post_data["student"],
          section: discussion_post_data["section"],
          body: discussion_post_data["body"]
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"class_note" => class_note_data}) do
    allowed_attrs = ["student", "section", "page", "body"]

    case DirectiveValidator.validate_attributes(allowed_attrs, class_note_data, "class_note") do
      :ok ->
        %ClassNoteDirective{
          student: class_note_data["student"],
          section: class_note_data["section"],
          page: class_note_data["page"],
          body: class_note_data["body"]
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"complete_scored_page" => complete_data}) do
    allowed_attrs = ["student", "section", "page", "score", "out_of"]

    case DirectiveValidator.validate_attributes(
           allowed_attrs,
           complete_data,
           "complete_scored_page"
         ) do
      :ok ->
        %CompleteScoredPageDirective{
          student: complete_data["student"],
          section: complete_data["section"],
          page: complete_data["page"],
          score: parse_float(complete_data["score"]),
          out_of: parse_float(complete_data["out_of"])
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"finalize_attempt" => finalize_data}) do
    allowed_attrs = ["student", "section", "page"]

    case DirectiveValidator.validate_attributes(
           allowed_attrs,
           finalize_data,
           "finalize_attempt"
         ) do
      :ok ->
        %FinalizeAttemptDirective{
          student: finalize_data["student"],
          section: finalize_data["section"],
          page: finalize_data["page"]
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"student_exception" => exception_data}) do
    allowed_attrs = ["action", "student", "section", "page", "set"]

    case DirectiveValidator.validate_attributes(
           allowed_attrs,
           exception_data,
           "student_exception"
         ) do
      :ok ->
        %StudentExceptionDirective{
          action: parse_student_exception_action(exception_data["action"]),
          student: exception_data["student"],
          section: exception_data["section"],
          page: exception_data["page"],
          set: parse_student_exception_settings(exception_data["set"])
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"certificate_action" => action_data}) do
    allowed_attrs = ["instructor", "section", "student", "action"]

    case DirectiveValidator.validate_attributes(
           allowed_attrs,
           action_data,
           "certificate_action"
         ) do
      :ok ->
        %CertificateActionDirective{
          instructor: action_data["instructor"],
          section: action_data["section"],
          student: action_data["student"],
          action: parse_certificate_action(action_data["action"])
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"collaborator" => collab_data}) do
    allowed_attrs = ["user", "project", "email"]

    case DirectiveValidator.validate_attributes(allowed_attrs, collab_data, "collaborator") do
      :ok ->
        %CollaboratorDirective{
          user: collab_data["user"],
          project: collab_data["project"],
          email: collab_data["email"]
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"media" => media_data}) do
    allowed_attrs = ["project", "path", "mime"]

    case DirectiveValidator.validate_attributes(allowed_attrs, media_data, "media") do
      :ok ->
        %MediaDirective{
          project: media_data["project"],
          path: media_data["path"],
          mime: media_data["mime"]
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_directive(%{"bibliography" => biblio_data}) do
    allowed_attrs = ["project", "entry"]

    case DirectiveValidator.validate_attributes(allowed_attrs, biblio_data, "bibliography") do
      :ok ->
        %BibliographyDirective{
          project: biblio_data["project"],
          entry: biblio_data["entry"]
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
         "visit_page",
         "start_attempt",
         "gate",
         "time",
         "answer_question",
         "finalize_attempt",
         "student_exception",
         "use",
         "collaborator",
         "media",
         "bibliography",
         "hook"
       ] do
      raise "Unrecognized directive: '#{key}'. Valid directives are: project, clone, section, product, remix, manipulate, publish, assert, verify, user, enroll, institution, update, customize, create_activity, edit_page, view_practice_page, visit_page, start_attempt, gate, time, answer_question, finalize_attempt, student_exception, use, collaborator, media, bibliography, hook"
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
             "visit_page",
             "start_attempt",
             "gate",
             "time",
             "answer_question",
             "finalize_attempt",
             "student_exception",
             "certificate",
             "discussion_post",
             "class_note",
             "complete_scored_page",
             "certificate_action",
             "update",
             "customize",
             "use",
             "collaborator",
             "media",
             "bibliography",
             "hook"
           ] ->
        [parse_directive(%{key => value})]

      {key, _value} ->
        raise "Unrecognized directive: '#{key}'. Valid directives are: project, clone, section, product, remix, manipulate, publish, assert, verify, user, enroll, institution, update, customize, create_activity, edit_page, view_practice_page, visit_page, start_attempt, gate, time, answer_question, finalize_attempt, student_exception, certificate, discussion_post, class_note, complete_scored_page, certificate_action, use, collaborator, media, bibliography, hook"
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

  defp parse_certificate_assertion(nil), do: nil

  defp parse_certificate_assertion(data) when is_map(data) do
    case DirectiveValidator.validate_assertion_attributes(:certificate, data) do
      :ok ->
        %{
          section: data["section"],
          student: data["student"],
          enabled: parse_optional_boolean(data["enabled"], "enabled"),
          state: parse_optional_certificate_state(data["state"]),
          with_distinction: parse_optional_boolean(data["with_distinction"], "with_distinction"),
          progress: parse_certificate_progress_assertion(data["progress"]),
          requires_instructor_approval:
            parse_optional_boolean(
              data["requires_instructor_approval"],
              "requires_instructor_approval"
            ),
          required_discussion_posts: parse_optional_integer(data["required_discussion_posts"]),
          required_class_notes: parse_optional_integer(data["required_class_notes"]),
          min_percentage_for_completion:
            parse_optional_float(data["min_percentage_for_completion"]),
          min_percentage_for_distinction:
            parse_optional_float(data["min_percentage_for_distinction"]),
          assessments_apply_to: parse_optional_string_or_atom(data["assessments_apply_to"]),
          scored_pages: data["scored_pages"],
          title: data["title"],
          description: data["description"],
          admin_name1: data["admin_name1"],
          admin_title1: data["admin_title1"],
          admin_name2: data["admin_name2"],
          admin_title2: data["admin_title2"],
          admin_name3: data["admin_name3"],
          admin_title3: data["admin_title3"]
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_gating_assertion(nil), do: nil

  defp parse_gating_assertion(data) when is_map(data) do
    case DirectiveValidator.validate_assertion_attributes(:gating, data) do
      :ok ->
        %{
          gate: data["gate"],
          section: data["section"],
          student: data["student"],
          resource: data["resource"],
          target: data["target"],
          source: data["source"],
          type: if(data["type"], do: parse_gate_type(data["type"]), else: nil),
          accessible: parse_optional_boolean(data["accessible"], "accessible"),
          blocking_types: parse_optional_gate_types(data["blocking_types"]),
          blocking_count: parse_optional_integer(data["blocking_count"]),
          minimum_percentage: parse_optional_float(data["minimum_percentage"]),
          start: parse_optional_datetime(data["start"]),
          end: parse_optional_datetime(data["end"])
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_prologue_assertion(nil), do: nil

  defp parse_prologue_assertion(data) when is_map(data) do
    case DirectiveValidator.validate_assertion_attributes(:prologue, data) do
      :ok ->
        %{
          section: data["section"],
          student: data["student"],
          page: data["page"],
          allow_attempt: parse_optional_boolean(data["allow_attempt"], "allow_attempt"),
          show_blocking_gates:
            parse_optional_boolean(data["show_blocking_gates"], "show_blocking_gates"),
          attempt_message: data["attempt_message"],
          attempts_taken: parse_optional_integer(data["attempts_taken"]),
          max_attempts: parse_optional_string_or_integer(data["max_attempts"]),
          attempts_summary: data["attempts_summary"],
          next_attempt_ordinal: data["next_attempt_ordinal"],
          terms: data["terms"] || %{}
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_gradebook_assertion(nil), do: nil

  defp parse_gradebook_assertion(data) when is_map(data) do
    case DirectiveValidator.validate_assertion_attributes(:gradebook, data) do
      :ok ->
        %{
          instructor: data["instructor"],
          section: data["section"],
          student: data["student"],
          page: data["page"],
          score: parse_optional_float(data["score"]),
          out_of: parse_optional_float(data["out_of"]),
          was_late: parse_optional_boolean(data["was_late"], "was_late")
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_review_attempt_assertion(nil), do: nil

  defp parse_review_attempt_assertion(data) when is_map(data) do
    case DirectiveValidator.validate_assertion_attributes(:review_attempt, data) do
      :ok ->
        %{
          section: data["section"],
          student: data["student"],
          page: data["page"],
          allow_review: parse_optional_boolean(data["allow_review"], "allow_review"),
          activities_visible:
            parse_optional_boolean(data["activities_visible"], "activities_visible"),
          answers_visible: parse_optional_boolean(data["answers_visible"], "answers_visible"),
          feedback_visible: parse_optional_boolean(data["feedback_visible"], "feedback_visible"),
          scores_visible: parse_optional_boolean(data["scores_visible"], "scores_visible"),
          activity_count: parse_optional_integer(data["activity_count"])
        }

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_activity_attempt_assertion(nil), do: nil

  defp parse_activity_attempt_assertion(data) when is_map(data) do
    case DirectiveValidator.validate_assertion_attributes(:activity_attempt, data) do
      :ok ->
        %{
          section: data["section"],
          student: data["student"],
          page: data["page"],
          activity_virtual_id: data["activity_virtual_id"],
          part_id: data["part_id"],
          activity_lifecycle_state:
            parse_optional_lifecycle_state(data["activity_lifecycle_state"]),
          part_lifecycle_state: parse_optional_lifecycle_state(data["part_lifecycle_state"]),
          score: parse_optional_float(data["score"]),
          out_of: parse_optional_float(data["out_of"]),
          part_score: parse_optional_float(data["part_score"]),
          part_out_of: parse_optional_float(data["part_out_of"]),
          response: data["response"],
          response_present: Map.has_key?(data, "response"),
          answerable: parse_optional_boolean(data["answerable"], "answerable")
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

      {:error, msg} ->
        raise msg
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

      {:error, msg} ->
        raise msg
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
  defp parse_visibility(nil), do: nil

  defp parse_visibility(value) when is_binary(value) do
    case String.downcase(String.trim(value)) do
      "authors" -> :authors
      "selected" -> :selected
      "global" -> :global
      other -> raise "Invalid visibility '#{other}'. Expected one of: authors, selected, global"
    end
  end

  defp parse_visibility(value) when is_atom(value) do
    case value do
      :authors ->
        :authors

      :selected ->
        :selected

      :global ->
        :global

      other ->
        raise "Invalid visibility #{inspect(other)}. Expected :authors, :selected, or :global"
    end
  end

  defp parse_visibility(value),
    do: raise("Invalid visibility value #{inspect(value)}. Expected string or atom")

  defp parse_section_type(nil), do: :enrollable
  defp parse_section_type("enrollable"), do: :enrollable
  defp parse_section_type("open_and_free"), do: :open_and_free
  defp parse_section_type(type) when is_atom(type), do: type

  defp parse_user_type(nil), do: :student
  defp parse_user_type("author"), do: :author
  defp parse_user_type("instructor"), do: :instructor
  defp parse_user_type("student"), do: :student
  defp parse_user_type(type) when is_atom(type), do: type

  defp parse_system_role(nil), do: :author
  defp parse_system_role(role) when is_atom(role), do: role

  defp parse_system_role(role) when is_binary(role) do
    normalized = String.trim(role)

    case normalized do
      "author" ->
        :author

      "system_admin" ->
        :system_admin

      "account_admin" ->
        :account_admin

      "content_admin" ->
        :content_admin

      other ->
        raise "Invalid system_role '#{other}' (allowed: author, system_admin, account_admin, content_admin)"
    end
  end

  defp parse_can_create_sections(value),
    do: parse_boolean(value, false, "can_create_sections")

  defp parse_email_verified(value),
    do: parse_boolean(value, true, "email_verified")

  defp parse_boolean(nil, default, _field), do: default
  defp parse_boolean(value, _default, _field) when is_boolean(value), do: value

  defp parse_boolean(value, _default, field) when is_binary(value) do
    case String.downcase(String.trim(value)) do
      "true" -> true
      "false" -> false
      other -> raise "Invalid boolean for #{field}: #{other}"
    end
  end

  defp parse_boolean(value, _default, _field) when is_integer(value), do: value != 0

  defp parse_boolean(value, _default, field),
    do: raise("Invalid boolean for #{field}: #{inspect(value)}")

  defp parse_enrollment_role(nil), do: :student
  defp parse_enrollment_role("instructor"), do: :instructor
  defp parse_enrollment_role("student"), do: :student
  defp parse_enrollment_role(role) when is_atom(role), do: role

  defp parse_start_attempt_expectation(nil), do: :started

  defp parse_start_attempt_expectation(value) when is_atom(value) do
    if value in start_attempt_expectations() do
      value
    else
      raise "Invalid start_attempt expectation #{inspect(value)}"
    end
  end

  defp parse_start_attempt_expectation(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.trim()
    |> String.to_atom()
    |> parse_start_attempt_expectation()
  end

  defp parse_start_attempt_expectation(value) do
    raise "Invalid start_attempt expectation #{inspect(value)}"
  end

  defp start_attempt_expectations do
    [
      :started,
      :password_required,
      :incorrect_password,
      :before_start_date,
      :active_attempt_present,
      :no_more_attempts,
      :end_date_passed
    ]
  end

  defp parse_student_exception_action(nil), do: :set
  defp parse_student_exception_action("set"), do: :set
  defp parse_student_exception_action("remove"), do: :remove
  defp parse_student_exception_action(action) when is_atom(action), do: action

  defp parse_student_exception_action(action) do
    raise "Invalid student_exception action #{inspect(action)}"
  end

  defp parse_student_exception_settings(nil), do: %{}

  defp parse_student_exception_settings(data) when is_map(data) do
    allowed_attrs = ["max_attempts", "time_limit", "end_date", "due_date", "late_policy"]

    case DirectiveValidator.validate_attributes(
           allowed_attrs,
           data,
           "student_exception.set"
         ) do
      :ok ->
        data
        |> Enum.map(fn
          {key, value} when key in ["max_attempts", "time_limit"] ->
            {String.to_atom(key), parse_optional_integer(value)}

          {key, value} when key in ["end_date", "due_date"] ->
            {String.to_atom(key), parse_optional_datetime(value)}

          {"late_policy", value} ->
            {:late_policy, parse_student_exception_late_policy(value)}
        end)
        |> Map.new()

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_student_exception_late_policy(value) when is_atom(value), do: value

  defp parse_student_exception_late_policy(value) when is_binary(value) do
    value
    |> parse_atom_literal()
    |> case do
      policy
      when policy in [
             :allow_late_start_and_late_submit,
             :allow_late_submit_but_not_late_start,
             :disallow_late_start_and_late_submit
           ] ->
        policy

      other ->
        raise "Invalid student_exception late_policy #{inspect(other)}"
    end
  end

  defp parse_float(nil), do: 0.0
  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value / 1.0

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> 0.0
    end
  end

  defp parse_optional_boolean(nil, _field), do: nil
  defp parse_optional_boolean(value, field), do: parse_boolean(value, false, field)

  defp parse_optional_integer(nil), do: nil
  defp parse_optional_integer(value) when is_integer(value), do: value

  defp parse_optional_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, _} -> integer
      :error -> raise "Invalid integer value #{inspect(value)}"
    end
  end

  defp parse_optional_float(nil), do: nil
  defp parse_optional_float(value), do: parse_float(value)

  defp parse_optional_lifecycle_state(nil), do: nil

  defp parse_optional_lifecycle_state(value) when is_atom(value),
    do: validate_lifecycle_state(value)

  defp parse_optional_lifecycle_state(value) when is_binary(value) do
    value
    |> String.to_atom()
    |> validate_lifecycle_state()
  end

  defp validate_lifecycle_state(value)
       when value in [:active, :evaluated, :submitted],
       do: value

  defp validate_lifecycle_state(value), do: raise("Invalid lifecycle_state #{inspect(value)}")

  defp parse_required_datetime(nil, field),
    do: raise("Missing required datetime for #{field}")

  defp parse_required_datetime(value, _field), do: parse_datetime(value)

  defp parse_optional_datetime(nil), do: nil
  defp parse_optional_datetime(value), do: parse_datetime(value)

  defp parse_datetime(%DateTime{} = value), do: value

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, reason} -> raise "Invalid datetime #{inspect(value)}: #{inspect(reason)}"
    end
  end

  defp parse_datetime(value),
    do: raise("Invalid datetime value #{inspect(value)}")

  defp parse_atom_literal(value) when is_binary(value) do
    if String.starts_with?(value, "@atom(") do
      value
      |> String.trim_leading("@atom(")
      |> String.trim_trailing(")")
      |> String.to_atom()
    else
      String.to_atom(value)
    end
  end

  defp parse_optional_string_or_atom(nil), do: nil
  defp parse_optional_string_or_atom(value) when is_binary(value), do: value
  defp parse_optional_string_or_atom(value) when is_atom(value), do: Atom.to_string(value)

  defp parse_optional_string_or_integer(nil), do: nil
  defp parse_optional_string_or_integer(value) when is_integer(value), do: value
  defp parse_optional_string_or_integer(value) when is_binary(value), do: value

  defp parse_gate_type(nil), do: raise("gate requires a type")

  defp parse_gate_type(value) when is_atom(value) do
    case value do
      type when type in [:schedule, :always_open, :started, :finished, :progress] -> type
      other -> raise "Invalid gate type #{inspect(other)}"
    end
  end

  defp parse_gate_type(value) when is_binary(value) do
    case String.downcase(String.trim(value)) do
      "schedule" -> :schedule
      "always_open" -> :always_open
      "alwaysopen" -> :always_open
      "started" -> :started
      "finished" -> :finished
      "progress" -> :progress
      other -> raise "Invalid gate type '#{other}'"
    end
  end

  defp parse_optional_gate_policy(nil), do: nil

  defp parse_optional_gate_policy(value) when is_atom(value) do
    case value do
      policy when policy in [:allows_nothing, :allows_review] -> policy
      other -> raise "Invalid graded_resource_policy #{inspect(other)}"
    end
  end

  defp parse_optional_gate_policy(value) when is_binary(value) do
    case String.downcase(String.trim(value)) do
      "allows_nothing" -> :allows_nothing
      "allows_review" -> :allows_review
      other -> raise "Invalid graded_resource_policy '#{other}'"
    end
  end

  defp parse_optional_gate_types(nil), do: nil

  defp parse_optional_gate_types(values) when is_list(values) do
    Enum.map(values, &parse_gate_type/1)
  end

  defp parse_optional_certificate_state(nil), do: nil

  defp parse_optional_certificate_state(value) when is_binary(value) do
    case String.downcase(String.trim(value)) do
      "none" -> :none
      "pending" -> :pending
      "earned" -> :earned
      "denied" -> :denied
      other -> raise "Invalid certificate state '#{other}'"
    end
  end

  defp parse_certificate_action(nil), do: raise("certificate_action requires an action")

  defp parse_certificate_action(value) when is_binary(value) do
    case String.downcase(String.trim(value)) do
      "approve" -> :approve
      "deny" -> :deny
      other -> raise "Invalid certificate action '#{other}'. Expected approve or deny"
    end
  end

  defp parse_certificate_thresholds(nil), do: %{}

  defp parse_certificate_thresholds(data) when is_map(data) do
    allowed_attrs = [
      "required_discussion_posts",
      "required_class_notes",
      "min_percentage_for_completion",
      "min_percentage_for_distinction",
      "assessments_apply_to",
      "scored_pages",
      "requires_instructor_approval"
    ]

    case DirectiveValidator.validate_attributes(
           allowed_attrs,
           data,
           "certificate thresholds"
         ) do
      :ok ->
        %{
          required_discussion_posts: parse_optional_integer(data["required_discussion_posts"]),
          required_class_notes: parse_optional_integer(data["required_class_notes"]),
          min_percentage_for_completion:
            parse_optional_float(data["min_percentage_for_completion"]),
          min_percentage_for_distinction:
            parse_optional_float(data["min_percentage_for_distinction"]),
          assessments_apply_to: parse_optional_string_or_atom(data["assessments_apply_to"]),
          scored_pages: data["scored_pages"],
          requires_instructor_approval:
            parse_optional_boolean(
              data["requires_instructor_approval"],
              "requires_instructor_approval"
            )
        }
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_certificate_design(nil), do: %{}

  defp parse_certificate_design(data) when is_map(data) do
    allowed_attrs = [
      "title",
      "description",
      "admin_name1",
      "admin_title1",
      "admin_name2",
      "admin_title2",
      "admin_name3",
      "admin_title3"
    ]

    case DirectiveValidator.validate_attributes(allowed_attrs, data, "certificate design") do
      :ok ->
        data
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_certificate_progress_assertion(nil), do: nil

  defp parse_certificate_progress_assertion(data) when is_map(data) do
    allowed_attrs = ["discussion_posts", "class_notes", "required_assignments"]

    case DirectiveValidator.validate_attributes(
           allowed_attrs,
           data,
           "certificate progress assertion"
         ) do
      :ok ->
        %{
          discussion_posts: parse_progress_count_spec(data["discussion_posts"]),
          class_notes: parse_progress_count_spec(data["class_notes"]),
          required_assignments: parse_progress_count_spec(data["required_assignments"])
        }
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()

      {:error, msg} ->
        raise msg
    end
  end

  defp parse_progress_count_spec(nil), do: nil

  defp parse_progress_count_spec(data) when is_map(data) do
    allowed_attrs = ["completed", "total"]

    case DirectiveValidator.validate_attributes(
           allowed_attrs,
           data,
           "certificate progress count"
         ) do
      :ok ->
        %{
          completed: parse_optional_integer(data["completed"]),
          total: parse_optional_integer(data["total"])
        }

      {:error, msg} ->
        raise msg
    end
  end
end
