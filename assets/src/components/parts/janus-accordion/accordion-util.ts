import { CSSProperties } from 'react';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { parseArray } from '../../../utils/common';
import { MarkupTree } from '../janus-text-flow/TextFlow';
import {
  AccordionModel,
  AccordionSection,
  DEFAULT_ACCORDION_HEIGHT,
  DEFAULT_ACCORDION_THEME,
  MAX_ACCORDION_SECTIONS,
  MIN_ACCORDION_SECTIONS,
  clampSectionCount,
  createDefaultSection,
  plainTextToDefaultNodes,
} from './schema';

export {
  DEFAULT_ACCORDION_HEIGHT,
  DEFAULT_ACCORDION_THEME,
  MAX_ACCORDION_SECTIONS,
  MIN_ACCORDION_SECTIONS,
  clampSectionCount,
};

export const isResponsiveAccordionLayout = (width?: number | string): boolean =>
  width === '100%' || (typeof width === 'string' && width.includes('%'));

export const accordionLayoutClass = (width?: number | string): string =>
  isResponsiveAccordionLayout(width) ? 'janus-accordion--responsive' : 'janus-accordion--fixed';

const parseColorToRgb = (color: string): { r: number; g: number; b: number } | null => {
  const trimmed = color.trim();
  if (!trimmed) return null;

  if (trimmed.startsWith('#')) {
    const hex = trimmed.slice(1);
    if (hex.length === 3) {
      return {
        r: parseInt(hex[0] + hex[0], 16),
        g: parseInt(hex[1] + hex[1], 16),
        b: parseInt(hex[2] + hex[2], 16),
      };
    }
    if (hex.length === 6) {
      return {
        r: parseInt(hex.slice(0, 2), 16),
        g: parseInt(hex.slice(2, 4), 16),
        b: parseInt(hex.slice(4, 6), 16),
      };
    }
    return null;
  }

  const rgbaMatch = trimmed.match(/^rgba?\(([^)]+)\)$/i);
  if (rgbaMatch) {
    const parts = rgbaMatch[1].split(',').map((part) => part.trim());
    const [r, g, b] = parts.map((part) => parseFloat(part));
    if ([r, g, b].every((channel) => Number.isFinite(channel))) {
      return { r, g, b };
    }
  }

  return null;
};

export const hasAccordionTheme = (themeColor?: string): boolean => Boolean(themeColor?.trim());

export const accordionHeaderContrastColor = (themeColor: string): string => {
  const rgb = parseColorToRgb(themeColor);
  if (!rgb) return '#262626';

  const luminance = (0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b) / 255;
  return luminance > 0.5 ? '#262626' : '#ffffff';
};

export const accordionThemeStyles = (themeColor?: string): CSSProperties => {
  if (!hasAccordionTheme(themeColor)) return {};

  return {
    ['--accordion-theme' as string]: themeColor!.trim(),
    ['--accordion-header-fg' as string]: accordionHeaderContrastColor(themeColor!),
  };
};

// model.height is the minimum collapsed height floor, not a maximum cap.
export const accordionMinHeight = (height?: number): number => height ?? DEFAULT_ACCORDION_HEIGHT;

export const accordionContainerStyles = (
  width?: number | string,
  height?: number,
): CSSProperties => {
  const minHeight = accordionMinHeight(height);
  const cssVar = { ['--accordion-min-height' as string]: `${minHeight}px` };

  return {
    width,
    minHeight,
    height: 'auto',
    ...cssVar,
  };
};

const parseNodes = (nodes: unknown): MarkupTree[] => {
  if (!nodes) return plainTextToDefaultNodes('');
  if (typeof nodes === 'string') {
    try {
      const parsed = JSON.parse(nodes) as MarkupTree[];
      return Array.isArray(parsed) && parsed.length > 0 ? parsed : plainTextToDefaultNodes('');
    } catch {
      return plainTextToDefaultNodes('');
    }
  }
  return Array.isArray(nodes) && nodes.length > 0
    ? (nodes as MarkupTree[])
    : plainTextToDefaultNodes('');
};

export const normalizeSections = (sections: unknown): AccordionSection[] => {
  const raw = Array.isArray(sections) ? sections : [];
  const normalized = raw
    .filter((s) => s && typeof s === 'object')
    .map((s: any, i) => ({
      id: s.id || `accordion-section-${i + 1}`,
      title: typeof s.title === 'string' ? s.title : `Section ${i + 1}`,
      contentNodes: parseNodes(s.contentNodes),
    }));

  const count = clampSectionCount(
    normalized.length > 0 ? normalized.length : MIN_ACCORDION_SECTIONS,
  );
  const next = normalized.slice(0, count);
  while (next.length < count) {
    next.push(createDefaultSection(next.length + 1));
  }
  return next;
};

export const uniqueSortedIndexes = (indexes: number[]): number[] =>
  [...new Set(indexes)].sort((a, b) => a - b);

export const parseSectionIndexes = (val: unknown, sectionCount: number): number[] => {
  const parsed = parseArray(val);
  const indexes = parsed
    .map((item) => (typeof item === 'number' ? item : parseInt(String(item).replace(/"/g, ''), 10)))
    .filter((n) => Number.isFinite(n) && n >= 1 && n <= sectionCount);
  return uniqueSortedIndexes(indexes);
};

export const getSectionPreviewText = (nodes: MarkupTree[] | undefined): string => {
  const walk = (node: MarkupTree | MarkupTree[] | undefined): string => {
    if (!node) return '';
    if (Array.isArray(node)) return node.map(walk).join('');
    const own = node.tag === 'text' ? node.text || '' : '';
    const children = node.children ? node.children.map(walk).join('') : '';
    return `${own}${children}`;
  };
  return walk(nodes).trim();
};

export type AccordionCapiState = {
  enabled: boolean;
  userOpened: boolean;
  openedSections: number[];
  expandedSections: number[];
};

export const buildResponses = (state: AccordionCapiState) => [
  { key: 'enabled', type: CapiVariableTypes.BOOLEAN, value: state.enabled },
  { key: 'userOpened', type: CapiVariableTypes.BOOLEAN, value: state.userOpened },
  {
    key: 'openedSectionsCount',
    type: CapiVariableTypes.NUMBER,
    value: state.openedSections.length,
  },
  { key: 'openedSections', type: CapiVariableTypes.ARRAY, value: state.openedSections },
  { key: 'expandedSections', type: CapiVariableTypes.ARRAY, value: state.expandedSections },
];

export const parseAccordionModel = (raw: unknown): AccordionModel => {
  let model: Partial<AccordionModel> = {};
  if (typeof raw === 'string') {
    try {
      model = JSON.parse(raw);
    } catch {
      model = {};
    }
  } else if (raw && typeof raw === 'object') {
    model = raw as Partial<AccordionModel>;
  }

  return {
    ...model,
    enabled: typeof model.enabled === 'boolean' ? model.enabled : true,
    themeColor: typeof model.themeColor === 'string' ? model.themeColor : '',
    customCssClass: model.customCssClass || '',
    customCss: model.customCss || '',
    sections: normalizeSections(model.sections),
  } as AccordionModel;
};
