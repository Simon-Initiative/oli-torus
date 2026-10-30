# Regenerates docs/design-docs/audit-log-events.md from the event catalog and examples.
#
#     MIX_ENV=test mix run test/support/audit_log_event_reference.exs

path = Oli.Auditing.EventReference.path()
File.write!(path, Oli.Auditing.EventReference.render())
Mix.shell().info("Wrote #{path}")
