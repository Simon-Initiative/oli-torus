import React, { useCallback, useEffect, useState } from 'react';
import { PartComponentProps } from 'components/parts/types/parts';
import { CapiVariableTypes } from 'adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from 'apps/delivery/components/NotificationContext';
import { parseBoolean } from 'utils/common';
import { FlashcardFlipState, FlashcardsView } from './FlashcardsView';
import { FlashcardsModel } from './schema';

type PrimitiveChanges = Record<string, string | number | boolean>;

const buildFlipResponses = (
  state: Pick<FlashcardFlipState, 'flippedCards' | 'hasCardBeenFlipped' | 'allCardsFlipped'>,
) => [
  { key: 'flippedCards', type: CapiVariableTypes.ARRAY, value: state.flippedCards },
  {
    key: 'hasCardBeenFlipped',
    type: CapiVariableTypes.BOOLEAN,
    value: state.hasCardBeenFlipped,
  },
  {
    key: 'allCardsFlipped',
    type: CapiVariableTypes.BOOLEAN,
    value: state.allCardsFlipped,
  },
  { key: 'flipAllCards', type: CapiVariableTypes.BOOLEAN, value: false },
];

const Flashcard: React.FC<PartComponentProps<FlashcardsModel>> = (props) => {
  const { id, model, onInit, onReady, onSave } = props;
  const [ready, setReady] = useState(false);
  const [flipAllSignal, setFlipAllSignal] = useState(0);

  useEffect(() => {
    if (!props.notify) return;

    const handleChanges = (changes: PrimitiveChanges) => {
      const flipAll = changes[`stage.${id}.flipAllCards`];

      if (flipAll !== undefined && parseBoolean(flipAll)) {
        setFlipAllSignal((value) => value + 1);
      }
    };

    const stateUnsub = subscribeToNotification(
      props.notify,
      NotificationType.STATE_CHANGED,
      (payload: any) => handleChanges(payload.mutateChanges || {}),
    );

    const contextUnsub = subscribeToNotification(
      props.notify,
      NotificationType.CONTEXT_CHANGED,
      (payload: any) => handleChanges(payload.initStateFacts || {}),
    );

    return () => {
      stateUnsub();
      contextUnsub();
    };
  }, [props.notify, id]);

  useEffect(() => {
    let mounted = true;

    const initialize = async () => {
      try {
        await onInit({
          id,
          responses: buildFlipResponses({
            flippedCards: [],
            hasCardBeenFlipped: false,
            allCardsFlipped: false,
          }),
        });
        if (!mounted) {
          return;
        }
        setReady(true);
        await onReady({ id, responses: [] });
      } catch {
        if (mounted) {
          setReady(false);
        }
      }
    };

    void initialize();

    return () => {
      mounted = false;
    };
  }, [id, onInit, onReady]);

  const handleFlipStateChange = useCallback(
    (state: FlashcardFlipState) => {
      onSave({
        id,
        responses: buildFlipResponses(state),
      });
    },
    [id, onSave],
  );

  return ready ? (
    <FlashcardsView
      model={model}
      cssBundle="delivery"
      flipAllSignal={flipAllSignal}
      onFlipStateChange={handleFlipStateChange}
    />
  ) : null;
};

export default Flashcard;
