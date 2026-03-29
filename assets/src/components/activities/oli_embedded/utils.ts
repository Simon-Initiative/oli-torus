import guid from 'utils/guid';
import { ScoringStrategy, makeStem } from '../types';
import { OliEmbeddedModelSchema } from './schema';

export type EmbeddedXmlDiagnostics = {
  isWellFormed: boolean;
  parseError: string | null;
  references: string[];
  untrackedReferences: string[];
  unusedUploads: string[];
};

export const defaultEmbeddedModel: () => OliEmbeddedModelSchema = () => {
  return {
    base: 'embedded',
    src: 'index.html',
    modelXml: `<?xml version="1.0" encoding="UTF-8"?>
    <embed_activity id="custom_side" width="670" height="300">
        <title>Custom Activity</title>
        <source>webcontent/custom_activity/customactivity.js</source>
        <assets>
            <asset name="layout">webcontent/custom_activity/layout.html</asset>
            <asset name="controls">webcontent/custom_activity/controls.html</asset>
            <asset name="styles">webcontent/custom_activity/styles.css</asset>
            <asset name="questions">webcontent/custom_activity/questions.xml</asset>
        </assets>
    </embed_activity>`,
    resourceBase: guid(),
    resourceURLs: [],
    resourceVerification: {},
    stem: makeStem(''),
    title: 'Embedded activity',
    authoring: {
      parts: [
        {
          id: guid(),
          scoringStrategy: ScoringStrategy.average,
          responses: [],
          hints: [],
        },
        {
          id: guid(),
          scoringStrategy: ScoringStrategy.average,
          responses: [],
          hints: [],
        },
      ],
      previewText: '',
    },
  };
};

export function isBundleResourceBase(resourceBase: string): boolean {
  return resourceBase.includes('bundles/');
}

export function buildUploadDirectory(resourceBase: string): string {
  const normalized = resourceBase.replace(/^\/+/, '');

  if (normalized.length === 0) {
    return '';
  }

  return isBundleResourceBase(normalized) ? normalized : `bundles/${normalized}`;
}

export function buildUploadLocation(resourceBase: string): string {
  const directory = buildUploadDirectory(resourceBase);
  return directory.length > 0 ? `/media/${directory}/webcontent/...` : '/media/webcontent/...';
}

export function buildRuntimeAssetBase(resourceBase: string): string {
  return isBundleResourceBase(resourceBase) ? `/super_media/${resourceBase}/` : '/super_media/';
}

export function lastPart(resourceBase: string, path: string): string {
  if (isBundleResourceBase(resourceBase)) {
    return path.substring(path.lastIndexOf('webcontent'));
  }
  if (path.includes('media/')) {
    return path.substring(path.lastIndexOf('media/') + 6);
  }
  return path.substring(path.lastIndexOf('/') + 1);
}

export function suggestAssetName(path: string): string {
  const fileName = path.split('/').pop() || 'asset';
  const baseName = fileName.replace(/\.[^.]+$/, '');
  const normalized = baseName.replace(/[^a-zA-Z0-9_-]+/g, '_').replace(/^_+|_+$/g, '');
  return normalized.length > 0 ? normalized : 'asset';
}

export function analyzeEmbeddedXml(xml: string, uploadedPaths: string[]): EmbeddedXmlDiagnostics {
  const parseError = parseXmlError(xml);
  const references =
    parseError === null ? extractReferencesFromXml(xml) : extractReferencesFromText(xml);

  const uploadedReferenceSet = new Set(uploadedPaths.map((path) => normalizeForComparison(path)));
  const xmlReferenceSet = new Set(references.map((path) => normalizeForComparison(path)));

  const untrackedReferences = references.filter((path) => {
    if (isExternalReference(path)) {
      return false;
    }

    return !uploadedReferenceSet.has(normalizeForComparison(path));
  });

  const unusedUploads = uploadedPaths.filter(
    (path) => !xmlReferenceSet.has(normalizeForComparison(path)),
  );

  return {
    isWellFormed: parseError === null,
    parseError,
    references,
    untrackedReferences,
    unusedUploads,
  };
}

function parseXmlError(xml: string): string | null {
  if (typeof DOMParser !== 'function') {
    return null;
  }

  try {
    const doc = new DOMParser().parseFromString(xml, 'application/xml');
    const error = doc.querySelector('parsererror');
    return error ? error.textContent?.replace(/\s+/g, ' ').trim() || 'XML parse error' : null;
  } catch {
    return 'Unable to parse XML.';
  }
}

function extractReferencesFromXml(xml: string): string[] {
  if (typeof DOMParser !== 'function') {
    return extractReferencesFromText(xml);
  }

  const doc = new DOMParser().parseFromString(xml, 'application/xml');
  const refs = new Set<string>();

  Array.from(doc.getElementsByTagName('*')).forEach((element) => {
    Array.from(element.attributes).forEach((attribute) => {
      maybeAddReference(refs, attribute.value);
    });

    if (element.children.length === 0) {
      maybeAddReference(refs, element.textContent || '');
    }
  });

  return Array.from(refs);
}

function extractReferencesFromText(xml: string): string[] {
  const refs = new Set<string>();
  const matches = xml.match(
    /\b(?:webcontent|media|bundles)\/[A-Za-z0-9_./-]+\.[A-Za-z0-9]{1,8}\b/g,
  );

  (matches || []).forEach((match) => maybeAddReference(refs, match));

  return Array.from(refs);
}

function maybeAddReference(refs: Set<string>, rawValue: string) {
  const normalized = normalizeReference(rawValue);
  if (normalized) {
    refs.add(normalized);
  }
}

function normalizeReference(rawValue: string): string | null {
  const trimmed = rawValue.trim();

  if (trimmed.length === 0) {
    return null;
  }

  const withoutQuotes = trimmed.replace(/^['"]|['"]$/g, '');
  const withoutCdata = withoutQuotes.replace(/^<!\[CDATA\[/, '').replace(/\]\]>$/, '');
  const normalized = withoutCdata.replace(/^\/+/, '');

  if (isExternalReference(normalized)) {
    return null;
  }

  if (!looksLikeReference(normalized)) {
    return null;
  }

  return normalized;
}

function looksLikeReference(value: string): boolean {
  return (
    value.startsWith('webcontent/') ||
    value.startsWith('media/') ||
    value.startsWith('bundles/') ||
    /(^|\/)[^/\s]+\.[A-Za-z0-9]{1,8}(?:[?#].*)?$/.test(value)
  );
}

function isExternalReference(value: string): boolean {
  return /^(https?:|data:|javascript:|#)/i.test(value);
}

function normalizeForComparison(value: string): string {
  return value.replace(/^\/+/, '').replace(/[?#].*$/, '');
}
