defmodule Oli.Institutions.Audited do
  @moduledoc """
  Application boundary for audited institution and LMS configuration commands: institutions,
  approval and decline of LTI registration requests, LTI registrations and deployments, and the
  system research-consent form.

  Each command writes the change and its event in one transaction (see
  `Oli.Auditing.Command`); an update that changes no audited field writes no event. Commands do
  not authorize the actor: callers keep their existing authorization, such as the admin routes.
  `context` identifies the administrator who acts.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export internal modules. Outgoing checks are off
  # because this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  import Ecto.Query, only: [from: 2]

  alias Ecto.Multi
  alias Oli.Auditing
  alias Oli.Auditing.{Command, Context}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Delivery.ResearchConsent
  alias Oli.Institutions.{Institution, PendingRegistration}
  alias Oli.Lti.Tool.{Deployment, Registration}
  alias Oli.Repo

  @type error ::
          :not_found | :nested_transaction | Ecto.Changeset.t() | Auditing.Error.t() | term()

  ## Institutions

  @doc "Creates an institution and records `institution_settings_changed`."
  @spec create_institution(Context.t(), map()) :: {:ok, %Institution{}} | {:error, error()}
  def create_institution(context, attrs),
    do: Command.run(:institution, &create_institution_multi(&1, :institution, context, attrs))

  @doc "Adds the steps of `create_institution/2` to `multi`."
  @spec create_institution_multi(Multi.t(), Multi.name(), Context.t(), map()) :: Multi.t()
  def create_institution_multi(multi, name, context, attrs) do
    Command.insert(
      multi,
      name,
      context,
      Institution.changeset(%Institution{}, attrs),
      institution()
    )
  end

  @doc "Updates the institution with ID `id` and records the settings that changed."
  @spec update_institution(Context.t(), pos_integer(), map()) ::
          {:ok, %Institution{}} | {:error, error()}
  def update_institution(context, id, attrs) do
    Command.run(:institution, fn multi ->
      Command.update(
        multi,
        :institution,
        context,
        {Institution, id},
        &Institution.changeset(&1, attrs),
        institution()
      )
    end)
  end

  @doc """
  Marks the institution as deleted (the existing soft delete) and records the status change.
  """
  @spec delete_institution(Context.t(), pos_integer()) ::
          {:ok, %Institution{}} | {:error, error()}
  def delete_institution(context, id), do: update_institution(context, id, %{status: :deleted})

  ## Registration requests

  @doc """
  Approves the pending LTI registration request with ID `pending_id`: finds or creates the
  institution, finds or creates the registration, creates the deployment when the request has
  one, and removes the request, all in one transaction. Records an event for each institution,
  registration, and deployment it creates; removing the request writes none.

  `institution` is `:by_url` (reuse an active institution with the same normalized URL, or
  create one), `:new` (always create one), or the ID of an existing active institution.
  Returns `{:ok, {institution, registration, deployment}}`.
  """
  @spec approve_pending_registration(Context.t(), pos_integer(), :by_url | :new | term()) ::
          {:ok, {%Institution{}, %Registration{}, %Deployment{} | nil}} | {:error, error()}
  def approve_pending_registration(%Context{} = context, pending_id, institution) do
    Command.run(:approval, fn multi ->
      multi
      |> Multi.run({:approval, :pending}, fn repo, _changes ->
        Command.lock(repo, PendingRegistration, pending_id)
      end)
      |> Multi.merge(fn %{{:approval, :pending} => pending} ->
        institution_step(context, pending, institution)
      end)
      |> Multi.run({:approval, :jwk}, fn _repo, _changes -> Lti_1p3.get_active_jwk() end)
      |> Multi.merge(fn changes ->
        pending = Map.fetch!(changes, {:approval, :pending})
        institution = Map.fetch!(changes, {:approval, :institution})

        attrs =
          Map.merge(PendingRegistration.registration_attrs(pending), %{
            institution_id: institution.id,
            tool_jwk_id: Map.fetch!(changes, {:approval, :jwk}).id
          })

        case existing_registration(attrs) do
          nil ->
            create_registration_multi(Multi.new(), {:approval, :registration}, context, attrs)

          found ->
            Multi.put(Multi.new(), {:approval, :registration}, found)
        end
      end)
      |> Multi.merge(fn changes ->
        pending = Map.fetch!(changes, {:approval, :pending})

        attrs =
          Map.merge(PendingRegistration.deployment_attrs(pending), %{
            institution_id: Map.fetch!(changes, {:approval, :institution}).id,
            registration_id: Map.fetch!(changes, {:approval, :registration}).id
          })

        case {institution, attrs} do
          {:new, _attrs} ->
            create_deployment_multi(Multi.new(), {:approval, :deployment}, context, attrs)

          {_reuse, %{deployment_id: nil}} ->
            Multi.put(Multi.new(), {:approval, :deployment}, nil)

          {_reuse, _attrs} ->
            create_deployment_multi(Multi.new(), {:approval, :deployment}, context, attrs)
        end
      end)
      |> Multi.run({:approval, :removed}, fn repo, changes ->
        changes |> Map.fetch!({:approval, :pending}) |> repo.delete()
      end)
      |> Multi.run(:approval, fn _repo, changes ->
        {:ok,
         {Map.fetch!(changes, {:approval, :institution}),
          Map.fetch!(changes, {:approval, :registration}),
          Map.fetch!(changes, {:approval, :deployment})}}
      end)
    end)
  end

  @doc """
  Declines the pending LTI registration request with ID `pending_id`, removes it, and records
  `lms_registration_declined` with the request's identifying fields (never its contact email).
  A request already approved or declined returns `{:error, :not_found}`.
  """
  @spec decline_pending_registration(Context.t(), pos_integer()) ::
          {:ok, %PendingRegistration{}} | {:error, error()}
  def decline_pending_registration(%Context{} = context, pending_id) do
    Command.run(:decline, fn multi ->
      Command.delete(multi, :decline, context, {PendingRegistration, pending_id}, %{
        event_type: :lms_registration_declined,
        policy: %{},
        proposal: fn pending, _operation ->
          %{
            entity: {:pending_registration, pending.id, %{id: pending.id, name: pending.name}},
            event_key: "pending_registration:#{pending.id}:declined",
            details:
              pending
              |> Map.take(~w(institution_url country_code issuer client_id deployment_id)a)
              |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
          }
        end
      })
    end)
  end

  ## Registrations and deployments

  @doc "Creates an LTI registration and records `lms_settings_changed`."
  @spec create_registration(Context.t(), map()) :: {:ok, %Registration{}} | {:error, error()}
  def create_registration(context, attrs),
    do: Command.run(:registration, &create_registration_multi(&1, :registration, context, attrs))

  @doc "Adds the steps of `create_registration/2` to `multi`."
  @spec create_registration_multi(Multi.t(), Multi.name(), Context.t(), map()) :: Multi.t()
  def create_registration_multi(multi, name, context, attrs),
    do:
      Command.insert(
        multi,
        name,
        context,
        Registration.changeset(%Registration{}, attrs),
        registration()
      )

  @doc "Updates the LTI registration with ID `id` and records the settings that changed."
  @spec update_registration(Context.t(), pos_integer(), map()) ::
          {:ok, %Registration{}} | {:error, error()}
  def update_registration(context, id, attrs) do
    Command.run(:registration, fn multi ->
      Command.update(
        multi,
        :registration,
        context,
        {Registration, id},
        &Registration.changeset(&1, attrs),
        registration()
      )
    end)
  end

  @doc "Deletes the LTI registration with ID `id` and records the deletion."
  @spec delete_registration(Context.t(), pos_integer()) ::
          {:ok, %Registration{}} | {:error, error()}
  def delete_registration(context, id) do
    Command.run(:registration, fn multi ->
      Command.delete(multi, :registration, context, {Registration, id}, registration())
    end)
  end

  @doc "Creates an LTI deployment and records `lms_settings_changed` for its institution."
  @spec create_deployment(Context.t(), map()) :: {:ok, %Deployment{}} | {:error, error()}
  def create_deployment(context, attrs),
    do: Command.run(:deployment, &create_deployment_multi(&1, :deployment, context, attrs))

  @doc "Adds the steps of `create_deployment/2` to `multi`."
  @spec create_deployment_multi(Multi.t(), Multi.name(), Context.t(), map()) :: Multi.t()
  def create_deployment_multi(multi, name, context, attrs),
    do:
      Command.insert(
        multi,
        name,
        context,
        Deployment.changeset(%Deployment{}, attrs),
        deployment()
      )

  @doc "Updates the LTI deployment with ID `id` and records the settings that changed."
  @spec update_deployment(Context.t(), pos_integer(), map()) ::
          {:ok, %Deployment{}} | {:error, error()}
  def update_deployment(context, id, attrs) do
    Command.run(:deployment, fn multi ->
      Command.update(
        multi,
        :deployment,
        context,
        {Deployment, id},
        &Deployment.changeset(&1, attrs),
        deployment()
      )
    end)
  end

  @doc "Deletes the LTI deployment with ID `id` and records the deletion."
  @spec delete_deployment(Context.t(), pos_integer()) :: {:ok, %Deployment{}} | {:error, error()}
  def delete_deployment(context, id) do
    Command.run(:deployment, fn multi ->
      Command.delete(multi, :deployment, context, {Deployment, id}, deployment())
    end)
  end

  ## Research consent

  @doc """
  Sets the system research-consent form (`:oli_form` or `:no_form`) and records
  `research_consent_settings_changed`. This is the platform configuration; an individual
  learner's consent is a preference and is not recorded here.
  """
  @spec update_system_research_consent(Context.t(), atom() | String.t()) ::
          {:ok, %ResearchConsent{}} | {:error, error()}
  def update_system_research_consent(context, research_consent) do
    attrs = %{research_consent: research_consent}

    Command.run(:research_consent, fn multi ->
      case Repo.one(from(r in ResearchConsent, limit: 1)) do
        nil ->
          Command.insert(
            multi,
            :research_consent,
            context,
            ResearchConsent.changeset(%ResearchConsent{}, attrs),
            research_consent()
          )

        %ResearchConsent{id: id} ->
          Command.update(
            multi,
            :research_consent,
            context,
            {ResearchConsent, id},
            &ResearchConsent.changeset(&1, attrs),
            research_consent()
          )
      end
    end)
  end

  ## Steps and event descriptions

  defp institution_step(context, pending, :new) do
    create_institution_multi(
      Multi.new(),
      {:approval, :institution},
      context,
      PendingRegistration.institution_attrs(pending)
    )
  end

  defp institution_step(context, pending, :by_url) do
    attrs = PendingRegistration.institution_attrs(pending)

    case Oli.Institutions.find_active_institution_by_normalized_url(attrs.institution_url) do
      nil -> create_institution_multi(Multi.new(), {:approval, :institution}, context, attrs)
      institution -> Multi.put(Multi.new(), {:approval, :institution}, institution)
    end
  end

  defp institution_step(_context, _pending, institution_id) do
    Multi.run(Multi.new(), {:approval, :institution}, fn repo, _changes ->
      with {:ok, id} <- parse_id(institution_id) do
        case repo.get(Institution, id) do
          nil -> {:error, :institution_not_found}
          %Institution{status: :deleted} -> {:error, :institution_deleted}
          institution -> {:ok, institution}
        end
      end
    end)
  end

  defp parse_id(id) when is_integer(id), do: {:ok, id}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed, ""} -> {:ok, parsed}
      _ -> {:error, :invalid_institution_id}
    end
  end

  defp parse_id(_id), do: {:error, :invalid_institution_id}

  defp existing_registration(%{issuer: issuer, client_id: client_id}) do
    Repo.one(from(r in Registration, where: r.issuer == ^issuer and r.client_id == ^client_id))
  end

  defp institution do
    %{
      event_type: :institution_settings_changed,
      policy: Fields.organization(),
      proposal: fn institution, operation ->
        %{
          entity: {:institution, institution.id, institution},
          scope: %{institution_id: institution.id},
          event_key: "institution:#{institution.id}:#{operation}"
        }
      end
    }
  end

  defp registration do
    %{
      event_type: :lms_settings_changed,
      policy: Fields.integration(),
      proposal: fn registration, operation ->
        %{
          entity:
            {:registration, registration.id, %{id: registration.id, label: registration.issuer}},
          event_key: "registration:#{registration.id}:#{operation}"
        }
      end
    }
  end

  defp deployment do
    %{
      event_type: :lms_settings_changed,
      policy: Fields.integration(),
      proposal: fn deployment, operation ->
        %{
          entity:
            {:deployment, deployment.id, %{id: deployment.id, label: deployment.deployment_id}},
          scope: %{institution_id: deployment.institution_id},
          event_key: "deployment:#{deployment.id}:#{operation}"
        }
      end
    }
  end

  defp research_consent do
    %{
      event_type: :research_consent_settings_changed,
      policy: Fields.organization(),
      proposal: fn _record, operation ->
        %{
          entity: {:research_consent, "system", %{label: "System research consent form"}},
          event_key: "research_consent:system:#{operation}"
        }
      end
    }
  end
end
