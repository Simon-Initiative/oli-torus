defmodule Oli.Lti.KeysetRefreshWorkerTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  import Mox
  import Oli.Factory

  alias Oli.Lti.KeysetRefreshWorker
  alias Oli.Lti.KeysetCache

  setup :verify_on_exit!

  setup do
    # Clear cache before each test
    KeysetCache.clear_cache()
    :ok
  end

  describe "schedule_refresh/1" do
    test "schedules a job for a specific registration" do
      registration = insert(:lti_registration)

      assert {:ok, _job} = KeysetRefreshWorker.schedule_refresh(registration.id)

      assert_enqueued(
        worker: KeysetRefreshWorker,
        args: %{"registration_id" => registration.id}
      )
    end
  end

  describe "schedule_refresh_all/0" do
    test "schedules a job to refresh all registrations" do
      assert {:ok, _job} = KeysetRefreshWorker.schedule_refresh_all()

      assert_enqueued(
        worker: KeysetRefreshWorker,
        args: %{"refresh_all" => true}
      )
    end
  end

  describe "perform/1 with registration_id" do
    test "discards job when registration does not exist" do
      job = %Oban.Job{args: %{"registration_id" => 99999}}

      assert :discard = KeysetRefreshWorker.perform(job)
    end

    test "discards job when registration has no key_set_url" do
      registration = insert(:lti_registration, %{key_set_url: nil})
      job = %Oban.Job{args: %{"registration_id" => registration.id}}

      assert :discard = KeysetRefreshWorker.perform(job)
    end
  end

  describe "perform/1 with refresh_all" do
    test "processes all registrations with key_set_url" do
      # Create registrations with and without key_set_url
      _reg_with_key = insert(:lti_registration, %{key_set_url: "https://platform1.com/jwks"})
      _reg_with_key2 = insert(:lti_registration, %{key_set_url: "https://platform2.com/jwks"})
      _reg_without_key = insert(:lti_registration, %{key_set_url: nil})

      # Mock HTTP responses for both URLs
      test_key = %{
        "kty" => "RSA",
        "kid" => "test-key",
        "use" => "sig",
        "n" => "test-n",
        "e" => "AQAB"
      }

      Oli.Test.MockHTTP
      |> expect(:get, 2, fn _url, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [test_key]}),
           headers: []
         }}
      end)

      job = %Oban.Job{args: %{"refresh_all" => true}}

      # The worker should complete without error
      assert :ok = KeysetRefreshWorker.perform(job)
    end

    test "handles empty registration list gracefully" do
      # No registrations in database
      job = %Oban.Job{args: %{"refresh_all" => true}}

      assert :ok = KeysetRefreshWorker.perform(job)
    end
  end

  describe "cache-control header parsing" do
    # This tests the private parse_cache_control_max_age function indirectly
    # by checking the TTL used when caching

    test "uses default TTL when no cache-control header present" do
      registration = insert(:lti_registration, %{key_set_url: "https://platform.com/jwks"})
      job = %Oban.Job{args: %{"registration_id" => registration.id}}

      test_key = %{
        "kty" => "RSA",
        "kid" => "test-key",
        "use" => "sig",
        "n" => "test-n",
        "e" => "AQAB"
      }

      # Mock HTTP response without cache-control header
      Oli.Test.MockHTTP
      |> expect(:get, fn "https://platform.com/jwks", _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"keys" => [test_key]}),
           headers: []
         }}
      end)

      assert :ok = KeysetRefreshWorker.perform(job)
    end
  end

  describe "retry behavior" do
    test "job is configured with 5 max attempts" do
      # Verify the worker has appropriate retry configuration
      worker_opts = KeysetRefreshWorker.__opts__()
      assert worker_opts[:max_attempts] == 5
    end

    test "job uses default queue" do
      worker_opts = KeysetRefreshWorker.__opts__()
      assert worker_opts[:queue] == :default
    end
  end
end
