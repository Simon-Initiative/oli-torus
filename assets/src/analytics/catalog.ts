import catalog from '../../../priv/analytics/event_catalog.json';

// Event, parameter and enum names are object keys in the catalog, so TypeScript keeps them as
// literal types and the emitter contract below is derived from the same file Elixir validates.
type Catalog = typeof catalog;
type Parameters = Catalog['context_parameters'] &
  Catalog['event_parameters'] &
  Catalog['derived_parameters'];

type ParameterName = keyof Parameters;
type ContextParameterName = keyof Catalog['context_parameters'];
type EventParameterName = keyof Catalog['event_parameters'];

export type EventName = keyof Catalog['events'];

type ValueOf<P extends ParameterName> = Parameters[P] extends { values: infer V }
  ? Extract<keyof V, string>
  : Parameters[P] extends { minimum: number }
  ? number
  : string;

type EmitterParameterName<E extends EventName> = Extract<
  keyof Catalog['events'][E]['parameters'],
  EventParameterName
>;

export type EventParams<E extends EventName> = {
  [P in EmitterParameterName<E>]: ValueOf<P>;
};

/** A catalogued event; context parameters are added by the writer, never by emitters. */
export type AnalyticsEvent = {
  [E in EventName]: [EmitterParameterName<E>] extends [never]
    ? { name: E; params?: Record<string, never> }
    : { name: E; params: EventParams<E> };
}[EventName];

export type PageArea = ValueOf<'page_area'>;
export type FileType = ValueOf<'file_type'>;
export type PreviewMode = 'preview' | 'template_preview';

export type EventContext = { [P in ContextParameterName]?: ValueOf<P> } & {
  preview_mode?: PreviewMode;
};

type Definition = {
  values?: Record<string, unknown>;
  pattern?: string;
  minimum?: number;
  derived_from?: string;
};

const hasOwn = (object: object, key: string) => Object.prototype.hasOwnProperty.call(object, key);

const groups: Record<string, Record<string, Definition>> = {
  context: catalog.context_parameters,
  event: catalog.event_parameters,
  derived: catalog.derived_parameters,
};

const events: Record<string, { parameters: Record<string, boolean> }> = catalog.events;

export const CONTEXT_PARAMETERS = Object.keys(groups.context) as ContextParameterName[];

const ALL_PARAMETERS = [
  ...CONTEXT_PARAMETERS,
  ...Object.keys(groups.event),
  ...Object.keys(groups.derived),
];

function definition(parameter: string): Definition | undefined {
  for (const group of Object.values(groups)) {
    if (hasOwn(group, parameter)) return group[parameter];
  }
  return undefined;
}

/** Whether `value` is allowed for a catalogued parameter. */
export function isValidValue(parameter: string, value: unknown): boolean {
  const spec = definition(parameter);
  if (!spec) return false;
  if (spec.values) return typeof value === 'string' && hasOwn(spec.values, value);
  if (spec.pattern) return typeof value === 'string' && new RegExp(spec.pattern).test(value);
  if (spec.minimum !== undefined) {
    return Number.isSafeInteger(value) && (value as number) >= spec.minimum;
  }
  return false;
}

/**
 * Keeps only the catalogued, valid event parameters an emitter may supply for `name`, with the
 * sorted names of dropped ones; null for uncatalogued events. Mirrors
 * `OliWeb.Analytics.Catalog.event_params/2`.
 */
export function eventParams(
  name: unknown,
  params: unknown,
): { params: Record<string, string>; dropped: string[] } | null {
  if (typeof name !== 'string' || !hasOwn(events, name)) return null;
  if (params !== undefined && (!params || typeof params !== 'object' || Array.isArray(params))) {
    return null;
  }

  const allowed = events[name].parameters;
  const kept: Record<string, string> = {};
  const dropped: string[] = [];
  for (const [key, value] of Object.entries(params || {})) {
    if (hasOwn(allowed, key) && hasOwn(groups.event, key) && isValidValue(key, value)) {
      kept[key] = value as string;
    } else {
      dropped.push(key);
    }
  }
  return { params: kept, dropped: dropped.sort() };
}

/**
 * Builds the data layer entry for a validated event. Every catalogued parameter key is present:
 * those that do not apply are explicitly undefined, so values from an earlier push cannot
 * persist in GTM's merged data model.
 */
export function dataLayerEvent(
  name: EventName,
  params: Record<string, string>,
  context: EventContext,
): Record<string, unknown> {
  const allowed = events[name].parameters;
  const entry: Record<string, unknown> = { event: name };
  for (const key of ALL_PARAMETERS) entry[key] = undefined;
  for (const key of CONTEXT_PARAMETERS) {
    if (hasOwn(allowed, key)) entry[key] = context[key];
  }
  Object.assign(entry, params);
  for (const [key, spec] of Object.entries(groups.derived)) {
    const source = spec.derived_from && params[spec.derived_from];
    const sourceValues = spec.derived_from && definition(spec.derived_from)?.values;
    if (hasOwn(allowed, key) && source && sourceValues) {
      entry[key] = (sourceValues[source] as Record<string, unknown>)[key];
    }
  }
  return entry;
}

/** Every catalogued parameter key set to undefined, for pushes that set only some of them. */
export function clearedParameters(): Record<string, undefined> {
  return Object.fromEntries(ALL_PARAMETERS.map((key) => [key, undefined]));
}
