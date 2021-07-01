import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import {
  DeliveryElement,
  DeliveryElementProps,
  DeliveryElementProvider,
  useDeliveryElementContext,
} from '../DeliveryElement';
import { OrderingModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { configureStore } from 'state/store';
import {
  ActivityDeliveryState,
  initializeStateOrdering,
  isEvaluated,
  slice,
} from 'data/content/activities/DeliveryState';
import {
  DragDropContext,
  Draggable,
  DraggableStateSnapshot,
  DraggingStyle,
  Droppable,
  NotDraggingStyle,
} from 'react-beautiful-dnd';
import './OrderingDelivery.scss';
import { GradedPointsConnected } from 'components/activities/common/delivery/gradedPoints/GradedPointsConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/resetButton/ResetButtonConnected';
import { SubmitButtonConnected } from 'components/activities/common/delivery/submitButton/SubmitButtonConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDeliveryConnected';
import { getChoice } from 'components/activities/common/choices/authoring/choiceUtils';

export const store = configureStore({}, slice.reducer);

export const OrderingComponent: React.FC = () => {
  const {
    model,
    state: activityState,
    writerContext,
  } = useDeliveryElementContext<OrderingModelSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  useEffect(() => {
    dispatch(initializeStateOrdering(model, activityState));
  }, []);

  // First render initializes state
  if (!uiState.selectedChoices) {
    return null;
  }

  const getStyle = (
    style: DraggingStyle | NotDraggingStyle | undefined,
    snapshot: DraggableStateSnapshot,
  ) => {
    const snapshotStyle = snapshot.draggingOver ? { 'pointer-events': 'none' } : {};
    if (style?.transform) {
      const axisLockY = `translate(0px, ${style.transform.split(',').pop()}`;
      return {
        ...style,
        ...snapshotStyle,
        minHeight: 41,
        transform: axisLockY,
      };
    }
    return {
      ...style,
      ...snapshotStyle,
      minHeight: 41,
    };
  };

  return (
    <div className={`activity ordering-activity ${isEvaluated(uiState) ? 'evaluated' : ''}`}>
      <div className="activity-content">
        <StemDeliveryConnected />
        <GradedPointsConnected />
        <DragDropContext
          onDragEnd={({ destination, source }) => {
            if (
              !destination ||
              (destination.droppableId === source.droppableId && destination.index === source.index)
            ) {
              return;
            }

            const choice = uiState.selectedChoices[source.index];
            const newChoices = Array.from(uiState.selectedChoices);
            newChoices.splice(source.index, 1);
            newChoices.splice(destination.index, 0, choice);

            dispatch(slice.actions.setSelectedChoices(newChoices));
          }}
        >
          <Droppable droppableId={'choices'}>
            {(provided) => (
              <div {...provided.droppableProps} className="mt-3" ref={provided.innerRef}>
                {uiState.selectedChoices.map((choiceId, index) => (
                  <Draggable draggableId={choiceId} key={choiceId} index={index}>
                    {(provided, snapshot) => (
                      <div
                        ref={provided.innerRef}
                        {...provided.draggableProps}
                        {...provided.dragHandleProps}
                        className="d-flex mb-3 align-items-center ordering-choice-card"
                        style={getStyle(provided.draggableProps.style, snapshot)}
                        onKeyDown={(e) => {
                          const index = uiState.selectedChoices.findIndex((id) => id === choiceId);
                          const newChoices = uiState.selectedChoices.slice();
                          newChoices.splice(index, 1);
                          if (e.key === 'ArrowUp' && e.getModifierState('Shift') && index > 0) {
                            newChoices.splice(index - 1, 0, choiceId);
                            dispatch(slice.actions.setSelectedChoices(newChoices));
                          }
                          if (
                            e.key === 'ArrowDown' &&
                            e.getModifierState('Shift') &&
                            index < uiState.selectedChoices.length - 1
                          ) {
                            newChoices.splice(index + 1, 0, choiceId);
                            dispatch(slice.actions.setSelectedChoices(newChoices));
                          }
                        }}
                      >
                        <div
                          style={{
                            cursor: 'move',
                            width: 24,
                            color: 'rgba(0,0,0,0.26)',
                            marginRight: '0.5rem',
                          }}
                          className="material-icons"
                        >
                          drag_indicator
                        </div>
                        <div style={{ marginRight: '0.5rem' }}>{index + 1}.</div>
                        <HtmlContentModelRenderer
                          text={getChoice(model, choiceId).content}
                          context={writerContext}
                        />
                      </div>
                    )}
                  </Draggable>
                ))}
                {provided.placeholder}
              </div>
            )}
          </Droppable>
        </DragDropContext>
        <ResetButtonConnected />
        <SubmitButtonConnected />
        <HintsDeliveryConnected />
        <EvaluationConnected />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class OrderingDelivery extends DeliveryElement<OrderingModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<OrderingModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <OrderingComponent />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, OrderingDelivery);
