# Reliability

## Expectations

Torus should be reliable as a long-running Phoenix application, not just as a request handler. Reliability in this system depends heavily on OTP supervision, safe recovery of background/runtime services, and support for multi-node deployment.

- OTP supervision is a primary reliability mechanism. `Oli.Application` supervises the endpoint, repo, PubSub, Oban, caches, telemetry, scheduled cleanup work, and other runtime services under a `:one_for_one` strategy.
- Background and supporting services are expected to recover without taking down the whole node when an individual process fails.
- Torus supports multi-node app server deployment and clustering rather than assuming a single-node runtime.
- Horizontal scaling is a supported deployment model through `libcluster`, including EC2-based cluster formation.
- PubSub, caching, background jobs, and section/delivery runtime concerns are part of the reliability story, not optional extras.
- The system should continue to behave predictably when one node is lost; clustering is not designed around a single irreplaceable parent node.
- Scheduled cleanup and recovery tasks matter for long-term correctness, including nonce cleanup, login hint cleanup, publication diff cleanup, and recovery of inflight analytics inventory work.

## Reliability Priorities

- keep learner-facing delivery stable even while authoring and publishing continue elsewhere
- avoid single-process bottlenecks for critical runtime concerns
- ensure background work is durable and restart-safe
- make clustered deployment a normal operating mode, not a special case
- detect and log incomplete or failing runtime work clearly enough for operators to intervene

## Canonical References

- application supervision tree and runtime services: `lib/oli/application.ex`
- horizontal scaling and clustering: `guides/starting/horizontal-scaling.md`
- operational guidance: `docs/OPERATIONS.md`
