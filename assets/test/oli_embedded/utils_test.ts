import {
  analyzeEmbeddedXml,
  buildRuntimeAssetBase,
  buildUploadDirectory,
  buildUploadLocation,
  isBundleResourceBase,
  isEmbeddedActivityReviewMode,
  isReviewInteractionSuppressed,
  suggestAssetName,
} from 'components/activities/oli_embedded/utils';

describe('oli embedded xml diagnostics', () => {
  it('detects uploaded and unmatched references in well-formed xml', () => {
    const xml = `<?xml version="1.0" encoding="UTF-8"?>
      <embed_activity>
        <source>webcontent/custom_activity/customactivity.js</source>
        <assets>
          <asset name="layout">webcontent/custom_activity/layout.html</asset>
          <asset name="styles">webcontent/custom_activity/styles.css</asset>
        </assets>
      </embed_activity>`;

    const diagnostics = analyzeEmbeddedXml(xml, [
      'webcontent/custom_activity/customactivity.js',
      'webcontent/custom_activity/layout.html',
      'webcontent/custom_activity/questions.xml',
    ]);

    expect(diagnostics.isWellFormed).toBe(true);
    expect(diagnostics.parseError).toBeNull();
    expect(diagnostics.references).toEqual([
      'webcontent/custom_activity/customactivity.js',
      'webcontent/custom_activity/layout.html',
      'webcontent/custom_activity/styles.css',
    ]);
    expect(diagnostics.untrackedReferences).toEqual(['webcontent/custom_activity/styles.css']);
    expect(diagnostics.unusedUploads).toEqual(['webcontent/custom_activity/questions.xml']);
  });

  it('falls back to text scanning for malformed xml', () => {
    const xml = `<embed_activity><source>webcontent/custom_activity/customactivity.js</source>`;
    const diagnostics = analyzeEmbeddedXml(xml, []);

    expect(diagnostics.isWellFormed).toBe(false);
    expect(diagnostics.parseError).toBeTruthy();
    expect(diagnostics.references).toEqual(['webcontent/custom_activity/customactivity.js']);
    expect(diagnostics.untrackedReferences).toEqual([
      'webcontent/custom_activity/customactivity.js',
    ]);
  });
});

describe('oli embedded bundle helpers', () => {
  it('formats bundle-backed runtime paths', () => {
    expect(isBundleResourceBase('bundles/abc123')).toBe(true);
    expect(buildUploadDirectory('bundles/abc123')).toBe('bundles/abc123');
    expect(buildUploadLocation('bundles/abc123')).toBe('/media/bundles/abc123/webcontent/...');
    expect(buildRuntimeAssetBase('bundles/abc123')).toBe('/super_media/bundles/abc123/');
  });

  it('uses shared media upload paths for non-bundle-backed activities', () => {
    expect(buildUploadDirectory('abc123')).toBe('');
    expect(buildUploadLocation('abc123')).toBe('/media/webcontent/...');
  });

  it('normalizes suggested asset names', () => {
    expect(suggestAssetName('webcontent/custom-activity/layout.html')).toBe('layout');
    expect(suggestAssetName('webcontent/custom_activity/controls.v2.html')).toBe('controls_v2');
  });
});

describe('oli embedded review behavior', () => {
  it('allows review interaction unless it is explicitly suppressed', () => {
    expect(isReviewInteractionSuppressed({})).toBe(false);
    expect(isReviewInteractionSuppressed({ suppressReviewInteraction: false })).toBe(false);
    expect(isReviewInteractionSuppressed({ suppressReviewInteraction: true })).toBe(true);
  });

  it('recognizes only complete review route segments', () => {
    expect(isEmbeddedActivityReviewMode('review', '/sections/course/lesson/page')).toBe(true);
    expect(
      isEmbeddedActivityReviewMode(
        'delivery',
        '/sections/course/lesson/page/attempt/attempt-guid/review',
      ),
    ).toBe(true);
    expect(isEmbeddedActivityReviewMode('delivery', '/sections/review-course/lesson/page')).toBe(
      false,
    );
  });
});
