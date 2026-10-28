import React, { useEffect, useRef, useState } from 'react';
import { tagName as quillEditorTagName } from '../janus-text-flow/QuillEditor';
import { getFaceNodes } from './flashcardContent';
import { FlashcardItem } from './schema';

type CardSide = 'front' | 'back';

type FlashcardQuillEditorProps = {
  card: FlashcardItem;
  cardId: string;
  activeSide: CardSide;
};

const EDITOR_READY_FALLBACK_MS = 3000;

const FlashcardQuillEditor: React.FC<FlashcardQuillEditorProps> = ({
  card,
  cardId,
  activeSide,
}) => {
  const [isLoading, setIsLoading] = useState(true);
  const stackRef = useRef<HTMLDivElement>(null);
  const previousCardIdRef = useRef<string | null>(null);

  useEffect(() => {
    const cardChanged = previousCardIdRef.current !== cardId;
    previousCardIdRef.current = cardId;

    if (!cardChanged) {
      return;
    }

    setIsLoading(true);
    const root = stackRef.current;
    if (!root) {
      return;
    }

    const isReady = () => root.querySelectorAll('.ql-toolbar.ql-snow').length >= 2;

    if (isReady()) {
      setIsLoading(false);
      return;
    }

    const observer = new MutationObserver(() => {
      if (isReady()) {
        setIsLoading(false);
        observer.disconnect();
      }
    });

    observer.observe(root, { childList: true, subtree: true });

    const fallbackTimer = window.setTimeout(() => {
      setIsLoading(false);
      observer.disconnect();
    }, EDITOR_READY_FALLBACK_MS);

    return () => {
      observer.disconnect();
      window.clearTimeout(fallbackTimer);
    };
  }, [cardId]);

  const renderEditor = (side: CardSide) =>
    React.createElement(quillEditorTagName, {
      key: `${cardId}-${side}`,
      tree: JSON.stringify(getFaceNodes(card, side)),
      showimagecontrol: true,
    });

  return (
    <div className="fc-config-quill-stack" ref={stackRef}>
      {isLoading ? (
        <div className="fc-config-quill-skeleton" aria-hidden="true">
          <div className="fc-config-quill-skeleton-toolbar">
            {Array.from({ length: 8 }, (_, index) => (
              <span key={index} className="fc-config-quill-skeleton-chip" />
            ))}
          </div>
          <div className="fc-config-quill-skeleton-body">
            <span className="fc-config-quill-skeleton-line" />
            <span className="fc-config-quill-skeleton-line is-short" />
          </div>
        </div>
      ) : null}

      <div
        className={`fc-config-quill-wrap${activeSide === 'front' ? ' is-active' : ''}`}
        data-side="front"
        data-card-id={cardId}
        aria-hidden={activeSide !== 'front'}
      >
        {renderEditor('front')}
      </div>

      <div
        className={`fc-config-quill-wrap${activeSide === 'back' ? ' is-active' : ''}`}
        data-side="back"
        data-card-id={cardId}
        aria-hidden={activeSide !== 'back'}
      >
        {renderEditor('back')}
      </div>
    </div>
  );
};

export default FlashcardQuillEditor;
