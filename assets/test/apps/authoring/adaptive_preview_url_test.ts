import { buildAdaptivePreviewUrl } from 'apps/authoring/Authoring';

describe('buildAdaptivePreviewUrl', () => {
  test('adds preview_sequence_id for adaptive preview handoff', () => {
    expect(buildAdaptivePreviewUrl('/authoring/project/demo/preview/page-slug', 'screen_2')).toBe(
      '/authoring/project/demo/preview/page-slug?preview_sequence_id=screen_2',
    );
  });

  test('preserves existing query params when adding preview_sequence_id', () => {
    expect(
      buildAdaptivePreviewUrl('/authoring/project/demo/preview/page-slug?foo=bar', 'screen_2'),
    ).toBe('/authoring/project/demo/preview/page-slug?foo=bar&preview_sequence_id=screen_2');
  });

  test('returns the original url when there is no selected sequence', () => {
    expect(buildAdaptivePreviewUrl('/authoring/project/demo/preview/page-slug')).toBe(
      '/authoring/project/demo/preview/page-slug',
    );
  });
});
