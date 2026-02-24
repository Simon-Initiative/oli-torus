defmodule Oli.InstructorDashboard.DataSnapshot.CsvExport do
  @moduledoc """
  Transform-only CSV ZIP export adapter over snapshot/projection bundles.
  """

  require Logger

  alias Oli.Dashboard.Snapshot.Parity
  alias Oli.Dashboard.Snapshot.Telemetry
  alias Oli.InstructorDashboard.DataSnapshot.DatasetRegistry
  alias Oli.Utils

  @type export_request :: map() | keyword()
  @type snapshot_bundle :: map()
  @type manifest :: map()
  @type reason_code ::
          :required_projection_unavailable
          | :required_projection_failed
          | :dataset_policy_excluded
          | :serializer_error
          | :zip_build_failed
          | :parity_mismatch
          | :export_timeout
          | :export_failed
  @type error :: {:export_failed, reason_code(), map()}
  @required_dataset_spec_keys [
    :dataset_id,
    :filename,
    :required_projections,
    :optional_projections,
    :serializer_module,
    :failure_policy
  ]

  @spec build_zip(snapshot_bundle(), export_request()) ::
          {:ok, binary(), manifest()} | {:error, error()}
  def build_zip(snapshot_bundle, export_request \\ %{})

  def build_zip(snapshot_bundle, export_request) when is_list(export_request) do
    build_zip(snapshot_bundle, Map.new(export_request))
  end

  def build_zip(%{} = snapshot_bundle, %{} = export_request) do
    started_at = System.monotonic_time()

    result =
      with {:ok, export_profile} <- export_profile(export_request),
           {:ok, dataset_specs} <- dataset_specs(export_profile, export_request),
           {:ok, dataset_entries, zip_entries} <-
             build_dataset_entries(snapshot_bundle, dataset_specs),
           {:ok, manifest} <-
             build_manifest(snapshot_bundle, export_profile, dataset_entries, export_request),
           {:ok, zip_binary} <- build_zip_binary(zip_entries, manifest, export_request) do
        {:ok, zip_binary, manifest}
      end

    duration_ms =
      System.convert_time_unit(System.monotonic_time() - started_at, :native, :millisecond)

    emit_export_telemetry(result, snapshot_bundle, export_request, duration_ms)

    case result do
      {:ok, _zip_binary, _manifest} = success ->
        success

      {:error, reason} = error ->
        log_export_failure(reason)
        error
    end
  end

  def build_zip(_snapshot_bundle, _export_request) do
    export_error(:export_failed, %{reason: :invalid_export_request})
  end

  defp export_profile(export_request) do
    profile =
      Map.get(export_request, :export_profile) ||
        Map.get(export_request, "export_profile") ||
        :default

    case profile do
      profile when profile in [:default, :instructor_dashboard, :with_optional_ai] ->
        {:ok, profile}

      other ->
        export_error(:export_failed, %{reason: {:unknown_export_profile, other}})
    end
  end

  defp dataset_specs(export_profile, export_request) do
    case Map.get(export_request, :dataset_specs) || Map.get(export_request, "dataset_specs") do
      nil ->
        DatasetRegistry.datasets_for(export_profile)

      dataset_specs when is_list(dataset_specs) ->
        normalize_dataset_specs(dataset_specs)

      other ->
        export_error(:export_failed, %{reason: {:invalid_dataset_specs, other}})
    end
  end

  defp build_dataset_entries(snapshot_bundle, dataset_specs) do
    Enum.reduce_while(dataset_specs, {:ok, [], []}, fn dataset_spec,
                                                       {:ok, entries_acc, zip_acc} ->
      dataset_id = Map.fetch!(dataset_spec, :dataset_id)
      filename = Map.fetch!(dataset_spec, :filename)
      failure_policy = Map.fetch!(dataset_spec, :failure_policy)

      case evaluate_dataset(snapshot_bundle, dataset_spec) do
        {:include, projection_state} ->
          serializer_module = Map.fetch!(dataset_spec, :serializer_module)

          case serialize_dataset(snapshot_bundle, dataset_spec, serializer_module) do
            {:ok, csv_data} ->
              entry = %{
                dataset_id: dataset_id,
                filename: filename,
                status: :included,
                projection_state: projection_state,
                reason_code: nil
              }

              zip_entry = {String.to_charlist(filename), csv_data}
              {:cont, {:ok, [entry | entries_acc], [zip_entry | zip_acc]}}

            {:error, reason} ->
              serializer_error = %{dataset_id: dataset_id, reason: reason}

              case failure_policy do
                :allow_partial_with_manifest ->
                  entry = %{
                    dataset_id: dataset_id,
                    filename: filename,
                    status: :excluded,
                    projection_state: projection_state,
                    reason_code: :serializer_error
                  }

                  {:cont, {:ok, [entry | entries_acc], zip_acc}}

                :fail_closed ->
                  {:halt, export_error(:serializer_error, serializer_error)}
              end
          end

        {:exclude, reason_code, projection_state} ->
          entry = %{
            dataset_id: dataset_id,
            filename: filename,
            status: :excluded,
            projection_state: projection_state,
            reason_code: reason_code
          }

          {:cont, {:ok, [entry | entries_acc], zip_acc}}

        {:error, reason_code, details} ->
          {:halt, export_error(reason_code, Map.merge(%{dataset_id: dataset_id}, details))}
      end
    end)
    |> case do
      {:ok, entries, zip_entries} -> {:ok, Enum.reverse(entries), Enum.reverse(zip_entries)}
      other -> other
    end
  end

  defp evaluate_dataset(snapshot_bundle, dataset_spec) do
    projection_statuses = Map.get(snapshot_bundle, :projection_statuses, %{})
    projections = Map.get(snapshot_bundle, :projections, %{})

    required_projection_keys = Map.get(dataset_spec, :required_projections, [])
    failure_policy = Map.get(dataset_spec, :failure_policy, :fail_closed)

    projection_state =
      required_projection_states(required_projection_keys, projection_statuses, projections)

    cond do
      all_ready?(projection_state) ->
        {:include, :ready}

      any_failed_or_unavailable?(projection_state) and
          failure_policy == :allow_partial_with_manifest ->
        {:exclude, :dataset_policy_excluded, projection_state}

      any_failed_or_unavailable?(projection_state) and failure_policy == :fail_closed ->
        reason_code =
          if any_unavailable?(projection_state),
            do: :required_projection_unavailable,
            else: :required_projection_failed

        {:error, reason_code, %{projection_state: projection_state}}

      any_partial?(projection_state) and failure_policy == :allow_partial_with_manifest ->
        {:include, :partial}

      any_partial?(projection_state) and failure_policy == :fail_closed ->
        {:error, :required_projection_failed, %{projection_state: projection_state}}

      true ->
        {:error, :export_failed, %{projection_state: projection_state}}
    end
  end

  defp required_projection_states(required_projection_keys, projection_statuses, projections) do
    Enum.map(required_projection_keys, fn projection_key ->
      projection_status = Map.get(projection_statuses, projection_key, %{status: :unavailable})
      projection_data_present = Map.has_key?(projections, projection_key)

      %{
        projection_key: projection_key,
        status: Map.get(projection_status, :status, :unavailable),
        reason_code: Map.get(projection_status, :reason_code),
        data_present: projection_data_present
      }
    end)
  end

  defp all_ready?(projection_state), do: Enum.all?(projection_state, &(&1.status == :ready))
  defp any_partial?(projection_state), do: Enum.any?(projection_state, &(&1.status == :partial))

  defp any_failed_or_unavailable?(projection_state),
    do:
      Enum.any?(projection_state, &(&1.status in [:failed, :unavailable] or not &1.data_present))

  defp any_unavailable?(projection_state),
    do: Enum.any?(projection_state, &(&1.status == :unavailable or not &1.data_present))

  @spec serialize_dataset(snapshot_bundle(), map(), module()) ::
          {:ok, binary()} | {:error, term()}
  def serialize_dataset(snapshot_bundle, dataset_spec, serializer_module) do
    if function_exported?(serializer_module, :serialize, 2) do
      serializer_module.serialize(snapshot_bundle, dataset_spec)
    else
      {:error, {:invalid_serializer_module, serializer_module}}
    end
  end

  defp build_manifest(snapshot_bundle, export_profile, dataset_entries, export_request) do
    snapshot = Map.get(snapshot_bundle, :snapshot, %{})

    with {:ok, parity} <-
           build_parity_metadata(
             snapshot_bundle,
             dataset_entries,
             export_profile,
             export_request
           ) do
      {:ok,
       %{
         export_profile: export_profile,
         generated_at: DateTime.utc_now(),
         request_token: Map.get(snapshot_bundle, :request_token),
         snapshot_version: Map.get(snapshot, :snapshot_version),
         projection_version: Map.get(snapshot, :projection_version),
         parity: parity,
         datasets: dataset_entries
       }}
    end
  end

  defp build_zip_binary(zip_entries, manifest, export_request) do
    manifest_json = Jason.encode!(manifest)
    zip_filename = Map.get(export_request, :zip_filename, "data_snapshot_export.zip")

    entries = zip_entries ++ [{~c"manifest.json", manifest_json}]

    case Utils.zip(entries, zip_filename) do
      binary when is_binary(binary) ->
        {:ok, binary}

      other ->
        export_error(:zip_build_failed, %{reason: other})
    end
  rescue
    error ->
      export_error(:zip_build_failed, %{reason: Exception.message(error)})
  end

  defp normalize_dataset_specs(dataset_specs) do
    Enum.reduce_while(dataset_specs, {:ok, []}, fn dataset_spec, {:ok, acc} ->
      case normalize_dataset_spec(dataset_spec) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, reason} -> {:halt, export_error(:export_failed, %{reason: reason})}
      end
    end)
    |> case do
      {:ok, specs} -> {:ok, Enum.reverse(specs)}
      other -> other
    end
  end

  defp normalize_dataset_spec(%{} = dataset_spec) do
    with :ok <- validate_required_dataset_spec_keys(dataset_spec),
         :ok <- validate_dataset_spec_identity(dataset_spec),
         :ok <- validate_dataset_spec_lists(dataset_spec),
         :ok <- validate_dataset_spec_serializer(dataset_spec),
         :ok <- validate_dataset_spec_failure_policy(dataset_spec) do
      {:ok, dataset_spec}
    end
  end

  defp normalize_dataset_spec(other), do: {:error, {:invalid_dataset_spec, other}}

  defp validate_required_dataset_spec_keys(dataset_spec) do
    missing_keys =
      @required_dataset_spec_keys
      |> Enum.reject(&Map.has_key?(dataset_spec, &1))

    case missing_keys do
      [] -> :ok
      _ -> {:error, {:invalid_dataset_spec, {:missing_keys, missing_keys}}}
    end
  end

  defp validate_dataset_spec_lists(dataset_spec) do
    required = Map.fetch!(dataset_spec, :required_projections)
    optional = Map.fetch!(dataset_spec, :optional_projections)

    cond do
      not is_list(required) ->
        {:error, {:invalid_dataset_spec, {:required_projections, required}}}

      not is_list(optional) ->
        {:error, {:invalid_dataset_spec, {:optional_projections, optional}}}

      not Enum.all?(required, &is_projection_key?/1) ->
        {:error, {:invalid_dataset_spec, {:required_projections, required}}}

      not Enum.all?(optional, &is_projection_key?/1) ->
        {:error, {:invalid_dataset_spec, {:optional_projections, optional}}}

      true ->
        :ok
    end
  end

  defp validate_dataset_spec_identity(dataset_spec) do
    dataset_id = Map.fetch!(dataset_spec, :dataset_id)
    filename = Map.fetch!(dataset_spec, :filename)

    cond do
      not is_projection_key?(dataset_id) ->
        {:error, {:invalid_dataset_spec, {:dataset_id, dataset_id}}}

      not is_binary(filename) or filename == "" ->
        {:error, {:invalid_dataset_spec, {:filename, filename}}}

      true ->
        :ok
    end
  end

  defp validate_dataset_spec_serializer(dataset_spec) do
    serializer_module = Map.fetch!(dataset_spec, :serializer_module)

    cond do
      not is_atom(serializer_module) ->
        {:error, {:invalid_dataset_spec, {:serializer_module, serializer_module}}}

      not function_exported?(serializer_module, :serialize, 2) ->
        {:error, {:invalid_dataset_spec, {:serializer_module, serializer_module}}}

      true ->
        :ok
    end
  end

  defp validate_dataset_spec_failure_policy(dataset_spec) do
    case Map.fetch!(dataset_spec, :failure_policy) do
      :fail_closed -> :ok
      :allow_partial_with_manifest -> :ok
      other -> {:error, {:invalid_dataset_spec, {:failure_policy, other}}}
    end
  end

  defp export_error(reason_code, details) do
    {:error, {:export_failed, reason_code, details}}
  end

  defp build_parity_metadata(snapshot_bundle, dataset_entries, export_profile, export_request) do
    actual_fingerprint = Parity.fingerprint(snapshot_bundle, dataset_entries)
    expected_fingerprint = expected_parity_fingerprint(export_request)

    comparison =
      case expected_fingerprint do
        nil ->
          %{
            status: :not_checked,
            expected_fingerprint: nil,
            actual_fingerprint: actual_fingerprint
          }

        expected ->
          case Parity.compare(expected, actual_fingerprint) do
            :match ->
              %{
                status: :match,
                expected_fingerprint: expected,
                actual_fingerprint: actual_fingerprint
              }

            {:mismatch, mismatch} ->
              %{
                status: :mismatch,
                expected_fingerprint: mismatch.expected,
                actual_fingerprint: mismatch.actual
              }
          end
      end

    Telemetry.parity_check(%{
      status: comparison.status,
      export_profile: export_profile,
      dataset_count: length(dataset_entries),
      mismatch_count: mismatch_count(comparison.status),
      expected_present: not is_nil(expected_fingerprint),
      reason_code: parity_reason_code(comparison.status)
    })

    {:ok, %{fingerprint: actual_fingerprint, comparison: comparison}}
  end

  defp expected_parity_fingerprint(export_request) do
    Map.get(export_request, :expected_parity_fingerprint) ||
      Map.get(export_request, "expected_parity_fingerprint")
  end

  defp mismatch_count(:mismatch), do: 1
  defp mismatch_count(_), do: 0

  defp parity_reason_code(:mismatch), do: :parity_mismatch
  defp parity_reason_code(_), do: nil

  defp is_projection_key?(value) when is_atom(value), do: true
  defp is_projection_key?(value) when is_binary(value) and byte_size(value) > 0, do: true
  defp is_projection_key?(_value), do: false

  defp emit_export_telemetry(result, snapshot_bundle, export_request, duration_ms) do
    scope_container_type = get_in(snapshot_bundle, [:scope, :container_type])
    export_profile = requested_export_profile(export_request)

    case result do
      {:ok, _zip_binary, %{datasets: datasets, export_profile: manifest_profile}} ->
        Telemetry.export_stop(
          %{duration_ms: duration_ms},
          %{
            outcome: :ok,
            scope_container_type: scope_container_type,
            export_profile: manifest_profile,
            dataset_count: length(datasets),
            included_count: dataset_status_count(datasets, :included),
            excluded_count: dataset_status_count(datasets, :excluded)
          }
        )

      {:error, {:export_failed, reason_code, details}} ->
        Telemetry.export_stop(
          %{duration_ms: duration_ms},
          %{
            outcome: :error,
            scope_container_type: scope_container_type,
            export_profile: export_profile,
            reason_code: reason_code,
            error_type: error_type(details)
          }
        )

      {:error, reason} ->
        Telemetry.export_stop(
          %{duration_ms: duration_ms},
          %{
            outcome: :error,
            scope_container_type: scope_container_type,
            export_profile: export_profile,
            reason_code: :export_failed,
            error_type: error_type(reason)
          }
        )
    end
  end

  defp requested_export_profile(export_request) do
    Map.get(export_request, :export_profile) ||
      Map.get(export_request, "export_profile") ||
      :default
  end

  defp dataset_status_count(datasets, status) do
    Enum.count(datasets, &(&1.status == status))
  end

  defp error_type(%{reason: {type, _rest}}) when is_atom(type), do: Atom.to_string(type)
  defp error_type(%{reason: type}) when is_atom(type), do: Atom.to_string(type)
  defp error_type(%{reason: type}) when is_binary(type), do: type
  defp error_type({type, _rest}) when is_atom(type), do: Atom.to_string(type)
  defp error_type(type) when is_atom(type), do: Atom.to_string(type)
  defp error_type(type) when is_binary(type), do: type
  defp error_type(other), do: inspect(other)

  defp log_export_failure({:export_failed, reason_code, details})
       when reason_code in [:required_projection_unavailable, :required_projection_failed] do
    Logger.warning(
      "snapshot csv export failed reason=#{inspect(reason_code)} details=#{inspect(details)}"
    )
  end

  defp log_export_failure(reason) do
    Logger.error("snapshot csv export failed reason=#{inspect(reason)}")
  end
end
