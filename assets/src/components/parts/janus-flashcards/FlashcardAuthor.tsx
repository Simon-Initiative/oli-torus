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
import { FlashcardItem, FlashcardsModel } from './schema';

type ActiveEdit = {
  cardId: string;
  side: 'front' | 'back';
};

const newCard = (label: string): FlashcardItem => ({
  id: guid(),
  frontNodes: plainTextToDefaultNodes(`${label} front`),
  backNodes: plainTextToDefaultNodes(`${label} back`),
});

const FlashcardAuthor: React.FC<AuthorPartComponentProps<FlashcardsModel>> = (props) => {
  const { id, model, configuremode, onConfigure, onSaveConfigure, onCancelConfigure } = props;
  const [inConfigureMode, setInConfigureMode] = React.useState(configuremode);
  const [activeEdit, setActiveEdit] = React.useState<ActiveEdit | null>(null);
  const [draftCards, setDraftCards] = React.useState<FlashcardItem[]>(model.cards ?? []);
  const [portalElement, setPortalElement] = React.useState<HTMLElement | null>(null);

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
        onConfigure({ id, configure: true, context: { fullscreen: true } });
      }
    },
    [id, model.cards, onConfigure],
  );

  const handleSave = useCallback(async () => {
    const modelClone = clone(model);
    modelClone.cards = draftCards;

    await onSaveConfigure({ id, snapshot: modelClone });
    setInConfigureMode(false);
    setActiveEdit(null);
  }, [draftCards, id, model, onSaveConfigure]);

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
      <FlashcardsView model={{ ...model, cards: draftCards }} cssBundle="authoring" />
      {configureContent}
    </>
  );
};
export default FlashcardAuthor;
