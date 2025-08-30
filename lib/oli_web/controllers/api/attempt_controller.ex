defmodule OliWeb.Api.AttemptController do
  use OliWeb, :controller
  use OpenApiSpex.Controller

  alias Oli.Delivery.Attempts.ActivityLifecycle, as: Activity
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate, as: ActivityEvaluation
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Delivery.Attempts.Core.ClientEvaluation
  alias Oli.Conversation.Triggers
  alias Oli.Conversation.Trigger
  alias OpenApiSpex.Schema

  require Logger

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

  defmodule BulkAttemptRetrievalResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Response from requesting a collection of activity attempts",
      description:
        "The response from a client request for many activity attempts, based off of activity attempt guids",
      type: :object,
      properties: %{
        result: %Schema{type: :string, description: "Success"},
        activityAttempts: %Schema{
          type: :list,
          description: "The activity attempts for the requested guids"
        }
      },
      required: [:result, :activityAttempts],
      example: %{
        "result" => "success",
        "activityAttempts" => [
          %{
            "attemptGuid" => "20595ef0-e5f1-474e-880d-f2c20f3a4459",
            "score" => 1,
            "outOf" => 2,
            "partAttempts" => [
              %{
                "attemptGuid" => "d25f8881-9a4b-4e73-9998-e7de3b3e7485",
                "partId" => "1",
                "score" => 1,
                "outOf" => 2,
                "feedback" => %{
                  "content" => "Partially correct."
                },
                "response" => %{
                  "input" => "A"
                }
              }
            ]
          },
          %{
            "attemptGuid" => "30b59817-e193-488f-94b1-597420b8670e",
            "score" => nil,
            "outOf" => nil,
            "partAttempts" => [
              %{
                "attemptGuid" => "7e1d90ef-0e75-4558-8266-5838f3aea2f3",
                "partId" => "1",
                "score" => nil,
                "outOf" => nil,
                "feedback" => nil,
                "response" => %{
                  "input" => "A"
                }
              }
            ]
          }
        ]
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

  defmodule BulkAttemptRequestBody do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Activity attempt bulk request body",
      description:
        "The collection of activity attempts guids to retrieve activity attempt records from",
      type: :object,
      properties: %{
        attemptGuids: %Schema{
          type: :list,
          description: "Collection of activity attempt guids"
        }
      },
      required: [:evaluations],
      example: %{
        "attemptGuids" => [
          "20595ef0-e5f1-474e-880d-f2c20f3a4459",
          "30b59817-e193-488f-94b1-597420b8670e"
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

  @doc """
  Retrieves a collection of activity attempt records for a collection of activity attempt guids.
  """
  @doc parameters: [
         section_slug: [
           in: :url,
           schema: %OpenApiSpex.Schema{type: :string},
           required: true,
           description: "The course section identifier"
         ]
       ],
       request_body:
         {"Bulk Attempt Body", "application/json", BulkAttemptRequestBody, required: true},
       responses: %{
         200 => {"Bulk Attempt Response", "application/json", BulkAttemptRetrievalResponse}
       }
  def bulk_retrieve(conn, %{
        "attemptGuids" => attempt_guids
      }) do
    case Attempts.get_activity_attempts(attempt_guids) do
      {:ok, attempts} ->
        attempts = Enum.map(attempts, &to_client_view/1)
        json(conn, %{"result" => "success", "activityAttempts" => attempts})
    end
  end

  defp to_client_view(attempt) do
    latest_part_attempt_by_part =
      Enum.reduce(attempt.part_attempts, %{}, fn p, m ->
        case Map.get(m, p.part_id) do
          nil ->
            Map.put(m, p.part_id, p)

          pa ->
            if Date.compare(pa.inserted_at, p.inserted_at) == :gt do
              Map.put(m, p.part_id, pa)
            else
              Map.put(m, p.part_id, p)
            end
        end
      end)

    %{
      activityId: attempt.resource_id,
      activityType: attempt.revision.activity_type_id,
      revisionId: attempt.revision_id,
      attemptGuid: attempt.attempt_guid,
      attemptNumber: attempt.attempt_number,
      score: attempt.score,
      outOf: attempt.out_of,
      dateEvaluated: attempt.date_evaluated,
      model: Attempts.select_model(attempt) |> Oli.Delivery.Page.ModelPruner.prune(),
      partAttempts:
        Map.values(latest_part_attempt_by_part)
        |> Enum.map(fn pa ->
          %{
            partId: pa.part_id,
            attemptGuid: pa.attempt_guid,
            attemptNumber: pa.attempt_number,
            dateEvaluated: pa.date_evaluated,
            score: pa.score,
            outOf: pa.out_of,
            response: pa.response,
            feedback: pa.feedback
          }
        end)
    }
  end

  def get_activity_attempt(conn, %{
        "activity_attempt_guid" => attempt_guid
      }) do
    case Attempts.get_activity_attempts([attempt_guid]) do
      {:ok, [attempt]} ->
        model = Oli.Delivery.Attempts.Core.select_model(attempt)

        resource_attempt =
          Oli.Delivery.Attempts.Core.get_resource_attempt_and_revision(
            attempt.resource_attempt_id
          )

        effective_settings = Oli.Delivery.Settings.get_combined_settings(resource_attempt)

        {:ok, parsed_model} = Oli.Activities.Model.parse(model)

        state =
          Oli.Activities.State.ActivityState.from_attempt(
            attempt,
            Attempts.get_latest_part_attempts(attempt.attempt_guid),
            parsed_model,
            nil,
            nil,
            effective_settings
          )

        json(conn, %{
          "result" => "success",
          "state" => state,
          "model" => Map.delete(model, "authoring")
        })
    end
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
    case Activity.save_student_input([
           %{attempt_guid: part_attempt_guid, response: response}
         ]) do
      {:ok, _} ->
        json(conn, %{"type" => "success"})

      {:error, _e} ->
        {_, msg} = Oli.Utils.log_error("Could not save part", e)
        error(conn, 500, msg)
    end
  end

  @doc """
  Saves user state for a specific part attempt on a basic page. This will only save the state
  for active part attempts.
  """
  @doc parameters: @part_attempt_parameters,
       request_body: {"User state", "application/json", UserStateUpdateBody, required: true},
       responses: %{
         200 => {"Update Response", "application/json", UserStateUpdateResponse}
       }
  def save_active_part(conn, %{
        "activity_attempt_guid" => _attempt_guid,
        "part_attempt_guid" => part_attempt_guid,
        "response" => response
      }) do
    case Activity.save_student_input(
           [
             %{attempt_guid: part_attempt_guid, response: response}
           ],
           only_active: true
         ) do
      {:ok, _} ->
        json(conn, %{"type" => "success"})

      {:error, :already_submitted} ->
        conn
        |> put_status(403)
        |> json(%{
          "error" => true,
          "message" =>
            "These changes could not be saved as this attempt may have already been submitted"
        })

      {:error, _e} ->
        {_, msg} = Oli.Utils.log_error("Could not save part", e)
        error(conn, 500, msg)
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
        "response" => input
      }) do
    datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)

    case ActivityEvaluation.evaluate_from_input(
           section_slug,
           activity_attempt_guid,
           [
             %{
               attempt_guid: attempt_guid,
               input: %StudentInput{
                 files: Map.get(input, "files", []),
                 input: Map.get(input, "input")
               }
             }
           ],
           datashop_session_id
         ) do
      {:ok, evaluations} ->
        maybe_fire_trigger(
          section_slug,
          Plug.Conn.get_session(conn, :current_user_id),
          evaluations
        )

        json(conn, %{"type" => "success", "actions" => evaluations})

      {:error, _e} ->
        {_, msg} = Oli.Utils.log_error("Could not submit part", e)
        error(conn, 500, msg)
    end
  end

  defp maybe_fire_trigger(_section_slug, _user_id, []), do: :ok
  defp maybe_fire_trigger(_section_slug, _user_id, nil), do: :ok

  defp maybe_fire_trigger(section_slug, user_id, %Trigger{} = trigger) do
    Task.start(fn -> Triggers.possibly_invoke_trigger(section_slug, user_id, trigger) end)
  end

  defp maybe_fire_trigger(section_slug, user_id, evaluations) when is_list(evaluations) do
    # Find the first trigger, as we never want to invoke multiple triggers from a single action.
    #
    # But do all of this in the most robust way possible, including invoking the trigger
    # in a Task so we don't block the response, and if we encounter an error, we don't
    # want to crash the request

    try do
      case Enum.map(evaluations, fn evaluation -> Map.get(evaluation, :trigger, nil) end)
           |> Enum.filter(fn trigger -> !is_nil(trigger) end) do
        [] -> :ok
        [trigger | _] -> maybe_fire_trigger(section_slug, user_id, trigger)
      end
    rescue
      e ->
        Logger.error("Could not fire trigger for evaluations: #{inspect(e)}")
        :ok
    end
  end

  defp maybe_fire_trigger(_section_slug, _user_id, _other), do: :ok

  @doc """
  Requests a new attempt for a specific part of an activity. NOT IMPLEMENTED.
  """
  @doc parameters: @part_attempt_parameters,
       request_body: {"User state", "application/json", UserStateUpdateBody, required: true},
       responses: %{
         200 => {"Evaluation response", "application/json", UserStateUpdateResponse}
       }
  def new_part(conn, %{
        "activity_attempt_guid" => activity_attempt_guid,
        "part_attempt_guid" => part_attempt_guid
      }) do
    datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)

    case Activity.reset_part(activity_attempt_guid, part_attempt_guid, datashop_session_id) do
      {:ok, attempt_state} ->
        json(conn, %{"type" => "success", "attemptState" => attempt_state})

      {:error, _e} ->
        {_, msg} = Oli.Utils.log_error("Could not reset part", e)
        error(conn, 500, msg)
    end
  end

  @doc """
  Requests a new hint for a specific part attempt.

  """
  @doc parameters: @part_attempt_parameters,
       responses: %{
         200 => {"Evaluation response", "application/json", HintResponse}
       }
  def get_hint(conn, %{
        "section_slug" => section_slug,
        "activity_attempt_guid" => activity_attempt_guid,
        "part_attempt_guid" => part_attempt_guid
      }) do
    case Activity.request_hint(activity_attempt_guid, part_attempt_guid) do
      {:ok, {hint, trigger, has_more_hints}} ->
        maybe_fire_trigger(section_slug, Plug.Conn.get_session(conn, :current_user_id), trigger)

        json(conn, %{"type" => "success", "hint" => hint, "hasMoreHints" => has_more_hints})

      {:error, {:not_found}} ->
        error(conn, 404, "not found")

      {:error, {:no_more_hints}} ->
        json(conn, %{"type" => "success", "hasMoreHints" => false})

      {:error, _e} ->
        {_, msg} = Oli.Utils.log_error("Could not get hint", e)
        error(conn, 500, msg)
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

    case Activity.save_student_input(parsed) do
      {:ok, _} ->
        json(conn, %{"type" => "success"})

      {:error, _e} ->
        {_, msg} = Oli.Utils.log_error("Could not save activity", e)
        error(conn, 500, msg)
    end
  end

  @doc """
  Saves user state for all parts for a specific activity attempt on a basic page. This will only
  save the state for active part attempts.
  """
  @doc parameters: @activity_attempt_parameters,
       request_body: {"User state", "application/json", ActivityAttemptBody, required: true},
       responses: %{
         200 => {"Update Response", "application/json", UserStateUpdateResponse}
       }
  def save_active_activity(conn, %{
        "activity_attempt_guid" => _attempt_guid,
        "partInputs" => part_inputs
      }) do
    parsed =
      Enum.map(part_inputs, fn %{"attemptGuid" => attempt_guid, "response" => response} ->
        %{attempt_guid: attempt_guid, response: response}
      end)

    case Activity.save_student_input(parsed, only_active: true) do
      {:ok, _} ->
        json(conn, %{"type" => "success"})

      {:error, :already_submitted} ->
        conn
        |> put_status(403)
        |> json(%{
          "error" => true,
          "message" =>
            "These changes could not be saved as this attempt may have already been submitted"
        })

      {:error, _e} ->
        {_, msg} = Oli.Utils.log_error("Could not save activity", e)
        error(conn, 500, msg)
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
    datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)

    parsed =
      Enum.map(part_inputs, fn %{"attemptGuid" => attempt_guid, "response" => input} ->
        %{
          attempt_guid: attempt_guid,
          input: %StudentInput{files: Map.get(input, "files", []), input: Map.get(input, "input")}
        }
      end)

    case ActivityEvaluation.evaluate_activity(
           section_slug,
           activity_attempt_guid,
           parsed,
           datashop_session_id
         ) do
      {:ok, evaluations} ->
        maybe_fire_trigger(
          section_slug,
          Plug.Conn.get_session(conn, :current_user_id),
          evaluations
        )

        json(conn, %{"type" => "success", "actions" => evaluations})

      {:error, message} ->
        {_, msg} = Oli.Utils.log_error("Could not submit activity", message)
        error(conn, 500, msg)
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
    datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)

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

    case ActivityEvaluation.apply_client_evaluation(
           section_slug,
           activity_attempt_guid,
           client_evaluations,
           datashop_session_id
         ) do
      {:ok, evaluations} ->
        json(conn, %{"type" => "success", "actions" => evaluations})

      {:error, _e} ->
        {_, msg} = Oli.Utils.log_error("Could not process activity evaluations", e)
        error(conn, 500, msg)
    end
  end

  @doc """
  Creates a new attempt for an activity.
  """
  @doc parameters: @activity_attempt_parameters,
       responses: %{
         200 => {"New Attempt Response", "application/json", NewActivityAttemptResponse}
       }
  def new_activity(
        conn,
        %{
          "section_slug" => section_slug,
          "activity_attempt_guid" => activity_attempt_guid,
          "survey_id" => survey_id
        } = params
      ) do
    seed_state_from_previous = Map.get(params, "seedResponsesWithPrevious", false)
    datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)

    case Activity.reset_activity(
           section_slug,
           activity_attempt_guid,
           datashop_session_id,
           seed_state_from_previous,
           survey_id
         ) do
      {:ok, {attempt_state, model}} ->
        json(conn, %{"type" => "success", "attemptState" => attempt_state, "model" => model})

      {:error, _e} ->
        error(conn, 500, "Could not reset activity")
    end
  end

  def new_activity(
        conn,
        %{
          "section_slug" => section_slug,
          "activity_attempt_guid" => activity_attempt_guid
        } = params
      ) do
    seed_state_from_previous = Map.get(params, "seedResponsesWithPrevious", false)
    datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)

    case Activity.reset_activity(
           section_slug,
           activity_attempt_guid,
           datashop_session_id,
           seed_state_from_previous
         ) do
      {:ok, {attempt_state, model}} ->
        json(conn, %{"type" => "success", "attemptState" => attempt_state, "model" => model})

      {:error, _e} ->
        error(conn, 500, "could not reset activity")
    end
  end

  def file_upload(conn, %{
        "section_slug" => section_slug,
        "activity_attempt_guid" => activity_guid,
        "part_attempt_guid" => part_guid,
        "file" => file,
        "name" => name
      }) do
    case Base.decode64(file) do
      {:ok, contents} ->
        case Oli.Delivery.Attempts.Artifact.upload(
               section_slug,
               activity_guid,
               part_guid,
               name,
               contents
             ) do
          {:ok, url} ->
            json(conn, %{
              result: "success",
              url: url,
              fileSize: byte_size(contents),
              creationDate: :os.system_time(:millisecond)
            })

          {:error, error} ->
            {_id, err_msg} = Oli.Utils.log_error("failed to add artifact", error)
            error(conn, 400, err_msg)
        end

      _ ->
        error(conn, 400, "invalid encoded file")
    end
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end
end
