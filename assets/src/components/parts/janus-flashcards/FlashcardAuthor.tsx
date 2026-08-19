import React, { useCallback, useEffect, useMemo } from 'react';
import ReactDOM from 'react-dom';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import {
  NotificationType,
  subscribeToNotification,
} from 'apps/delivery/components/NotificationContext';
import { clone, parseBoolean } from 'utils/common';
import guid from 'utils/guid';
import { tagName as quillEditorTagName, registerEditor } from '../janus-text-flow/QuillEditor';
import { FlashcardsView } from './FlashcardsView';
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

type ActiveEdit = {
  cardId: string;
  side: 'front' | 'back';
};

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
  const [activeEdit, setActiveEdit] = React.useState<ActiveEdit | null>(null);
  const [draftCards, setDraftCards] = React.useState<FlashcardItem[]>(model.cards ?? []);
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
        setActiveEdit({ cardId: cards[0].id, side: 'front' });
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
    setActiveEdit(null);
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
    setActiveEdit(null);
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
      if (!inConfigureMode || !activeEdit) return;

      const nodes = e.detail.payload.value;
      const field = activeEdit.side === 'front' ? 'frontNodes' : 'backNodes';

      setDraftCards((cards) =>
        cards.map((card) => (card.id === activeEdit.cardId ? { ...card, [field]: nodes } : card)),
      );
    };

    const handleEditorCancel = () => {
      if (!inConfigureMode) return;

      setInConfigureMode(false);
      setActiveEdit(null);
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
  }, [activeEdit, id, inConfigureMode, onCancelConfigure]);

  const activeCard = useMemo(
    () => draftCards.find((card) => card.id === activeEdit?.cardId),
    [draftCards, activeEdit],
  );

  const addCard = () => {
    const card = newCard(`Card ${draftCards.length + 1}`);
    setDraftCards((cards) => [...cards, card]);
    setActiveEdit({ cardId: card.id, side: 'front' });
  };

  const deleteCard = (cardId: string) => {
    setDraftCards((cards) => {
      const nextCards = cards.filter((card) => card.id !== cardId);

      if (activeEdit?.cardId === cardId) {
        const nextActive = nextCards[0];
        setActiveEdit(nextActive ? { cardId: nextActive.id, side: 'front' } : null);
      }

      return nextCards;
    });
  };

  const configureContent =
    inConfigureMode && portalElement
      ? ReactDOM.createPortal(
          <div className="flashcards-configure" style={{ padding: 20, minWidth: 720 }}>
            <div style={{ display: 'flex', gap: 20 }}>
              <div style={{ width: 220 }}>
                <button type="button" className="btn btn-primary btn-sm" onClick={addCard}>
                  Add card
                </button>

                <div style={{ marginTop: 12 }}>
                  {draftCards.map((card, index) => (
                    <div key={card.id} style={{ marginBottom: 12 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                        <strong>Card {index + 1}</strong>
                        <button
                          type="button"
                          className="btn btn-link btn-sm text-danger"
                          onClick={() => deleteCard(card.id)}
                        >
                          Delete
                        </button>
                      </div>

                      <button
                        type="button"
                        className="btn btn-outline-secondary btn-sm mr-1"
                        onClick={() => setActiveEdit({ cardId: card.id, side: 'front' })}
                      >
                        Front
                      </button>

                      <button
                        type="button"
                        className="btn btn-outline-secondary btn-sm"
                        onClick={() => setActiveEdit({ cardId: card.id, side: 'back' })}
                      >
                        Back
                      </button>
                    </div>
                  ))}
                </div>
              </div>

              <div style={{ flex: 1 }}>
                {activeCard && activeEdit ? (
                  <>
                    <h4>
                      Editing {activeEdit.side} of card{' '}
                      {draftCards.findIndex((card) => card.id === activeCard.id) + 1}
                    </h4>

                    {React.createElement(quillEditorTagName, {
                      key: `${activeCard.id}-${activeEdit.side}`,
                      tree: JSON.stringify(getFaceNodes(activeCard, activeEdit.side)),
                      showimagecontrol: true,
                    })}
                  </>
                ) : (
                  <div>No card selected</div>
                )}
              </div>
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
    </>
  );
};
export default FlashcardAuthor;
