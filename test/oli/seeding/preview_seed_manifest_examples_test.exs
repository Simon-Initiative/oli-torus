defmodule Oli.Seeding.PreviewSeedManifestExamplesTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../../..", __DIR__)
  @manifest_dir Path.join(@repo_root, "docs/manifests/preview-seeding")
  @scenario_id "oli_torus_getting_started_course"
  @job_name "oli-torus-preview-seed"

  test "preview seed Job preserves the one-time execution contract" do
    runtime = read_yaml("runtime-config.yaml")
    job = read_yaml("seed-job.yaml")
    pod_spec = get_in(job, ["spec", "template", "spec"])
    [container] = pod_spec["containers"]

    assert runtime["data"] == %{
             "PREVIEW_QA_SEED_SCENARIO" => @scenario_id,
             "PREVIEW_QA_TOOLS_ENABLED" => "true"
           }

    assert job["metadata"]["name"] == @job_name
    assert job["metadata"]["annotations"]["argocd.argoproj.io/sync-wave"] == "20"
    assert job["spec"]["backoffLimit"] == 0
    refute Map.has_key?(job["spec"], "ttlSecondsAfterFinished")

    assert pod_spec["serviceAccountName"] == "oli-torus-preview"
    assert pod_spec["automountServiceAccountToken"] == false
    assert pod_spec["restartPolicy"] == "Never"
    assert container["image"] == "oli-torus-preview"
    assert container["command"] == ["/app/bin/seed"]
    assert container["args"] == ["scenarios", "run", "--name", @scenario_id]

    assert container["envFrom"] == [
             %{"configMapRef" => %{"name" => "oli-torus-preview-runtime"}},
             %{"secretRef" => %{"name" => "oli-torus-preview-runtime"}}
           ]

    assert get_in(container, ["resources", "requests", "cpu"])
    assert get_in(container, ["resources", "requests", "memory"])
    assert get_in(container, ["resources", "limits", "cpu"])
    assert get_in(container, ["resources", "limits", "memory"])
  end

  test "Kustomize and Argo examples retain the completed Job across later syncs" do
    kustomization = read_yaml("kustomization.yaml")
    application_set_patch = read_yaml("applicationset-patch.yaml")

    assert %{
             "source" => %{
               "fieldPath" => "data.PREVIEW_QA_SEED_SCENARIO",
               "kind" => "ConfigMap",
               "name" => "oli-torus-preview-runtime"
             },
             "targets" => [
               %{
                 "fieldPaths" => ["spec.template.spec.containers.[name=seed].args.3"],
                 "select" => %{"kind" => "Job", "name" => @job_name}
               }
             ]
           } in kustomization["replacements"]

    assert "RespectIgnoreDifferences=true" in get_in(application_set_patch, [
             "syncPolicy",
             "syncOptions"
           ])

    assert get_in(application_set_patch, ["syncPolicy", "automated", "prune"])

    assert %{
             "group" => "batch",
             "jsonPointers" => ["/spec/template"],
             "kind" => "Job",
             "name" => @job_name
           } in application_set_patch["ignoreDifferences"]
  end

  test "Playwright setup remains independent of deployment seeding" do
    forbidden_values = [@scenario_id, @job_name, "startup-status", "startup_status"]

    @repo_root
    |> Path.join("assets/automation/**/*")
    |> Path.wildcard()
    |> Enum.filter(&(Path.extname(&1) in [".ts", ".yaml", ".yml", ".json", ".md"]))
    |> Enum.each(fn path ->
      contents = File.read!(path)

      Enum.each(forbidden_values, fn value ->
        refute String.contains?(contents, value),
               "#{Path.relative_to(path, @repo_root)} unexpectedly references #{value}"
      end)
    end)
  end

  defp read_yaml(filename) do
    @manifest_dir
    |> Path.join(filename)
    |> YamlElixir.read_from_file!()
  end
end
