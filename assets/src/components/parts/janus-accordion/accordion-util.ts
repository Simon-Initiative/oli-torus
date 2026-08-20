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

export const accordionThemeStyles = (themeColor?: string): CSSProperties => ({
  ['--accordion-theme' as string]: themeColor || DEFAULT_ACCORDION_THEME,
});

export const accordionContainerStyles = (
  width?: number | string,
  height?: number,
): CSSProperties => {
  const resolvedHeight = height ?? DEFAULT_ACCORDION_HEIGHT;
  const cssVar = { ['--accordion-min-height' as string]: `${resolvedHeight}px` };

  if (isResponsiveAccordionLayout(width)) {
    return { width, minHeight: resolvedHeight, height: 'auto', ...cssVar };
  }

  return { width, height: resolvedHeight, minHeight: resolvedHeight, ...cssVar };
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

  const count = clampSectionCount(normalized.length > 0 ? normalized.length : MIN_ACCORDION_SECTIONS);
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
  { key: 'openedSectionsCount', type: CapiVariableTypes.NUMBER, value: state.openedSections.length },
  { key: 'openedSections', type: CapiVariableTypes.ARRAY, value: state.openedSections },
  { key: 'expandedSections', type: CapiVariableTypes.ARRAY, value: state.expandedSections },
];

export const parseAccordionModel = (raw: unknown): AccordionModel => {
  let model: Partial<AccordionModel> = {};
  if (typeof raw === 'string') {
    try { model = JSON.parse(raw); } catch { model = {}; }
  } else if (raw && typeof raw === 'object') {
    model = raw as Partial<AccordionModel>;
  }

  return {
    ...model,
    enabled: typeof model.enabled === 'boolean' ? model.enabled : true,
    themeColor: model.themeColor || DEFAULT_ACCORDION_THEME,
    customCssClass: model.customCssClass || '',
    customCss: model.customCss || '',
    sections: normalizeSections(model.sections),
  } as AccordionModel;
};
