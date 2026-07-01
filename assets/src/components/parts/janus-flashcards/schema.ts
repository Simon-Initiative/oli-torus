import { JSONSchema7Object } from 'json-schema';
import { CapiVariableTypes } from 'adaptivity/capi';
import {
  DEFAULT_ADAPTIVE_CORRECT_FEEDBACK,
  DEFAULT_ADAPTIVE_INCORRECT_FEEDBACK,
} from '../adaptiveFeedbackDefaults';
import { MarkupTree } from '../janus-text-flow/TextFlow';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface FlashcardsModel extends JanusAbsolutePositioned, JanusCustomCss {
  customCssClass: string;
  enabled: boolean;
  randomize: boolean;
  flipDuration: number;
  cardHeight?: number;
  cards: FlashcardItem[];
  minCardsPerRow: number;
  maxCardsPerRow: number;
  correctFeedback: string;
  incorrectFeedback: string;
}

export interface FlashcardItem {
  id: string;
  frontNodes?: MarkupTree[];
  backNodes?: MarkupTree[];
}

export const MIN_CARDS_PER_ROW = 1;
export const MAX_CARDS_PER_ROW = 6;
export const MIN_CARDS_PER_ROW_DEFAULT = 1;
export const MAX_CARDS_PER_ROW_DEFAULT = 3;
export const MIN_CARD_WIDTH_PX = 180;
export const FLASHCARDS_GRID_GAP_REM = 1;
export const FLASHCARD_NARROW_CONTAINER_MAX_PX = 480;
export const FLASHCARD_NARROW_MIN_HEIGHT_PX = 140;
export const DEFAULT_CARD_HEIGHT_PX = 180;
export const DEFAULT_LAYOUT_WIDTH_PX = 480;
export const FLASHCARDS_EMPTY_MIN_HEIGHT_PX = 120;

const effectiveCardFaceHeight = (cardHeight: number, containerWidth: number): number => {
  if (containerWidth > 0 && containerWidth <= FLASHCARD_NARROW_CONTAINER_MAX_PX) {
    return Math.max(cardHeight, FLASHCARD_NARROW_MIN_HEIGHT_PX);
  }

  return cardHeight;
};

export const resolveContainerWidth = (width?: number | string): number => {
  if (typeof width === 'number' && width > 0) {
    return width;
  }

  if (width === '100%') {
    return 960;
  }

  return DEFAULT_LAYOUT_WIDTH_PX;
};

export const resolveCardHeight = (
  model: Pick<FlashcardsModel, 'cardHeight' | 'height'>,
): number => {
  if (typeof model.cardHeight === 'number' && model.cardHeight > 0) {
    return model.cardHeight;
  }

  if (
    typeof model.height === 'number' &&
    model.height > 0 &&
    model.height <= DEFAULT_CARD_HEIGHT_PX * 1.5
  ) {
    return model.height;
  }

  return DEFAULT_CARD_HEIGHT_PX;
};

export const resolveCardHeightForLayout = (
  model: FlashcardsModel,
  containerWidth: number,
  cardCount: number,
): number => {
  if (cardCount === 0) {
    return resolveCardHeight(model);
  }

  const storedCardHeight = resolveCardHeight(model);
  const autoHeight = computeFlashcardsLayoutHeight(cardCount, containerWidth, model);
  const layoutHeight =
    typeof model.height === 'number' && model.height > 0 ? model.height : autoHeight;

  if (Math.abs(layoutHeight - autoHeight) <= 1) {
    return effectiveCardFaceHeight(storedCardHeight, containerWidth);
  }

  const bounds = resolveCardsPerRowBounds(model);
  const columns = computeCardsPerRow(containerWidth, bounds);
  const rows = Math.ceil(cardCount / columns);
  const gap = getFlashcardsGridGapPx();
  const derived = (layoutHeight - Math.max(0, rows - 1) * gap) / rows;
  const minFaceHeight =
    containerWidth > 0 && containerWidth <= FLASHCARD_NARROW_CONTAINER_MAX_PX
      ? FLASHCARD_NARROW_MIN_HEIGHT_PX
      : 48;

  return Math.max(minFaceHeight, Math.round(derived));
};

export const computeFlashcardsLayoutHeight = (
  cardCount: number,
  containerWidth: number,
  model: Pick<FlashcardsModel, 'minCardsPerRow' | 'maxCardsPerRow' | 'cardHeight' | 'height'>,
): number => {
  if (cardCount === 0) {
    return FLASHCARDS_EMPTY_MIN_HEIGHT_PX;
  }

  const cardHeight = effectiveCardFaceHeight(resolveCardHeight(model), containerWidth);
  const bounds = resolveCardsPerRowBounds(model);
  const columns = computeCardsPerRow(containerWidth, bounds);
  const rows = Math.ceil(cardCount / columns);
  const gap = getFlashcardsGridGapPx();

  return rows * cardHeight + Math.max(0, rows - 1) * gap;
};

export const withFlashcardsLayoutDimensions = (model: FlashcardsModel): FlashcardsModel => {
  const cards = model.cards ?? [];
  const cardHeight = resolveCardHeight(model);
  const containerWidth = resolveContainerWidth(model.width);

  return {
    ...model,
    cardHeight,
    height: computeFlashcardsLayoutHeight(cards.length, containerWidth, {
      ...model,
      cardHeight,
    }),
  };
};

export const getFlashcardsGridGapPx = (element?: Element | null): number => {
  if (typeof document === 'undefined') {
    return 16;
  }

  if (element) {
    const { columnGap, gap } = getComputedStyle(element);
    const gapPx = parseFloat(columnGap || gap);
    if (Number.isFinite(gapPx) && gapPx > 0) {
      return gapPx;
    }
  }

  const rootFontSize = parseFloat(getComputedStyle(document.documentElement).fontSize);
  return Number.isFinite(rootFontSize) ? rootFontSize * FLASHCARDS_GRID_GAP_REM : 16;
};

export const clampCardsPerRow = (value: unknown): number => {
  const n = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(n)) {
    return MIN_CARDS_PER_ROW;
  }
  return Math.min(MAX_CARDS_PER_ROW, Math.max(MIN_CARDS_PER_ROW, Math.round(n)));
};

export const resolveCardsPerRowBounds = (
  model: Pick<FlashcardsModel, 'minCardsPerRow' | 'maxCardsPerRow'>,
) => {
  const min = clampCardsPerRow(model.minCardsPerRow ?? MIN_CARDS_PER_ROW_DEFAULT);
  const max = clampCardsPerRow(model.maxCardsPerRow ?? MAX_CARDS_PER_ROW_DEFAULT);
  return { min: Math.min(min, max), max: Math.max(min, max) };
};

export const computeCardsPerRow = (
  containerWidth: number,
  bounds: { min: number; max: number },
  minCardWidth = MIN_CARD_WIDTH_PX,
  gapPx = getFlashcardsGridGapPx(),
): number => {
  if (containerWidth <= 0) return bounds.min;
  const ideal = Math.floor((containerWidth + gapPx) / (minCardWidth + gapPx));
  return clampCardsPerRow(Math.min(bounds.max, Math.max(bounds.min, ideal)));
};

export const schema: JSONSchema7Object = {
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    default: true,
  },
  customCssClass: {
    title: 'CSS Classes',
    type: 'string',
  },
  customCss: {
    title: 'Custom CSS',
    type: 'string',
  },
  randomize: {
    title: 'Randomize Cards',
    type: 'boolean',
    default: false,
  },
  minCardsPerRow: {
    title: 'Min Cards per Row',
    description: 'Keep at 1 for best accessibility and readability on mobile and narrow screens.',
    type: 'number',
    minimum: MIN_CARDS_PER_ROW,
    maximum: MAX_CARDS_PER_ROW,
    default: MIN_CARDS_PER_ROW_DEFAULT,
  },
  maxCardsPerRow: {
    title: 'Max Cards per Row',
    type: 'number',
    minimum: MIN_CARDS_PER_ROW,
    maximum: MAX_CARDS_PER_ROW,
    default: MAX_CARDS_PER_ROW_DEFAULT,
  },
  flipDuration: {
    title: 'Flip duration (ms)',
    type: 'number',
    minimum: 0,
    default: 600,
  },
};

export const uiSchema = {
  cards: { 'ui:widget': 'hidden' },
};

export const getCapabilities = () => ({
  configure: true,
});

export const adaptivitySchema = ({ currentModel }: { currentModel: any }) => {
  const adaptivitySchema: Record<string, unknown> = {};
  adaptivitySchema.flippedCards = CapiVariableTypes.ARRAY;
  adaptivitySchema.hasCardBeenFlipped = CapiVariableTypes.BOOLEAN;
  adaptivitySchema.allCardsFlipped = CapiVariableTypes.BOOLEAN;
  adaptivitySchema.flipAllCards = CapiVariableTypes.BOOLEAN;

  return adaptivitySchema;
};

export const createSchema = (): Partial<FlashcardsModel> => {
  const cardHeight = DEFAULT_CARD_HEIGHT_PX;
  const width = DEFAULT_LAYOUT_WIDTH_PX;
  const layoutModel = {
    minCardsPerRow: MIN_CARDS_PER_ROW_DEFAULT,
    maxCardsPerRow: MAX_CARDS_PER_ROW_DEFAULT,
    cardHeight,
    height: cardHeight,
  };

  return {
    width,
    cardHeight,
    height: computeFlashcardsLayoutHeight(0, width, layoutModel),
    cssClasses: '',
    randomize: false,
    minCardsPerRow: MIN_CARDS_PER_ROW_DEFAULT,
    maxCardsPerRow: MAX_CARDS_PER_ROW_DEFAULT,
    flipDuration: 600,
    correctFeedback: DEFAULT_ADAPTIVE_CORRECT_FEEDBACK,
    incorrectFeedback: DEFAULT_ADAPTIVE_INCORRECT_FEEDBACK,
  };
};
