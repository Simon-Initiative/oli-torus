# GenAI Infrastructure: Design and Implementation

This document describes the design and operation of the GenAI infrastructure within Torus. This infrastructure provides flexible, runtime-configurable support for integrating multiple GenAI models from various providers, enabling features to leverage different models depending on system-level or course-section-level configurations.

## Key Capabilities

The GenAI infrastructure is designed with several core capabilities:

- **Dynamic Model Integration**: Runtime support for registering and utilizing models from multiple providers, including OpenAI, Claude, or any provider with an OpenAI-compliant API.
- **Feature-Specific Model Usage**: Different GenAI features within Torus can independently use different registered models.
- **Course-Section-Level Customization**: The ability to override default models at the individual course section level.
- **Backpressure-Aware Routing**: Admission control and circuit breakers select primary/secondary/backup models proactively and shed load when needed.
- **Fallback Mechanism**: Backup model is reserved for provider-level outages (primary + secondary breaker open).
- **Reusable Dialogue Implementation**: A clean, modular GenServer-based dialogue component suitable for use across multiple features.
- **Operational Telemetry**: Routing decisions and provider outcomes are observable via telemetry and AppSignal metrics.

## Architectural Components

### Completions Service and Provider Behavior

The core interface for interacting with GenAI models is the `Oli.GenAI.Completions` service. This module dynamically dispatches completion requests through its `generate/3` and `stream/4` functions to specific provider implementations based on configuration.

Three provider implementations currently exist:

- `Oli.GenAI.Completions.OpenAICompliantProvider`
- `Oli.GenAI.Completions.ClaudeProvider`
- `Oli.GenAI.Completions.NullProvider` (a placeholder used for development and testing)

### Registered Models

Models from GenAI providers are represented within the system using the `RegisteredModel` schema. This schema captures essential details such as provider type, model name, and the API endpoint (`url_template`). Administrators will be able to dynamically register new models via an upcoming administrative interface.

Example registrations:

```elixir
%RegisteredModel{provider: :openai, model: "gpt-4-1106-preview", url_template: "https://api.openai.com"}
%RegisteredModel{provider: :openai, model: "gpt-4.5-preview-2025-02-27", url_template: "https://api.openai.com"}
%RegisteredModel{provider: :claude, model: "claude-3-haiku-20240307", url_template: "https://api.anthropic.com"}
%RegisteredModel{provider: :openai, model: "my-fine-tuned-gemini", url_template: "https://server.undermydesk.com"}
```

The infrastructure supports integration of official foundation models and self-hosted or fine-tuned solutions seamlessly.

### Service Configuration (`ServiceConfig`)
Each GenAI-driven feature in Torus is configured through a `ServiceConfig`. A service configuration defines a primary registered model to use for a feature and can optionally specify a secondary model (capacity/health overflow) and a backup model (outage-only). This ensures graceful degradation of service if the primary provider becomes unavailable or is at capacity.

ServiceConfig only controls Primary/Secondary/Backup selection. Breaker thresholds and provider timeouts are configured per RegisteredModel so a single model has consistent behavior across all ServiceConfigs that reference it.

### Feature-Level Configuration (`GenAIFeatureConfig`)
The GenAIFeatureConfig schema associates GenAI-powered features (like student dialogue or instructor dashboards) with specific ServiceConfig instances. It allows setting a global default for each feature, with the option for individual course sections to override this default.

The schema is straightforward:

```
schema "gen_ai_feature_configs" do
  field(:feature, Ecto.Enum, values: [:student_dialogue, :instructor_dashboard])
  belongs_to :service_config, Oli.GenAI.Completions.ServiceConfig
  belongs_to :section, Oli.Delivery.Sections.Section

  timestamps(type: :utc_datetime)
end
```

For instance, the system might define a global default where the student dialogue feature (`:student_dialogue`) uses OpenAI's GPT-4 by default, with a Claude model as a fallback. A specific course section (e.g., REAL CHEM) could then override this to use a fine-tuned Gemini model, specifying OpenAI as the backup.

When a feature initializes (such as the DOT component), it retrieves both the global default and any section-specific configuration. It prioritizes the section-specific configuration, falling back to the global default as necessary.

### Dialogue Management via GenServer (`Oli.GenAI.Dialogue.Server`)
The multi-turn dialogue implementation previously embedded within UI components has been extracted into a standalone GenServer (Oli.GenAI.Dialogue.Server). This GenServer manages the lifecycle of GenAI dialogues—processing messages, handling streaming responses from GenAI providers, and dispatching tokens back to UI processes (typically Phoenix LiveView components). This modular design allows easy reuse and maintains a clear separation of concerns.

Dialogue streaming calls are routed through the execution layer described below, ensuring counters and breakers are applied consistently.

### Backpressure-Aware Routing and Execution
GenAI requests are routed dynamically at runtime based on ServiceConfig model selection, local backpressure signals, and breaker state. The main components are:

- `Oli.GenAI.Router`: Computes a `RoutingPlan` (selected model, tier, pool, reason) from request context, ServiceConfig selection, and live signals.
- `Oli.GenAI.AdmissionControl`: ETS-backed counters for per-model and per-pool inflight counts (capacity).
- `Oli.GenAI.Breaker`: Per-RegisteredModel GenServer tracking rolling error/429/latency signals and breaker state (closed/open/half_open).
- `Oli.GenAI.Execution`: Wraps provider calls, applies routing plans, releases admissions, emits telemetry, and reports outcomes to breakers.

Breaker state and counters are per-node in the initial implementation; there is no cross-node coordination. Rollout is controlled via ServiceConfig model selection updates (no new feature flag).

#### Admission Control
Admission control is enforced at the RegisteredModel and pool level:

- **RegisteredModel / Pool capacity (global protection)**  
  - Enforced via per-model and per-pool inflight caps.  
  - Prevents slow models (e.g., GPT‑5) from monopolizing capacity and protects hackney pools.

### Telemetry and Observability
Routing and provider outcomes emit telemetry events used to populate AppSignal metrics. The primary events are:

- `[:oli, :genai, :router, :decision]` (decision reason and duration)
- `[:oli, :genai, :router, :admission]` (admitted vs rejected)
- `[:oli, :genai, :provider, :stop]` (provider latency and outcome)
- `[:oli, :genai, :breaker, :state_change]` (breaker transitions)

These events are mapped to AppSignal counters and distributions for operational dashboards.

### Database Initialization and Environment Variables
When setting up or resetting the database (mix ecto.reset), migrations automatically detect environment variables for API keys (OpenAI and Anthropic). If these keys are present, appropriate RegisteredModel and ServiceConfig records are created. If absent, the system defaults to using the NullProvider, which provides basic responses for development purposes.

This design ensures that in production environments (such as Proton or Stellarator), real provider configurations will automatically be established, whereas in local or development setups, the system gracefully defaults to a no-operation provider.

### Planned Enhancements

The present design deliberately maintains backward compatibility. Deploying this infrastructure will not affect previous GenAI functionality, as default configurations replicate existing behavior, with new capabilities becoming available incrementally as administrators and course authors configure them through the forthcoming UI.

Future features (instructor facing DOT, authoring agent) will add new entries into the `Ecto.Enum` of `:features` in the `GenAIFeatureConfig` schema and default `ServiceConfig` references.
