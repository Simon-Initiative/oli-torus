import React, { CSSProperties } from 'react';
import { FlashcardFaceContent } from './FlashcardsView';
import { flashcardThemeStyles } from './flashcard-util';
import { getFaceNodes } from './flashcardContent';
import { FlashcardItem } from './schema';

type CardSide = 'front' | 'back';

type FlashcardConfigurePreviewProps = {
  card: FlashcardItem | undefined;
  cardNumber: number;
  activeSide: CardSide;
  onSideChange: (side: CardSide) => void;
  cardWidthPx: number;
  cardHeightPx: number;
  flipDuration?: number;
};

const FlashcardConfigurePreview: React.FC<FlashcardConfigurePreviewProps> = ({
  card,
  cardNumber,
  activeSide,
  onSideChange,
  cardWidthPx,
  cardHeightPx,
  flipDuration = 600,
}) => {
  if (!card) {
    return <div className="fc-config-preview-empty">Select a card to preview</div>;
  }

  const durationMs = typeof flipDuration === 'number' && flipDuration >= 0 ? flipDuration : 600;
  const faceStyle = flashcardThemeStyles(card.themeColor);
  const isFlipped = activeSide === 'back';
  const deckStyle = {
    ['--flashcard-min-height' as string]: `${cardHeightPx}px`,
    ['--flashcard-height' as string]: '100%',
    ['--flip-duration-ms' as string]: `${durationMs}ms`,
    width: `${cardWidthPx}px`,
  } as CSSProperties;
  const listStyle = {
    '--cards-per-row': 1,
  } as CSSProperties;

  const toggleFlip = () => {
    onSideChange(activeSide === 'front' ? 'back' : 'front');
  };

  const visibleSide = isFlipped ? 'back' : 'front';
  const nextSide = isFlipped ? 'front' : 'back';
  const sideBadgeLabel = activeSide === 'front' ? 'Front' : 'Back';

  return (
    <div className="fc-config-preview">
      <div className="fc-config-preview-label">Live preview</div>
      <div className="fc-config-preview-sub">This is what learners will see.</div>
      <div className="fc-config-preview-frame">
        <div className="janus-flashcards fc-config-preview-deck" style={deckStyle}>
          <style type="text/css">{`@import url(/css/janus_flashcards_authoring.css);`}</style>
          <div className="flashcards-deck">
            <div className="flashcards-list" style={listStyle} role="presentation">
              <div className="flashcards-list-item">
                <div
                  className={`flashcard fc-config-preview-card${isFlipped ? ' is-flipped' : ''}`}
                  onClick={toggleFlip}
                  role="button"
                  tabIndex={0}
                  aria-pressed={isFlipped}
                  onKeyDown={(event) => {
                    if (event.key === 'Enter' || event.key === ' ') {
                      event.preventDefault();
                      toggleFlip();
                    }
                  }}
                >
                  <span className="flashcard-sr-only">
                    Flashcard {cardNumber}, showing {visibleSide}. Press Enter or Space to show{' '}
                    {nextSide}.
                  </span>

                  <span className="fc-config-preview-side-badge" aria-hidden="true">
                    {sideBadgeLabel}
                  </span>

                  <div className="flashcard-inner">
                    <div
                      className="flashcard-face flashcard-front"
                      style={faceStyle}
                      aria-hidden={isFlipped}
                    >
                      <FlashcardFaceContent
                        contentKeyPrefix={`${card.id}-preview-front`}
                        nodes={getFaceNodes(card, 'front')}
                      />
                    </div>
                    <div
                      className="flashcard-face flashcard-back"
                      style={faceStyle}
                      aria-hidden={!isFlipped}
                    >
                      <FlashcardFaceContent
                        contentKeyPrefix={`${card.id}-preview-back`}
                        nodes={getFaceNodes(card, 'back')}
                      />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="fc-config-preview-hint">
          <i className="fa fa-rotate-right" aria-hidden="true" />
          Click the card to flip it
        </div>
      </div>
    </div>
  );
};

export default FlashcardConfigurePreview;
