defmodule ECL.Constellation do
  @moduledoc """
  Constellation SDK.
  """

  import Elixir.HTTPoison.Retry

  @spec login(String.t, String.t) :: String.t
  def login(username, password) do
    signin_path = "/ise/signintoken"
    body = %{
      username: username,
      password: password
    }

    responseObject = send_constellation_request_with_retries(signin_path, body, "", "POST")
    Map.fetch!(responseObject, "AuthToken")
  end

  @spec me(String.t) :: %{}
  def me(auth_token) do
    me_path = "/ise/me"
    send_constellation_request_with_retries(me_path, "", auth_token, "GET")
  end

  @spec download(String.t, String.t, list(String.T)) :: %{}
   def download(auth_token, object_id, fields) do
    download_path = "/obj/download"
    body = %{
      requests: [
        %{
          object: %{
            id: object_id
          },
          fields: fields
        }
      ]
    }

    send_constellation_request_with_retries(download_path, body, auth_token, "POST")
  end

  @spec search(String.t, String.t, String.t) :: %{}
  def search(auth_token, type, clause) do
    search_path = "/obj/search"
    body = %{
      queries: [
          %{
              clauses: [
                  %{
                      Types: [type],
                      Query: clause,
                  }
              ],
              SubTypes: true,
              date: nil,
          }
      ],
    }
    send_constellation_request_with_retries(search_path, body, auth_token, "POST")
  end


  @spec upload(String.t, String.t, String.t, %{}) :: %{}
  def upload(auth_token, type, id, new_field_values) do
    upload_path = "/obj/upload"

    # if and id isn't provided, we're creating a new object and the request is slightly different
    object_upload_data = case id do
      "" -> %{
        type: type,
        fields: new_field_values,
      }
      _ ->  %{
        object:
          %{id: id, type: type},
        fields: new_field_values,
      }
    end

    body = %{
      requests: [object_upload_data]
    }

    send_constellation_request_with_retries(upload_path, body, auth_token, "POST")
  end


  def send_constellation_request_with_retries(orig_path, data, auth_token, request_type) do
    base_path = "https://constellation.emeraldcloudlab.com"

    path = base_path <> orig_path

    base_header = [{"Content-type", "application/json"}]

    headers = if auth_token != "" do
      [{"Authorization", "Bearer " <> auth_token} | base_header]
    else
      base_header
    end


    headers = if orig_path == "/obj/upload" do
      # starting to get ugly here with this if statement (and during debugging it was proved to be true)
      [{"X-ECL-NotebookId", get_default_notebook_id(auth_token)} | headers]
    else
      headers
    end


    case request_type do
      "GET" -> HTTPoison.get(path, headers, [])
      "POST" ->
          body = Poison.encode!(data)
          HTTPoison.post(path, body, headers, [])
    end
    |>  autoretry(max_attempts: 5, wait: 1000, include_404s: false, retry_unknown_errors: false)
    |>  handle_constellation_response()

  end

  def handle_constellation_response(response_tuple) do
    response = elem(response_tuple, 1)
    Poison.decode!(response.body)
  end

  @spec get_default_notebook_id(String.t) :: String.t
  def get_default_notebook_id(auth_token) do
    me = me(auth_token)
    meId = Map.get(me, "Id")
    financingTeamId = download(auth_token, meId, ["FinancingTeams"])
      |> Map.get("responses")
      |> List.first()
      |> Map.get("fields")
      |> Map.get("FinancingTeams")
      |> List.first()
      |> Map.get("object")
      |> Map.get("id")

    defaultNotebookId = download(auth_token, financingTeamId, ["DefaultNotebook"])
      |> Map.get("responses")
      |> List.first()
      |> Map.get("fields")
      |> Map.get("DefaultNotebook")
      |> Map.get("object")
      |> Map.get("id")


    defaultNotebookId
  end

  @spec execute_sll_expression(String.t, String.t) :: String.t
  def execute_sll_expression(auth_token, mm_expression) do
    # search for available manifold kernels
    responseObject = search(auth_token, "Object.Software.ManifoldKernel", "Available = true AND ManifoldJob->Computations->Status=\"Running\"")
    results = List.first(Map.get(responseObject, "Results"))
    references = Map.get(results, "References")
    if length(references) < 1 do
      raise "Mathematica kernel not found! Please contact ECL for support."
    end

    # just use the first reference
    first_kernel_id = references
      |> List.first()
      |> Map.get("id")


    # create the command object
    command_upload_data = %{
      Status: "Pending",
      Command: mm_expression,
    }

    command_upload_response = upload(auth_token, "Object.Software.ManifoldKernelCommand", "", command_upload_data)

    new_command_id = command_upload_response
      |> Map.get("responses")
      |> List.first()
      |> Map.get("id")

    new_command_cas = command_upload_response
      |> Map.get("responses")
      |> List.first()
      |> Map.get("cas")

    # link the newly created command object to the kernel object

    link_to_kernel_upload_data = %{
      "Append[Commands]": [%{
        "$Type" => "__JsonLink__",
          object: %{
            id: new_command_id,
            type: "Object.Software.ManifoldKernelCommand"
        },
        field: %{name: "ManifoldKernel"}
      }]
    }

    upload(auth_token, "Object.Software.ManifoldKernel", first_kernel_id, link_to_kernel_upload_data)
    # wait for command to return completed
    wait_for_command_to_complete(auth_token, new_command_id, new_command_cas)
  end

  def wait_for_command_to_complete(auth_token, command_id, cas) do
    # wait for the object to change from its initial state
    new_cas = poll_object_change(auth_token, command_id, cas)
    # wait for the command object to have the status completed
    download_response = download(auth_token, command_id, ["Status", "Result"])
      |> Map.get("responses")
      |> List.first()

    command_status = download_response
      |> Map.get("fields")
      |> Map.get("Status")

    if command_status == "Completed" do
      download_response
        |> Map.get("fields")
        |> Map.get("Result")
    else
      wait_for_command_to_complete(auth_token, command_id, new_cas)
    end
  end

  def poll_object_change(auth_token, object_id, cas) do
    long_polling_path = "/obj/poll-object-change"
    request_body = %{objects: [%{id: object_id, cas: cas}]}
    pollResponse = send_constellation_request_with_retries(long_polling_path, request_body, auth_token, "POST")
    changedObjects = Map.get(pollResponse, "changed")

    # call recursively if nothing has changed
    if length(changedObjects) == 0 do
      poll_object_change(auth_token, object_id, cas)
    else
      # otherwise return the new cas token
      changedObjects
        |> List.first()
        |> Map.get("id")
    end
  end
end
