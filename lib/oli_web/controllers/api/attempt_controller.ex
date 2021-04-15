defmodule OliWeb.Api.AttemptController do
  use OliWeb, :controller
  use OpenApiSpex.Controller

  alias Oli.Delivery.Attempts
  alias Oli.Delivery.Attempts.StudentInput
  alias Oli.Delivery.Attempts.ClientEvaluation
  alias OpenApiSpex.Schema

  @moduledoc tags: ["User State Service: Intrinsic State"]

  defmodule UserStateUpdateResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Response from updating user state",
      description: "The server response for a successful user state update",
      type: :object,
      properties: %{
        result: %Schema{type: :string, description: "Success"}
      },
      required: [:result],
      example: %{
        "result" => "success"
      }
    })
  end

  defmodule NewActivityAttemptResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Response from creating a new activity attempt",
      description:
        "The server has created a new activity attempt and is delivering its new state and model to the client",
      type: :object,
      properties: %{
        result: %Schema{type: :string, description: "Success"},
        attemptState: %Schema{
          type: :object,
          description: "The activity attempt state for the new attempt"
        },
        model: %Schema{
          type: :string,
          description: "The transformed activity model for the new attempt"
        }
      },
      required: [:result, :attemptState, :model],
      example: %{
        "result" => "success",
        "attemptState" => %{},
        "model" => %{"stem" => "What is 3 + 4?"}
      }
    })
  end

  defmodule HintResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Response from updating user state",
      description: "The server response for a successful user state update",
      type: :object,
      properties: %{
        result: %Schema{type: :string, description: "Success"},
        hasMoreHints: %Schema{
          type: :boolean,
          description: "Whether or not there are more hints beyond this one"
        },
        hint: %Schema{type: :object, description: "The hint structured content"}
      },
      required: [:result, :hasMoreHints, :hint],
      example: %{
        "result" => "success",
        "hasMoreHints" => false,
        "hint" => %{
          "content" => [
            %{"type" => "p", "children" => [%{"text" => "Reread the course material"}]}
          ]
        }
      }
    })
  end

  defmodule EvaluationResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Response from updating user state",
      description: "The server response for a successful user state update",
      type: :object,
      properties: %{
        result: %Schema{type: :string, description: "Success"},
        actions: %Schema{
          type: :list,
          description: "The collection of actions as a result of the evaluation"
        }
      },
      required: [:result],
      example: %{
        "result" => "success",
        "actions" => [
          %{"type" => "ShowFeedbackAction", "feedback" => "Correct", "score" => 1, "outOf" => 1}
        ]
      }
    })
  end

  defmodule UserStateUpdateBody do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "User state",
      description: "The request body representing a student's state for a part or attempt",
      type: :object,
      properties: %{
        response: %Schema{
          type: :object,
          description: "JSON object representing the users state"
        }
      },
      required: [:response],
      example: %{
        "response" => %{"selected" => "A"}
      }
    })
  end

  defmodule ActivityEvaluationBody do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Activity driven evaluation body",
      description: "Activity driven evaluation parameters",
      type: :object,
      properties: %{
        evaluations: %Schema{
          type: :list,
          description: "Collection of evaluation results, one per part in the activity"
        }
      },
      required: [:evaluations],
      example: %{
        "evaluations" => [
          %{
            "attemptGuid" => "part1_guid",
            "response" => "A",
            "score" => 0,
            "outOf" => 1,
            "feedback" => "Wrong"
          }
        ]
      }
    })
  end

  defmodule ActivityAttemptBody do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "User state",
      description: "The state to save or evaluate for all parts for the activity",
      type: :object,
      properties: %{
        partInputs: %Schema{
          type: :list,
          description: "Collection of part inputs, one for each part present in the activity"
        }
      },
      required: [:partInputs],
      example: %{
        "partInputs" => [
          %{
            "attemptGuid" => "part1_guid",
            "response" => "A"
          },
          %{
            "attemptGuid" => "part2_guid",
            "response" => "B"
          }
        ]
      }
    })
  end

  @activity_attempt_parameters [
    section_slug: [
      in: :url,
      schema: %OpenApiSpex.Schema{type: :string},
      required: true,
      description: "The course section identifier"
    ],
    activity_attempt_guid: [
      in: :url,
      schema: %OpenApiSpex.Schema{type: :string},
      required: true,
      description: "The activity attempt identifier"
    ]
  ]

  @part_attempt_parameters @activity_attempt_parameters ++
                             [
                               part_attempt_guid: [
                                 in: :url,
                                 schema: %OpenApiSpex.Schema{type: :string},
                                 required: true,
                                 description: "The part attempt identifier"
                               ]
                             ]

  @doc """
  Saves user state for a specific part attempt.

  """
  @doc parameters: @part_attempt_parameters,
       request_body: {"User state", "application/json", UserStateUpdateBody, required: true},
       responses: %{
         200 => {"Update Response", "application/json", UserStateUpdateResponse}
       }
  def save_part(conn, %{
        "activity_attempt_guid" => _attempt_guid,
        "part_attempt_guid" => part_attempt_guid,
        "response" => response
      }) do
    case Attempts.save_student_input([%{attempt_guid: part_attempt_guid, response: response}]) do
      {:ok, _} -> json(conn, %{"type" => "success"})
      {:error, _} -> error(conn, 500, "server error")
    end
  end

  @doc """
  Submit user state for server-side evaluation for a single part.

  If this evaluation completes the activity attempt, a rolled up score will be calculdated
  across all parts and captured in the activity attempt, thus finalizing the activity
  attempt.

  """
  @doc parameters: @part_attempt_parameters,
       request_body: {"User state", "application/json", UserStateUpdateBody, required: true},
       responses: %{
         200 => {"Evaluation response", "application/json", EvaluationResponse}
       }
  def submit_part(conn, %{
        "section_slug" => section_slug,
        "activity_attempt_guid" => activity_attempt_guid,
        "part_attempt_guid" => attempt_guid,
        "input" => input
      }) do
    case Attempts.submit_part_evaluations(section_slug, activity_attempt_guid, [
           %{attempt_guid: attempt_guid, input: input}
         ]) do
      {:ok, evaluations} -> json(conn, %{"type" => "success", "actions" => evaluations})
      {:error, _} -> error(conn, 500, "server error")
    end
  end

  @doc """
  Requests a new attempt for a specific part of an activity. NOT IMPLEMENTED.
  """
  @doc parameters: @part_attempt_parameters,
       request_body: {"User state", "application/json", UserStateUpdateBody, required: true},
       responses: %{
         200 => {"Evaluation response", "application/json", UserStateUpdateResponse}
       }
  def new_part(conn, %{"activity_attempt_guid" => _, "part_attempt_guid" => _attempt_guid}) do
    json(conn, %{"type" => "success"})
  end

  @doc """
  Requests a new hint for a specific part attempt.

  """
  @doc parameters: @part_attempt_parameters,
       responses: %{
         200 => {"Evaluation response", "application/json", HintResponse}
       }
  def get_hint(conn, %{
        "activity_attempt_guid" => activity_attempt_guid,
        "part_attempt_guid" => part_attempt_guid
      }) do
    case Attempts.request_hint(activity_attempt_guid, part_attempt_guid) do
      {:ok, {hint, has_more_hints}} ->
        json(conn, %{"type" => "success", "hint" => hint, "hasMoreHints" => has_more_hints})

      {:error, {:not_found}} ->
        error(conn, 404, "not found")

      {:error, {:no_more_hints}} ->
        json(conn, %{"type" => "success", "hasMoreHints" => false})

      {:error, _} ->
        error(conn, 500, "server error")
    end
  end

  @doc """
  Saves user state for all parts for a specific activity attempt.

  """
  @doc parameters: @activity_attempt_parameters,
       request_body: {"User state", "application/json", ActivityAttemptBody, required: true},
       responses: %{
         200 => {"Update Response", "application/json", UserStateUpdateResponse}
       }
  def save_activity(conn, %{"activity_attempt_guid" => _attempt_guid, "partInputs" => part_inputs}) do
    parsed =
      Enum.map(part_inputs, fn %{"attemptGuid" => attempt_guid, "response" => response} ->
        %{attempt_guid: attempt_guid, response: response}
      end)

    case Attempts.save_student_input(parsed) do
      {:ok, _} -> json(conn, %{"type" => "success"})
      {:error, _} -> error(conn, 500, "server error")
    end
  end

  @doc """
  Evaluates user state for all parts for a specific activity attempt.

  """
  @doc parameters: @activity_attempt_parameters,
       request_body: {"User state", "application/json", ActivityAttemptBody, required: true},
       responses: %{
         200 => {"Update Response", "application/json", EvaluationResponse}
       }
  def submit_activity(conn, %{
        "section_slug" => section_slug,
        "activity_attempt_guid" => activity_attempt_guid,
        "partInputs" => part_inputs
      }) do
    parsed =
      Enum.map(part_inputs, fn %{"attemptGuid" => attempt_guid, "response" => input} ->
        %{attempt_guid: attempt_guid, input: %StudentInput{input: Map.get(input, "input")}}
      end)

    case Attempts.submit_part_evaluations(section_slug, activity_attempt_guid, parsed) do
      {:ok, evaluations} ->
        json(conn, %{"type" => "success", "actions" => evaluations})

      {:error, _} ->
        error(conn, 500, "server error")
    end
  end

  @doc """
  Finalizes an activity attempt from the result of an activity driven evaluation.
  """
  @doc parameters: @activity_attempt_parameters,
       request_body:
         {"Activity driven evaluation body", "application/json", ActivityEvaluationBody,
          required: true},
       responses: %{
         200 => {"Evaluation Response", "application/json", EvaluationResponse}
       }
  def submit_evaluations(conn, %{
        "section_slug" => section_slug,
        "activity_attempt_guid" => activity_attempt_guid,
        "evaluations" => client_evaluations
      }) do
    client_evaluations =
      Enum.map(client_evaluations, fn %{
                                        "attemptGuid" => attempt_guid,
                                        "response" => response,
                                        "score" => score,
                                        "outOf" => out_of,
                                        "feedback" => feedback
                                      } ->
        %{
          attempt_guid: attempt_guid,
          client_evaluation: %ClientEvaluation{
            input: %StudentInput{
              input: Map.get(response, "input")
            },
            score: score,
            out_of: out_of,
            feedback: feedback
          }
        }
      end)

    case Attempts.submit_client_evaluations(
           section_slug,
           activity_attempt_guid,
           client_evaluations
         ) do
      {:ok, evaluations} -> json(conn, %{"type" => "success", "actions" => evaluations})
      {:error, _} -> error(conn, 500, "server error")
    end
  end

  @doc """
  Creates a new attempt for an activity.
  """
  @doc parameters: @activity_attempt_parameters,
       responses: %{
         200 => {"New Attempt Response", "application/json", NewActivityAttemptResponse}
       }
  def new_activity(conn, %{
        "section_slug" => section_slug,
        "activity_attempt_guid" => activity_attempt_guid
      }) do
    case Attempts.reset_activity(section_slug, activity_attempt_guid) do
      {:ok, {attempt_state, model}} ->
        json(conn, %{"type" => "success", "attemptState" => attempt_state, "model" => model})

      {:error, _} ->
        error(conn, 500, "server error")
    end
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end
end
