import React, { CSSProperties, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { MarkupTree, renderFlow } from 'components/parts/janus-text-flow/TextFlow';
import './Flashcard.css';
import { getFaceNodes, stripFlashcardImageDimensions } from './flashcardContent';
import {
  FLASHCARDS_GRID_GAP_REM,
  FLASHCARD_NARROW_MIN_HEIGHT_PX,
  FlashcardItem,
  FlashcardsModel,
  MIN_CARD_WIDTH_PX,
  computeCardsPerRow,
  getFlashcardsGridGapPx,
  resolveCardHeightForLayout,
  resolveCardsPerRowBounds,
  resolveContainerWidth,
} from './schema';

export type FlashcardFlipState = {
  flippedCards: number[];
  hasCardBeenFlipped: boolean;
  allCardsFlipped: boolean;
  cardId?: string;
  isFlipped?: boolean;
};

type FlashcardsViewProps = {
  model: FlashcardsModel;
  cssBundle: 'authoring' | 'delivery';
  flipAllSignal?: number;
  onFlipStateChange?: (state: FlashcardFlipState) => void;
};

const hasNodeTag = (nodes: MarkupTree[], tag: string): boolean =>
  nodes.some((node) => node.tag === tag || hasNodeTag(node.children ?? [], tag));

const hasText = (nodes: MarkupTree[]): boolean =>
  nodes.some(
    (node) => (node.tag === 'text' && !!node.text?.trim()) || hasText(node.children ?? []),
  );

const shuffleCards = (cards: FlashcardItem[]): FlashcardItem[] => {
  const shuffled = [...cards];

  for (let i = shuffled.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }

  return shuffled;
};

type FlashcardFaceContentProps = {
  contentKeyPrefix: string;
  nodes: MarkupTree[];
};

const FlashcardFaceContent: React.FC<FlashcardFaceContentProps> = ({ contentKeyPrefix, nodes }) => {
  const containsImage = hasNodeTag(nodes, 'img');
  const containsText = hasText(nodes);

  const className = [
    'flashcard-content',
    containsImage ? 'has-image' : 'is-text-only',
    containsImage && !containsText ? 'is-image-only' : '',
  ]
    .filter(Boolean)
    .join(' ');

  const renderNodes = useMemo(() => stripFlashcardImageDimensions(nodes), [nodes]);

  return (
    <div className={className}>
      {renderNodes.map((subtree, index) =>
        renderFlow(`${contentKeyPrefix}-${index}`, subtree, {}, []),
      )}
    </div>
  );
};

export const FlashcardsView: React.FC<FlashcardsViewProps> = ({
  model,
  cssBundle,
  flipAllSignal,
  onFlipStateChange,
}) => {
  const { cards = [], flipDuration, customCss = '', customCssClass = '' } = model;

  const [flippedById, setFlippedById] = useState<Record<string, boolean>>({});
  const [, setFlippedCards] = useState<number[]>([]);
  const lastHandledFlipAllSignal = useRef(0);

  const cardNumberById = useMemo(
    () => new Map(cards.map((card, index) => [card.id, index + 1])),
    [cards],
  );

  const displayCards = useMemo(() => {
    if (!model.randomize || cssBundle !== 'delivery') {
      return cards;
    }

    return shuffleCards(cards);
  }, [cards, model.randomize, cssBundle]);

  const resizeObserverRef = useRef<ResizeObserver | null>(null);
  const [containerWidth, setContainerWidth] = useState(0);
  const [gridGapPx, setGridGapPx] = useState(() => getFlashcardsGridGapPx());
  const durationMs = typeof flipDuration === 'number' && flipDuration >= 0 ? flipDuration : 600;
  const layoutContainerWidth =
    containerWidth > 0 ? containerWidth : resolveContainerWidth(model.width);
  const cardHeightPx = resolveCardHeightForLayout(model, layoutContainerWidth, cards.length);
  const cardHeight = `${cardHeightPx}px`;

  const listRef = useCallback((element: HTMLDivElement | null) => {
    resizeObserverRef.current?.disconnect();
    resizeObserverRef.current = null;

    if (!element) {
      return;
    }

    const updateLayoutMetrics = (width: number) => {
      setContainerWidth(width);
      setGridGapPx(getFlashcardsGridGapPx(element));
    };

    updateLayoutMetrics(element.getBoundingClientRect().width);

    if (typeof ResizeObserver === 'undefined') {
      return;
    }

    const observer = new ResizeObserver(([entry]) => {
      updateLayoutMetrics(entry.contentRect.width);
    });

    observer.observe(element);
    resizeObserverRef.current = observer;
  }, []);

  useEffect(
    () => () => {
      resizeObserverRef.current?.disconnect();
    },
    [],
  );

  const bounds = useMemo(
    () => resolveCardsPerRowBounds(model),
    [model.minCardsPerRow, model.maxCardsPerRow],
  );
  const columns = useMemo(
    () => computeCardsPerRow(layoutContainerWidth, bounds, MIN_CARD_WIDTH_PX, gridGapPx),
    [layoutContainerWidth, bounds, gridGapPx],
  );

  const rootStyle = {
    '--flashcard-narrow-min-height': `${FLASHCARD_NARROW_MIN_HEIGHT_PX}px`,
    '--flashcards-gap': `${FLASHCARDS_GRID_GAP_REM}rem`,
    '--flip-duration-ms': `${durationMs}ms`,
    '--flashcard-height': cardHeight,
  } as CSSProperties;

  const listStyle = {
    '--cards-per-row': columns,
  } as CSSProperties;

  const cssFile =
    cssBundle === 'authoring'
      ? '/css/janus_flashcards_authoring.css'
      : '/css/janus_flashcards_delivery.css';

  const flipCard = (cardId: string) => {
    setFlippedById((prev) => {
      const nextIsFlipped = !prev[cardId];
      const nextFlippedById = { ...prev, [cardId]: nextIsFlipped };
      const cardNumber = cardNumberById.get(cardId);

      setFlippedCards((previousCards) => {
        const nextFlippedCards =
          cardNumber && !previousCards.includes(cardNumber)
            ? [...previousCards, cardNumber]
            : previousCards;

        onFlipStateChange?.({
          flippedCards: nextFlippedCards,
          hasCardBeenFlipped: nextFlippedCards.length > 0,
          allCardsFlipped: cards.length > 0 && nextFlippedCards.length === cards.length,
          cardId,
          isFlipped: nextIsFlipped,
        });

        return nextFlippedCards;
      });

      return nextFlippedById;
    });
  };

  useEffect(() => {
    if (
      !flipAllSignal ||
      flipAllSignal === lastHandledFlipAllSignal.current ||
      cards.length === 0
    ) {
      return;
    }

    lastHandledFlipAllSignal.current = flipAllSignal;

    const nextFlippedById = cards.reduce<Record<string, boolean>>((acc, card) => {
      acc[card.id] = true;
      return acc;
    }, {});
    const nextFlippedCards = cards.map((_card, index) => index + 1);

    setFlippedById(nextFlippedById);
    setFlippedCards(nextFlippedCards);

    onFlipStateChange?.({
      flippedCards: nextFlippedCards,
      hasCardBeenFlipped: true,
      allCardsFlipped: true,
    });
  }, [flipAllSignal, cards, onFlipStateChange]);

  const renderCard = (card: FlashcardItem, index: number) => {
    const isFlipped = !!flippedById[card.id];
    const cardNumber = cardNumberById.get(card.id) ?? index + 1;
    const visibleSide = isFlipped ? 'back' : 'front';
    const nextSide = isFlipped ? 'front' : 'back';
    const instructionsId = `flashcard-${card.id}-instructions`;

    return (
      <div key={card.id} className="flashcards-list-item" role="listitem">
        <div
          className={`flashcard${isFlipped ? ' is-flipped' : ''}`}
          onClick={() => flipCard(card.id)}
          role="button"
          tabIndex={0}
          aria-pressed={isFlipped}
          aria-describedby={instructionsId}
          onKeyDown={(e) => {
            if (e.key === 'Enter' || e.key === ' ') {
              e.preventDefault();
              flipCard(card.id);
            }
          }}
        >
          <span id={instructionsId} className="flashcard-sr-only">
            Flashcard {cardNumber}, showing {visibleSide}. Press Enter or Space to show {nextSide}.
          </span>

          <div className="flashcard-inner">
            <div className="flashcard-face flashcard-front" aria-hidden={isFlipped}>
              <FlashcardFaceContent
                contentKeyPrefix={`${card.id}-front`}
                nodes={getFaceNodes(card, 'front')}
              />
            </div>
            <div className="flashcard-face flashcard-back" aria-hidden={!isFlipped}>
              <FlashcardFaceContent
                contentKeyPrefix={`${card.id}-back`}
                nodes={getFaceNodes(card, 'back')}
              />
            </div>
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className={`janus-flashcards ${customCssClass || ''}`.trim()} style={rootStyle}>
      <style type="text/css">{`@import url(${cssFile});`}</style>
      {customCss ? <style type="text/css">{customCss}</style> : null}

      <div className="flashcards-deck">
        {cards.length === 0 ? (
          <div className="flashcards-empty">No flashcards yet</div>
        ) : (
          <div ref={listRef} className="flashcards-list" style={listStyle} role="list">
            {displayCards.map(renderCard)}
          </div>
        )}
      </div>
    </div>
  );
};
