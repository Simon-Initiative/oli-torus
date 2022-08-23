defmodule OliWeb.Api.AutomationSetupController do
  use OliWeb, :controller
  use OpenApiSpex.Controller
  import OliWeb.Api.Helpers
  alias Oli.AutomationSetup

  @moduledoc tags: ["Automated Test Data Setup Service"]

  alias OpenApiSpex.Schema

  plug Oli.Plugs.ValidateAPIKey, &Oli.Interop.validate_for_automation_setup/1

  defmodule AutomationSetupResponse do
    require OpenApiSpex

    authSchema = %Schema{
      type: :object,
      properties: %{
        id: %Schema{type: :number, description: "User ID"},
        email: %Schema{type: :string, description: "Email"},
        password: %Schema{type: :string, description: "Password"}
      }
    }

    OpenApiSpex.schema(%{
      title: "Automated Test Data setup response",
      description: "The response for an automation test setup operation",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean, description: true},
        author: authSchema,
        educator: authSchema,
        learner: authSchema,
        project: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :number},
            slug: %Schema{type: :string},
            title: %Schema{type: :string}
          }
        },
        section: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :number},
            slug: %Schema{type: :string}
          }
        }
      },
      required: [:success],
      example: %{
        author: %{
          email: "author-e2e-test-1651784090140222300@argos.test",
          id: 71,
          password: "qluaro51s5xp_1_a8t4e"
        },
        educator: %{
          email: "educator-e2e-test-1651784090795089200@argos.test",
          id: 73,
          password: "dpzxm4vdtca_w8$$gq@j"
        },
        learner: %{
          email: "learner-e2e-test-1651784091259636700@argos.test",
          id: 74,
          password: "d_#syfiws!vb1nhai@35"
        },
        project: %{
          id: 36,
          slug: "cc_balancing_chemical_reaction_ntt7v",
          title: "CC: Balancing Chemical Reactions 95858"
        },
        section: %{
          id: 18,
          slug: "automation_test_section_z9bc2"
        },
        success: true
      }
    })
  end

  defmodule AutomationTeardownBody do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Automated test data teardown",
      type: :object,
      properties: %{
        author_email: %Schema{type: :string},
        author_password: %Schema{type: :string},
        educator_email: %Schema{type: :string},
        educator_password: %Schema{type: :string},
        learner_email: %Schema{type: :string},
        learner_password: %Schema{type: :string},
        section_slug: %Schema{type: :string},
        project_slug: %Schema{type: :string}
      }
    })
  end

  defmodule AutomationTeardownResponse do
    require OpenApiSpex

    teardown_response = %Schema{
      oneOf: [
        %Schema{
          type: :object,
          properties: %{
            success: true
          }
        },
        %Schema{
          type: :object,
          properties: %{
            success: false,
            message: %Schema{type: :string}
          }
        }
      ]
    }

    OpenApiSpex.schema(%{
      title: "Automated test data teardown",
      type: :object,
      properties: %{
        author_deleted: teardown_response,
        educator_deleted: teardown_response,
        learner_deleted: teardown_response,
        section_deleted: teardown_response,
        project_deleted: teardown_response
      },
      example: %{
        author_deleted: %{
          success: true
        },
        educator_deleted: %{
          success: true
        },
        learner_deleted: %{
          success: true
        },
        project_deleted: %{
          success: true
        },
        section_deleted: %{
          success: true
        }
      }
    })
  end

  defmodule AutomationSetupBody do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Automated test data setup body",
      description: """
        The request body for setting data suitable for an automated test.
        If you provide a projectArchive
          - An author account is created.
          - Archive is ingested and a project is created for that author.
        If createSection is set:
          - The project is published (if projectArchive was set)
          - An educator account is created
          - The educator account is linked to the author (if projectArchive was set)
          - A section is created for that educator
            - With the project created set (if projectArchive was set)
        If createLearner is set:
          - A learner account is created
          - It's enrolled in the section (if it was created)
      """,
      type: :object,
      properties: %{
        project_archive: %Schema{
          type: :file,
          description: "Zip file containing a project export"
        },
        create_author: %Schema{
          type: :boolean,
          description: "Should an author account be created?"
        },
        create_section: %Schema{
          type: :boolean,
          description: "Should a section be set up that teaches this project?"
        },
        create_learner: %Schema{
          type: :boolean,
          description: "Should a learner be created?"
        },
        create_educator: %Schema{
          type: :boolean,
          description: "Should an educator account be created? Required if createSection is true"
        }
      },
      required: []
    })
  end

  @doc parameters: [],
       security: [%{"bearer-authorization" => []}],
       request_body:
         {"Setup Request", "multipart/form-data",
          OliWeb.Api.AutomationSetupController.AutomationSetupBody, required: true},
       responses: %{
         200 =>
           {"Setup Response", "application/json",
            OliWeb.Api.AutomationSetupController.AutomationSetupResponse}
       }
  def setup(conn, %{
        "create_author" => create_author,
        "create_learner" => create_learner,
        "create_section" => create_section,
        "create_educator" => create_educator,
        "project_archive" => project_archive
      }) do
    case setup_data(
           project_archive,
           create_learner,
           create_educator,
           create_author,
           create_section
         ) do
      {:error, reason, _, _} ->
        error(conn, 400, "Could not create #{Atom.to_string(reason)}")

      {:ok, author, author_password, educator, educator_password, learner, learner_password,
       project, section} ->
        json(
          conn,
          %{
            author: format_user(author, author_password),
            educator: format_user(educator, educator_password),
            learner: format_user(learner, learner_password),
            project: format_project(project),
            section: format_section(section),
            success: true
          }
        )
    end
  end

  @doc parameters: [],
       security: [%{"bearer-authorization" => []}],
       request_body:
         {"Teardown Request", "application/json",
          OliWeb.Api.AutomationSetupController.AutomationTeardownBody, required: true},
       responses: %{
         200 =>
           {"Teardown Response", "application/json",
            OliWeb.Api.AutomationSetupController.AutomationTeardownResponse}
       }
  def teardown(conn, %{
        "author_email" => author_email,
        "author_password" => author_password,
        "educator_email" => educator_email,
        "educator_password" => educator_password,
        "learner_email" => learner_email,
        "learner_password" => learner_password,
        "section_slug" => section_slug,
        "project_slug" => project_slug
      }) do
    # The order these happen in matters
    author_deleted = AutomationSetup.teardown_author(author_email, author_password)
    educator_deleted = AutomationSetup.teardown_educator(educator_email, educator_password)
    learner_deleted = AutomationSetup.teardown_learner(learner_email, learner_password)
    section_deleted = AutomationSetup.teardown_section(section_slug)
    project_deleted = AutomationSetup.teardown_project(project_slug)

    json(conn, %{
      author_deleted: author_deleted,
      educator_deleted: educator_deleted,
      learner_deleted: learner_deleted,
      section_deleted: section_deleted,
      project_deleted: project_deleted
    })
  end

  defp format_project(project) do
    %{
      slug: project.slug,
      title: project.title,
      id: project.id
    }
  end

  defp format_section(nil) do
    nil
  end

  defp format_section(section) do
    %{
      slug: section.slug,
      id: section.id
    }
  end

  defp format_user(nil, _) do
    nil
  end

  defp format_user(user, password) do
    %{
      email: user.email,
      password: password,
      id: user.id
    }
  end

  defp setup_data(
         project_archive,
         create_learner,
         create_educator,
         create_author,
         create_section
       ) do
    AutomationSetup.setup_data(
      file_path(project_archive),
      create_learner == "true",
      create_educator == "true",
      create_author == "true",
      create_section == "true"
    )
  end

  defp file_path(""), do: nil
  defp file_path(upload), do: upload.path
end
