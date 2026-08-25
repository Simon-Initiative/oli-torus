import React, { useCallback, useEffect, useMemo } from 'react';
import ReactDOM from 'react-dom';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import ConfirmDelete from 'apps/authoring/components/Modal/DeleteConfirmationModal';
import {
  NotificationType,
  subscribeToNotification,
} from 'apps/delivery/components/NotificationContext';
import { clone, parseBoolean } from 'utils/common';
import guid from 'utils/guid';
import { tagName as quillEditorTagName, registerEditor } from '../janus-text-flow/QuillEditor';
import FlashcardConfigurePreview from './FlashcardConfigurePreview';
import FlashcardQuillEditor from './FlashcardQuillEditor';
import FlashcardThemePicker from './FlashcardThemePicker';
import { FlashcardsView } from './FlashcardsView';
import {
  DEFAULT_FLASHCARD_FACE_COLOR,
  FLASHCARD_PREVIEW_HEIGHT_SCALE,
  computeFlashcardCellWidth,
  nodesToPlainText,
} from './flashcard-util';
import { getFaceNodes, plainTextToDefaultNodes } from './flashcardContent';
import {
  FlashcardItem,
  FlashcardsModel,
  computeFlashcardsLayoutHeight,
  resolveCardHeight,
  resolveCardHeightForLayout,
  resolveContainerWidth,
  withFlashcardsLayoutDimensions,
} from './schema';

type FlashcardAuthorProps = AuthorPartComponentProps<FlashcardsModel> & {
  editmode?: string | boolean | number;
  layoutchanging?: string | boolean | number;
};

type PreviousLayout = {
  key: string;
  observedModelHeight?: number;
  observedModelWidth?: number | string;
  requestedHeight?: number;
};

type CardSide = 'front' | 'back';

const newCard = (label: string): FlashcardItem => ({
  id: guid(),
  frontNodes: plainTextToDefaultNodes(`${label} front`),
  backNodes: plainTextToDefaultNodes(`${label} back`),
});

const FlashcardAuthor: React.FC<AuthorPartComponentProps<FlashcardsModel>> = (props) => {
  const { id, model, configuremode, onConfigure, onSaveConfigure, onCancelConfigure, onResize } =
    props;
  const editMode = parseBoolean((props as FlashcardAuthorProps).editmode ?? props.editMode);
  const layoutChanging = parseBoolean((props as FlashcardAuthorProps).layoutchanging ?? false);
  const [inConfigureMode, setInConfigureMode] = React.useState(configuremode);
  const [activeCardId, setActiveCardId] = React.useState<string | null>(null);
  const [activeSide, setActiveSide] = React.useState<CardSide>('front');
  const [draftCards, setDraftCards] = React.useState<FlashcardItem[]>(model.cards ?? []);
  const [confirmDeleteCardId, setConfirmDeleteCardId] = React.useState<string | null>(null);
  const [portalElement, setPortalElement] = React.useState<HTMLElement | null>(null);
  const [measuredContainerWidth, setMeasuredContainerWidth] = React.useState(0);
  const previousLayoutRef = React.useRef<PreviousLayout | null>(null);
  const layoutChangingRef = React.useRef(false);
  const containerWidth =
    measuredContainerWidth > 0
      ? measuredContainerWidth
      : resolveContainerWidth(model.width, model.responsiveLayoutWidth);

  useEffect(() => {
    registerEditor();
    props.onReady({ id });
  }, []);

  useEffect(() => {
    setInConfigureMode(parseBoolean(configuremode));
  }, [configuremode]);

  useEffect(() => {
    if (!inConfigureMode) {
      setPortalElement(null);
      return;
    }

    const timeoutId = window.setTimeout(() => {
      setPortalElement(document.getElementById(props.portal));
    }, 10);

    return () => window.clearTimeout(timeoutId);
  }, [inConfigureMode, props.portal]);

  const beginConfigure = useCallback(
    (configure: boolean) => {
      setInConfigureMode(configure);

      if (configure) {
        const cards = model.cards?.length ? model.cards : [newCard('New Card')];
        setDraftCards(cards);
        setActiveCardId(cards[0].id);
        setActiveSide('front');
        setConfirmDeleteCardId(null);
        onConfigure({
          id,
          configure: true,
          context: { fullscreen: true, customClassName: 'flashcards-config-modal' },
        });
      }
    },
    [id, model.cards, onConfigure],
  );

  const handleSave = useCallback(async () => {
    const modelClone = clone(model);
    modelClone.cards = draftCards;
    modelClone.cardHeight = resolveCardHeightForLayout(
      { ...modelClone, cards: draftCards },
      containerWidth,
      draftCards.length,
    );

    await onSaveConfigure({ id, snapshot: modelClone });
    setInConfigureMode(false);
    setActiveCardId(null);
    setActiveSide('front');
    setConfirmDeleteCardId(null);
  }, [containerWidth, draftCards, id, model, onSaveConfigure]);

  const previewModel = useMemo(() => {
    const base = { ...model, cards: draftCards };
    const cardHeight = resolveCardHeightForLayout(base, containerWidth, draftCards.length);
    const autoHeight = computeFlashcardsLayoutHeight(draftCards.length, containerWidth, {
      ...base,
      cardHeight,
    });

    return {
      ...base,
      cardHeight,
      height: typeof model.height === 'number' ? model.height : autoHeight,
    };
  }, [containerWidth, model, draftCards]);

  useEffect(() => {
    if (layoutChanging) {
      layoutChangingRef.current = true;
      return;
    }

    if (!editMode || typeof onResize !== 'function') {
      return;
    }

    const layoutInteractionEnded = layoutChangingRef.current;
    layoutChangingRef.current = false;
    const layoutWidth = model.width === '100%' ? containerWidth : model.width;
    const layoutKey = [
      draftCards.length,
      layoutWidth,
      model.minCardsPerRow,
      model.maxCardsPerRow,
    ].join(':');
    const modelHeight =
      typeof model.height === 'number' && model.height > 0 ? model.height : undefined;
    const previousLayout = previousLayoutRef.current;
    const layoutChanged = previousLayout === null || layoutKey !== previousLayout.key;
    const requestedHeightApplied =
      previousLayout?.requestedHeight !== undefined &&
      modelHeight === previousLayout.requestedHeight;
    const manualHeightChanged =
      previousLayout !== null &&
      modelHeight !== previousLayout.observedModelHeight &&
      !requestedHeightApplied;
    const manualWidthChanged =
      previousLayout !== null &&
      model.width !== '100%' &&
      model.width !== previousLayout.observedModelWidth;
    const manualDimensionsChanged =
      layoutInteractionEnded || manualHeightChanged || manualWidthChanged;

    if (!layoutChanged && !manualDimensionsChanged) {
      if (previousLayout !== null && modelHeight !== previousLayout.observedModelHeight) {
        previousLayoutRef.current = {
          ...previousLayout,
          observedModelHeight: modelHeight,
          requestedHeight: requestedHeightApplied ? undefined : previousLayout.requestedHeight,
        };
      }
      return;
    }

    const autoModel = withFlashcardsLayoutDimensions(
      { ...model, cards: draftCards },
      containerWidth,
    );
    const nextHeight =
      manualDimensionsChanged && modelHeight !== undefined ? modelHeight : autoModel.height;
    const nextCardHeight =
      manualDimensionsChanged && modelHeight !== undefined
        ? resolveCardHeightForLayout(
            { ...model, cards: draftCards },
            containerWidth,
            draftCards.length,
          )
        : autoModel.cardHeight ?? resolveCardHeight(model);
    if (typeof nextHeight !== 'number') {
      return;
    }

    previousLayoutRef.current = {
      key: layoutKey,
      observedModelHeight: modelHeight,
      observedModelWidth: model.width,
      requestedHeight: nextHeight === modelHeight ? undefined : nextHeight,
    };

    void onResize({
      id,
      settings: {
        height: { value: nextHeight },
        cardHeight: { value: nextCardHeight },
      },
    });
  }, [
    draftCards.length,
    containerWidth,
    id,
    layoutChanging,
    model,
    model.maxCardsPerRow,
    model.minCardsPerRow,
    model.width,
    onResize,
    editMode,
  ]);

  const handleCancel = useCallback(() => {
    setDraftCards(model.cards ?? []);
    setInConfigureMode(false);
    setActiveCardId(null);
    setActiveSide('front');
  }, [model.cards]);

  useEffect(() => {
    if (!props.notify) return;

    const configureUnsub = subscribeToNotification(
      props.notify,
      NotificationType.CONFIGURE,
      (payload: any) => {
        if (payload?.partId === id) {
          beginConfigure(payload.configure);
        }
      },
    );

    const saveUnsub = subscribeToNotification(
      props.notify,
      NotificationType.CONFIGURE_SAVE,
      (payload: any) => {
        if (payload?.id === id) {
          handleSave();
        }
      },
    );

    const cancelUnsub = subscribeToNotification(
      props.notify,
      NotificationType.CONFIGURE_CANCEL,
      (payload: any) => {
        if (payload?.id === id) {
          handleCancel();
        }
      },
    );

    return () => {
      configureUnsub();
      saveUnsub();
      cancelUnsub();
    };
  }, [props.notify, id, beginConfigure, handleSave, handleCancel]);

  useEffect(() => {
    const handleEditorChange = (e: any) => {
      if (!inConfigureMode || !activeCardId) return;

      const wrapper = (e.target as HTMLElement | null)?.closest(
        '[data-side]',
      ) as HTMLElement | null;
      const side = wrapper?.dataset.side as CardSide | undefined;
      const cardId = wrapper?.dataset.cardId;

      if (!side || cardId !== activeCardId) {
        return;
      }

      const nodes = e.detail.payload.value;
      const field = side === 'front' ? 'frontNodes' : 'backNodes';

      setDraftCards((cards) =>
        cards.map((card) => (card.id === activeCardId ? { ...card, [field]: nodes } : card)),
      );
    };

    const handleEditorCancel = () => {
      if (!inConfigureMode) return;

      setInConfigureMode(false);
      setActiveCardId(null);
      setActiveSide('front');
      setConfirmDeleteCardId(null);
      onCancelConfigure({ id });
    };

    if (inConfigureMode) {
      document.addEventListener(`${quillEditorTagName}-change`, handleEditorChange);
      document.addEventListener(`${quillEditorTagName}-cancel`, handleEditorCancel);
    }

    return () => {
      document.removeEventListener(`${quillEditorTagName}-change`, handleEditorChange);
      document.removeEventListener(`${quillEditorTagName}-cancel`, handleEditorCancel);
    };
  }, [activeCardId, id, inConfigureMode, onCancelConfigure]);

  const activeCard = useMemo(
    () => draftCards.find((card) => card.id === activeCardId),
    [draftCards, activeCardId],
  );

  const activeCardIndex = useMemo(
    () => draftCards.findIndex((card) => card.id === activeCardId),
    [draftCards, activeCardId],
  );

  const previewCardWidth = useMemo(
    () => computeFlashcardCellWidth(containerWidth, previewModel),
    [containerWidth, previewModel],
  );

  const previewCardHeight = useMemo(() => {
    const layoutHeight = resolveCardHeightForLayout(
      previewModel,
      containerWidth,
      draftCards.length,
    );

    return Math.round(layoutHeight * FLASHCARD_PREVIEW_HEIGHT_SCALE);
  }, [containerWidth, draftCards.length, previewModel]);

  const selectCard = (cardId: string) => {
    setActiveCardId(cardId);
    setActiveSide('front');
  };

  const addCard = () => {
    const card = newCard(`Card ${draftCards.length + 1}`);
    setDraftCards((cards) => [...cards, card]);
    setActiveCardId(card.id);
    setActiveSide('front');
  };

  const deleteCard = (cardId: string) => {
    setDraftCards((cards) => {
      const nextCards = cards.filter((card) => card.id !== cardId);

      if (activeCardId === cardId) {
        setActiveCardId(nextCards[0]?.id ?? null);
        setActiveSide('front');
      }

      return nextCards;
    });
  };

  const confirmDeleteCard = () => {
    if (!confirmDeleteCardId) {
      return;
    }

    deleteCard(confirmDeleteCardId);
    setConfirmDeleteCardId(null);
  };

  const confirmDeleteCardIndex = confirmDeleteCardId
    ? draftCards.findIndex((card) => card.id === confirmDeleteCardId)
    : -1;
  const confirmDeleteCardName =
    confirmDeleteCardIndex >= 0 ? `Card ${confirmDeleteCardIndex + 1}` : 'this card';

  const updateActiveCardTheme = (themeColor: string | undefined) => {
    if (!activeCardId) return;

    setDraftCards((cards) =>
      cards.map((card) => {
        if (card.id !== activeCardId) {
          return card;
        }

        if (!themeColor) {
          const { themeColor: _removed, ...rest } = card;
          return rest;
        }

        return { ...card, themeColor };
      }),
    );
  };

  const configureContent =
    inConfigureMode && portalElement
      ? ReactDOM.createPortal(
          <div className="flashcards-configure">
            <div className="fc-config-header">
              <span className="fc-config-header-title">Flashcard deck</span>
              <span className="fc-config-header-count">
                {draftCards.length} {draftCards.length === 1 ? 'card' : 'cards'}
              </span>
            </div>

            <div className="fc-config-body">
              <aside className="fc-config-list">
                <button type="button" className="fc-config-add-btn" onClick={addCard}>
                  + Add card
                </button>

                <div className="fc-config-card-list">
                  {draftCards.map((card, index) => {
                    const previewText =
                      nodesToPlainText(getFaceNodes(card, 'front')) || 'Empty front';

                    return (
                      <div
                        key={card.id}
                        className={`fc-config-card-item${
                          card.id === activeCardId ? ' is-active' : ''
                        }`}
                        role="button"
                        tabIndex={0}
                        onClick={() => selectCard(card.id)}
                        onKeyDown={(event) => {
                          if (event.key === 'Enter' || event.key === ' ') {
                            event.preventDefault();
                            selectCard(card.id);
                          }
                        }}
                      >
                        <span
                          className="fc-config-card-strip"
                          style={{ background: card.themeColor || DEFAULT_FLASHCARD_FACE_COLOR }}
                        />
                        <div className="fc-config-card-body">
                          <div className="fc-config-card-item-header">
                            <span className="fc-config-card-item-title">CARD {index + 1}</span>
                            <button
                              type="button"
                              className="fc-config-card-delete"
                              aria-label="Delete card"
                              title="Delete card"
                              onClick={(event) => {
                                event.stopPropagation();
                                setConfirmDeleteCardId(card.id);
                              }}
                            >
                              <i className="fa fa-trash-alt" aria-hidden="true" />
                            </button>
                          </div>
                          <span className="fc-config-card-preview">{previewText}</span>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </aside>

              <main className="fc-config-editor">
                {activeCard && activeCardId ? (
                  <>
                    <div className="fc-config-editor-top">
                      <div className="fc-config-editor-title-block">
                        <h4 className="fc-config-editor-heading">
                          Editing card {activeCardIndex + 1}
                        </h4>
                        <p className="fc-config-editor-sub">
                          Front and back save together — theme applies to both sides.
                        </p>
                      </div>

                      <FlashcardThemePicker
                        compact
                        value={activeCard.themeColor}
                        onChange={updateActiveCardTheme}
                      />
                    </div>

                    <div className="fc-side-switch" role="tablist" aria-label="Card side">
                      <button
                        type="button"
                        role="tab"
                        aria-selected={activeSide === 'front'}
                        className={`fc-side-option${activeSide === 'front' ? ' active' : ''}`}
                        onClick={() => setActiveSide('front')}
                      >
                        Front
                        <span className="fc-side-option-tag">Shown first</span>
                      </button>
                      <button
                        type="button"
                        role="tab"
                        aria-selected={activeSide === 'back'}
                        className={`fc-side-option${activeSide === 'back' ? ' active' : ''}`}
                        onClick={() => setActiveSide('back')}
                      >
                        Back
                        <span className="fc-side-option-tag">Revealed on flip</span>
                      </button>
                    </div>

                    <FlashcardQuillEditor
                      card={activeCard}
                      cardId={activeCardId}
                      activeSide={activeSide}
                    />
                  </>
                ) : (
                  <div className="fc-config-editor-empty">No card selected</div>
                )}
              </main>

              <aside className="fc-config-preview-pane">
                <FlashcardConfigurePreview
                  card={activeCard}
                  cardNumber={activeCardIndex + 1}
                  activeSide={activeSide}
                  onSideChange={setActiveSide}
                  cardWidthPx={previewCardWidth}
                  cardHeightPx={previewCardHeight}
                  flipDuration={model.flipDuration}
                />
              </aside>
            </div>
          </div>,
          portalElement,
        )
      : null;

  return (
    <>
      <FlashcardsView
        model={previewModel}
        cssBundle="authoring"
        onLayoutWidthChange={setMeasuredContainerWidth}
      />
      {configureContent}
      {confirmDeleteCardId && (
        <ConfirmDelete
          show={!!confirmDeleteCardId}
          elementType="card"
          elementName={`"${confirmDeleteCardName}"`}
          explanation="This cannot be undone."
          deleteHandler={confirmDeleteCard}
          cancelHandler={() => setConfirmDeleteCardId(null)}
        />
      )}
    </>
  );
};
export default FlashcardAuthor;
