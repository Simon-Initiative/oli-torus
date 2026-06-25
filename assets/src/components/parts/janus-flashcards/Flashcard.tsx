import React, { useCallback, useEffect, useRef, useState } from 'react';
import { PartComponentProps } from 'components/parts/types/parts';
import { CapiVariableTypes } from 'adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from 'apps/delivery/components/NotificationContext';
import { parseBoolean } from 'utils/common';
import { FlashcardFlipState, FlashcardsView } from './FlashcardsView';
import {
  FlashcardsModel,
  resolveCardHeightForLayout,
  resolveContainerWidth,
  withFlashcardsLayoutDimensions,
} from './schema';

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
  const { id, model, onInit, onReady, onSave, onResize } = props;
  const [ready, setReady] = useState(false);
  const [flipAllSignal, setFlipAllSignal] = useState(0);
  const lastAutoLayoutKeyRef = useRef('');

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

  useEffect(() => {
    if (!ready) {
      return;
    }

    const layoutModel = withFlashcardsLayoutDimensions(model);
    const containerWidth = resolveContainerWidth(model.width);
    const cardCount = model.cards?.length ?? 0;
    const cardHeight = resolveCardHeightForLayout(model, containerWidth, cardCount);
    const hostHeight =
      typeof model.height === 'number' && model.height > 0 ? model.height : layoutModel.height;
    const layoutKey = [
      cardCount,
      model.width,
      model.minCardsPerRow,
      model.maxCardsPerRow,
      cardHeight,
      hostHeight,
    ].join(':');

    if (layoutKey === lastAutoLayoutKeyRef.current) {
      return;
    }

    lastAutoLayoutKeyRef.current = layoutKey;

    const styleChanges: Record<string, { value: number }> = {};
    const width =
      typeof model.width === 'number' ? model.width : parseInt(String(model.width ?? ''), 10);

    if (Number.isFinite(width) && width > 0) {
      styleChanges.width = { value: width };
    }

    if (typeof hostHeight === 'number') {
      styleChanges.height = { value: hostHeight };
    }

    styleChanges.cardHeight = { value: cardHeight };

    void onResize({ id, settings: styleChanges });
  }, [id, model, onResize, ready]);

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
