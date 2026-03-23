import {
  decodeSourceConfig,
  transformModelToSchema,
  transformSchemaToModel,
} from 'components/parts/janus-capi-iframe/schema';

describe('janus-capi-iframe source schema transforms', () => {
  it('encodes legacy external src into source config for editor', () => {
    const transformed = transformModelToSchema({
      src: 'https://example.com/widget',
      allowScrolling: true,
    });

    expect(typeof transformed.source).toBe('string');
    const sourceConfig = decodeSourceConfig(transformed.source);
    expect(sourceConfig.mode).toBe('url');
    expect(sourceConfig.url).toBe('https://example.com/widget');
  });

  it('encodes page metadata into source config for editor', () => {
    const transformed = transformModelToSchema({
      src: '/course/link/introduction',
      sourceType: 'page',
      idref: 27,
      sourcePageSlug: 'introduction',
    });

    const sourceConfig = decodeSourceConfig(transformed.source);
    expect(sourceConfig.mode).toBe('page');
    expect(sourceConfig.pageId).toBe(27);
    expect(sourceConfig.pageSlug).toBe('introduction');
  });

  it('maps page source config back to model fields', () => {
    const transformed = transformSchemaToModel({
      source: JSON.stringify({
        mode: 'page',
        pageId: 44,
        pageSlug: 'module-1',
        url: '',
      }),
      allowScrolling: false,
    }) as any;

    expect(transformed.src).toBe('/course/link/module-1');
    expect(transformed.sourceType).toBe('page');
    expect(transformed.linkType).toBe('page');
    expect(transformed.idref).toBe(44);
    expect(transformed.resource_id).toBe(44);
    expect(transformed).not.toHaveProperty('source');
  });

  it('maps url source config back to model fields', () => {
    const transformed = transformSchemaToModel({
      source: JSON.stringify({
        mode: 'url',
        pageId: null,
        pageSlug: '',
        url: 'https://oli.example/content',
      }),
      allowScrolling: false,
    }) as any;

    expect(transformed.src).toBe('https://oli.example/content');
    expect(transformed.sourceType).toBe('url');
    expect(transformed).not.toHaveProperty('source');
  });

  it('keeps url mode when legacy linkType is still present', () => {
    const transformed = transformModelToSchema({
      src: 'https://oli.example/content',
      sourceType: 'url',
      linkType: 'page',
      idref: 44,
      sourcePageSlug: 'module-1',
    });

    const sourceConfig = decodeSourceConfig(transformed.source);
    expect(sourceConfig.mode).toBe('url');
    expect(sourceConfig.url).toBe('https://oli.example/content');
  });

  it('uses resource_id as page id fallback for editor source config', () => {
    const transformed = transformModelToSchema({
      src: '/course/link/module-1',
      sourceType: 'page',
      resource_id: 44,
      sourcePageSlug: 'module-1',
    });

    const sourceConfig = decodeSourceConfig(transformed.source);
    expect(sourceConfig.mode).toBe('page');
    expect(sourceConfig.pageId).toBe(44);
    expect(sourceConfig.pageSlug).toBe('module-1');
  });

  it('clears internal link metadata when switching from page mode to url mode', () => {
    const existing = {
      src: '/course/link/module-1',
      sourceType: 'page' as const,
      linkType: 'page' as const,
      idref: 44,
      sourcePageSlug: 'module-1',
      resource_id: 44,
      dynamicLinkFallback: {
        type: 'unresolved_internal_source' as const,
        message: 'old',
        href: '/sections/demo/lesson/current',
      },
    };

    const transformed = transformSchemaToModel({
      ...existing,
      source: JSON.stringify({
        mode: 'url',
        pageId: null,
        pageSlug: '',
        url: 'https://oli.example/content',
      }),
    }) as any;

    const merged = { ...existing, ...transformed };

    expect(merged.src).toBe('https://oli.example/content');
    expect(merged.sourceType).toBe('url');
    expect(merged.linkType).toBeUndefined();
    expect(merged.idref).toBeUndefined();
    expect(merged.resource_id).toBeUndefined();
    expect(merged.sourcePageSlug).toBeUndefined();
    expect(merged.dynamicLinkFallback).toBeUndefined();
  });
});
