import parityCases from '../../../test/support/fixtures/analytics_event_catalog_parity.json';
import { clearedParameters, dataLayerEvent, eventParams } from '../../src/analytics/catalog';

const defined = (entry: Record<string, unknown>) =>
  Object.fromEntries(Object.entries(entry).filter(([, value]) => value !== undefined));

describe('analytics catalog', () => {
  // The same cases run through OliWeb.Analytics.Catalog in
  // test/oli_web/analytics/catalog_test.exs, so both emitters validate identically.
  test.each(
    parityCases as { description: string; name: string; params: unknown; expected: unknown }[],
  )('$description validates like the Elixir emitter', ({ name, params, expected }) => {
    expect(eventParams(name, params)).toEqual(expected);
  });

  test('omitted parameters are an empty set', () => {
    expect(eventParams('page_entered', undefined)).toEqual({ params: {}, dropped: [] });
  });

  test('entries add only the context catalogued for the event and derive feature areas', () => {
    const context = {
      user_role: 'learner',
      page_area: 'delivery',
      course_id: 42,
      page_type: 'graded',
      entry_point: 'lti',
      preview_mode: 'preview',
    } as const;

    expect(defined(dataLayerEvent('course_entered', {}, context))).toEqual({
      event: 'course_entered',
      user_role: 'learner',
      page_area: 'delivery',
      course_id: 42,
      entry_point: 'lti',
    });

    const entry = dataLayerEvent('feature_used', { feature_name: 'notes_opened' }, context);
    expect(defined(entry)).toEqual({
      event: 'feature_used',
      user_role: 'learner',
      page_area: 'delivery',
      course_id: 42,
      page_type: 'graded',
      feature_name: 'notes_opened',
      feature_area: 'notes',
    });
    expect(Object.keys(entry).sort()).toEqual(
      ['event', ...Object.keys(clearedParameters())].sort(),
    );
  });
});
