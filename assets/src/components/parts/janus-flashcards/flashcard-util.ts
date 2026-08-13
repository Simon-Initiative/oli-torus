import { CSSProperties } from 'react';
import { MarkupTree } from '../janus-text-flow/TextFlow';
import {
  MIN_CARD_WIDTH_PX,
  computeCardsPerRow,
  getFlashcardsGridGapPx,
  resolveCardsPerRowBounds,
} from './schema';

export const FLASHCARD_PREVIEW_HEIGHT_SCALE = 1.5;

export const FLASHCARD_THEME_PRESETS = [
  { id: 'coral', color: 'rgba(255,107,107,1)' },
  { id: 'amber', color: 'rgba(245,158,11,1)' },
  { id: 'teal', color: 'rgba(20,184,166,1)' },
  { id: 'indigo', color: 'rgba(99,102,241,1)' },
  { id: 'violet', color: 'rgba(139,92,246,1)' },
  { id: 'slate', color: 'rgba(100,116,139,1)' },
] as const;

export const DEFAULT_FLASHCARD_FACE_COLOR = '#ffffff';

export const DEFAULT_FLASHCARD_THEME = FLASHCARD_THEME_PRESETS[3].color;

export const presetThemeColorForIndex = (index: number): string =>
  FLASHCARD_THEME_PRESETS[index % FLASHCARD_THEME_PRESETS.length].color;

const normalizeColor = (value: string): string => value.replace(/\s+/g, '').toLowerCase();

export const isDefaultThemeColor = (value?: string): boolean => !value;

export const isPresetThemeColor = (value?: string): boolean =>
  !!value &&
  FLASHCARD_THEME_PRESETS.some((preset) => normalizeColor(preset.color) === normalizeColor(value));

export const flashcardThemeStyles = (themeColor?: string): CSSProperties => {
  if (!themeColor) {
    return {};
  }

  return {
    ['--flashcard-face-bg' as string]: themeColor,
    background: themeColor,
  };
};

export const nodesToPlainText = (nodes: MarkupTree[]): string => {
  const parts: string[] = [];

  const walk = (node: MarkupTree) => {
    if (node.tag === 'text' && node.text?.trim()) {
      parts.push(node.text.trim());
    }

    (node.children ?? []).forEach(walk);
  };

  nodes.forEach(walk);

  return parts.join(' ').replace(/\s+/g, ' ').trim();
};

export const computeFlashcardCellWidth = (
  containerWidth: number,
  model: { minCardsPerRow?: number; maxCardsPerRow?: number },
  gapPx = getFlashcardsGridGapPx(),
): number => {
  if (containerWidth <= 0) {
    return MIN_CARD_WIDTH_PX;
  }

  const bounds = resolveCardsPerRowBounds(model);
  const columns = computeCardsPerRow(containerWidth, bounds, MIN_CARD_WIDTH_PX, gapPx);

  return Math.max(
    MIN_CARD_WIDTH_PX,
    Math.floor((containerWidth - Math.max(0, columns - 1) * gapPx) / columns),
  );
};
