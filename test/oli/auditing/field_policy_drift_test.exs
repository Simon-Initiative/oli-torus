defmodule Oli.Auditing.FieldPolicyDriftTest do
  @moduledoc """
  Keeps the audit field policies in `Oli.Auditing.EventCatalog.Fields` in sync with the domain
  schemas they describe.

  A field policy is a hand-written list of the fields an event may record in `changes`.
  `Oli.Auditing.Changes.diff/3` compares only those fields, so a column that is missing from
  the policy is never audited, and nothing warns about it at runtime.

  ## Explicit yes and explicit no

  Every field of every domain schema that feeds a policy is classified once, in that schema's
  declaration in `Fields.schema_sources/0`:

    * **Audited** - the field is listed in one of the schema's `policies`, as `:value` or
      `:secret` (only a redaction marker is stored). Policies are the only lists used at runtime.
    * **Not audited** - the field is in the schema's `excluded`, with the reason (identity
      already stored in its own column, row timestamp, data derived by the system, content or
      personal data that must not be copied, configuration audited through another schema, and
      so on).

  The policies stay allowlists, so an unknown field is never recorded by default (no secret or
  personal data reaches the log by accident). The exclusions make every "no" a written decision
  that reviewers can see and challenge, instead of an omission.

  ## What these tests prevent

  Suppose a developer adds `extra_time_multiplier` to `Oli.Delivery.Settings.StudentException`
  so instructors can give a student 1.5x time, and does not touch `Fields.student_exception/0`:

    * When an instructor changes only that field, the diff is empty. `student_exception_updated`
      is a `:skip` contract, so no event is written and the change leaves no audit trail.
    * When the instructor also changes another field, the event is written without the new one,
      so the history looks complete but is not.
    * If the new column held a secret, nothing would force it to be declared `:secret` before a
      later change starts recording it.

  Nobody would notice until someone investigated an incident and found the change missing.

  With these tests, the same change fails CI with a message that names the unclassified field,
  and the developer must decide on purpose, in `Fields`: add it to one of the schema's policies
  (as `:secret` when needed) or to the schema's `excluded` with a reason.

  ## How the checks work

  Each declaration returned by `Fields.schema_sources/0` names a schema, the policies it feeds,
  the fields no policy audits (`excluded`, with the reason), and the policy keys that are not
  columns of that schema (`pseudo_keys`, such as the bulk-update key `late_policy` or subfields
  of an embed). One schema may feed several policies and one policy may draw from several
  schemas. The tests fail when:

    * a schema has a column that none of its policies audits and that is not excluded;
    * a column the schema marks `redact: true` is audited as `:value` instead of `:secret`;
    * a policy lists a field that none of its schemas has and that is not a pseudo key;
    * an exclusion names a field the schema no longer has;
    * a pseudo key is no longer listed by any of the schema's policies, or is now a real field;
    * a field is both audited and excluded in the same schema;
    * a policy is not fed by any declared schema (`account/0` is checked as the merge of
      `user_account/0` and `author_account/0`).

  `Oli.Auditing.FieldPolicyFixture` (test support) proves that each check fires.

  ## What this does not cover

    * Field origin within a policy: the checks match names. When two schemas of one policy share
      a name (for example `status` or `institution_id` in `integration`), a column of either
      counts as audited by that policy.
    * Subfields of embedded schemas that are recorded whole (`customizations`,
      `explanation_strategy`): new subfields are audited inside the embed; secret-looking
      subfield names are rejected by `Oli.Auditing.Changes.validate/2`.
    * Change fields written inline in `Oli.Auditing.EventCatalog.Definitions` (for example
      `%{locked_at: :value}` or the collaborator `role`/`status`) instead of a `Fields` policy.
    * Whether a coordinator passes the persisted before/after state to `Changes.diff/3`: each
      coordinator's own tests assert that.
  """

  use ExUnit.Case, async: true

  alias Oli.Auditing.EventCatalog.Fields

  # Arity-0 functions of Fields that are not policies.
  @not_policies [:not_secret, :schema_sources]

  for %{schema: schema} = source <- Fields.schema_sources() do
    @source source

    test "classifies every #{inspect(schema)} field" do
      assert schema_errors(@source, &policy/1) == []
    end
  end

  test "every policy field exists in one of its schemas or is a pseudo key" do
    sources = Fields.schema_sources()

    errors =
      sources
      |> Enum.flat_map(& &1.policies)
      |> Enum.uniq()
      |> Enum.flat_map(&policy_errors(&1, policy(&1), sources))

    assert errors == []
  end

  test "every policy is fed by a declared schema" do
    declared = Fields.schema_sources() |> Enum.flat_map(& &1.policies) |> MapSet.new()

    policies =
      for {name, 0} <- Fields.__info__(:functions), name not in @not_policies, do: name

    assert Fields.account() == Map.merge(Fields.user_account(), Fields.author_account())

    assert Enum.reject(policies, &(&1 in declared or &1 == :account)) == [],
           "Every Fields policy must be listed by at least one schema in Fields.schema_sources/0"
  end

  test "reports new columns, redacted values, orphaned policy fields, and stale exclusions" do
    fixture = Oli.Auditing.FieldPolicyFixture

    source = %{
      schema: fixture,
      policies: [:fixture],
      excluded: %{id: "identity", removed_column: "no longer exists"},
      pseudo_keys: %{retired_key: "no policy lists it", max_attempts: "now a real field"}
    }

    fixture_policy = %{max_attempts: :value, webhook_secret: :value, dropped_column: :value}
    lookup = fn :fixture -> fixture_policy end

    errors =
      (schema_errors(source, lookup) ++ policy_errors(:fixture, fixture_policy, [source]))
      |> Enum.join("\n")

    assert errors =~
             "#{inspect(fixture)} has fields no policy audits and not excluded: [:extra_time_multiplier]"

    assert errors =~ "redacted fields audited as values: [:webhook_secret]"

    assert errors =~
             "Fields.fixture/0 lists fields that none of its schemas has: [:dropped_column]"

    assert errors =~ "name fields that no longer exist: [:removed_column]"
    assert errors =~ "pseudo keys that none of its policies lists: [:retired_key]"
    assert errors =~ "pseudo keys that are real fields: [:max_attempts]"
  end

  defp policy(name), do: apply(Fields, name, [])

  defp schema_errors(source, lookup) do
    %{schema: schema, policies: policies, excluded: excluded, pseudo_keys: pseudo_keys} = source

    schema_fields = schema |> existing_fields() |> MapSet.new()
    redacted_fields = MapSet.new(schema.__schema__(:redact_fields))
    policy_maps = Enum.map(policies, lookup)
    audited = policy_maps |> Enum.flat_map(&Map.keys/1) |> MapSet.new()
    values = for map <- policy_maps, {field, :value} <- map, into: MapSet.new(), do: field
    excluded_fields = excluded |> Map.keys() |> MapSet.new()
    pseudo = pseudo_keys |> Map.keys() |> MapSet.new()
    columns = MapSet.new(schema.__schema__(:fields))
    names = Enum.map_join(policies, ", ", &"Fields.#{&1}/0")

    [
      {columns |> MapSet.difference(audited) |> MapSet.difference(excluded_fields),
       "#{inspect(schema)} has fields no policy audits and not excluded: %s. Add each one to " <>
         "one of #{names} (as :secret when it holds a secret) or to its exclusions in " <>
         "Fields.schema_sources/0 with a reason."},
      {MapSet.intersection(redacted_fields, values),
       "#{inspect(schema)} marks these with `redact: true`, but #{names} has redacted fields " <>
         "audited as values: %s. Declare them :secret or exclude them."},
      {MapSet.difference(excluded_fields, schema_fields),
       "Exclusions for #{inspect(schema)} name fields that no longer exist: %s."},
      {MapSet.intersection(audited, excluded_fields),
       "#{inspect(schema)} fields cannot be both audited and excluded: %s."},
      {MapSet.difference(pseudo, audited),
       "#{inspect(schema)} declares pseudo keys that none of its policies lists: %s."},
      {MapSet.intersection(pseudo, schema_fields),
       "#{inspect(schema)} declares pseudo keys that are real fields: %s. Remove them from " <>
         "its pseudo_keys."}
    ]
    |> messages()
  end

  defp policy_errors(name, policy, sources) do
    feeding = Enum.filter(sources, &(name in &1.policies))

    known =
      feeding
      |> Enum.flat_map(fn source ->
        existing_fields(source.schema) ++ Map.keys(source.pseudo_keys)
      end)
      |> MapSet.new()

    [
      {policy |> Map.keys() |> MapSet.new() |> MapSet.difference(known),
       "Fields.#{name}/0 lists fields that none of its schemas has: %s. Remove them or declare " <>
         "them as pseudo keys of one of its schemas."}
    ]
    |> messages()
  end

  # Virtual fields count as existing: a policy may audit one (such as `password`) as :secret.
  defp existing_fields(schema),
    do: schema.__schema__(:fields) ++ schema.__schema__(:virtual_fields)

  defp messages(checks) do
    checks
    |> Enum.reject(fn {fields, _message} -> MapSet.size(fields) == 0 end)
    |> Enum.map(fn {fields, message} ->
      String.replace(message, "%s", inspect(fields |> MapSet.to_list() |> Enum.sort()))
    end)
  end
end
