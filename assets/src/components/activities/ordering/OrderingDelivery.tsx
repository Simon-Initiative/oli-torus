import React, { useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import {
  DeliveryElement,
  DeliveryElementProps,
  EvaluationResponse,
  RequestHintResponse,
  ResetActivityResponse,
} from '../DeliveryElement';
import { OrderingModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import { Stem } from '../common/DisplayedStem';
import { Hints } from '../common/DisplayedHints';
import { Reset } from '../common/Reset';
import { Evaluation } from '../common/delivery/evaluation/Evaluation';
import { IconCorrect, IconIncorrect } from 'components/misc/Icons';
import { defaultWriterContext, WriterContext } from 'data/content/writers/context';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { configureStore } from 'state/store';
import {
  ActivityDeliveryState,
  initializeState,
  isEvaluated,
  reset,
  selectChoice,
  slice,
  submit,
} from 'data/content/activities/DeliveryState';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { GradedPoints } from 'components/activities/common/GradedPoints';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { ResetButton } from 'components/activities/common/delivery/ResetButton';
import { SubmitButton } from 'components/activities/common/SubmitButton';
import { HintsDelivery } from 'components/activities/common/hints/delivery/HintsDelivery';
import { requestHint } from 'data/content/activities/delivery/hintsState';
import { Checkbox } from 'components/activities/common/icons/Checkbox';
import {
  DragDropContext,
  Draggable,
  DraggableStateSnapshot,
  DraggingStyle,
  Droppable,
  NotDraggingStyle,
} from 'react-beautiful-dnd';
import './OrderingDelivery.scss';

export const store = configureStore({}, slice.reducer);

type Evaluation = {
  score: number;
  outOf: number;
  feedback: ActivityTypes.RichText;
};

// [id, index]
type Selection = [ActivityTypes.ChoiceId, number];

interface SelectionProps {
  selected: Selection[];
  onDeselect: (id: ActivityTypes.ChoiceId) => void;
  isEvaluated: boolean;
}

const Selection = ({ selected, onDeselect, isEvaluated }: SelectionProps) => {
  const id = (selection: Selection) => selection[0];
  const index = (selection: Selection) => selection[1];
  return (
    <div className="mb-2" style={{ height: 34, borderBottom: '3px solid #333' }}>
      {selected.map((selection) => (
        <button
          key={id(selection)}
          onClick={() => onDeselect(id(selection))}
          disabled={isEvaluated}
          className="choice-index mr-1"
        >
          {index(selection) + 1}
        </button>
      ))}
    </div>
  );
};

interface ChoicesProps {
  choices: ActivityTypes.Choice[];
  selected: ActivityTypes.ChoiceId[];
  context: WriterContext;
  onSelect: (id: string) => void;
  isEvaluated: boolean;
}

const Choices = ({ choices, selected, context, onSelect, isEvaluated }: ChoicesProps) => {
  const isSelected = (choiceId: string) => !!selected.find((s) => s === choiceId);
  return (
    <div className="choices" aria-label="ordering choices">
      {choices.map((choice, index) => (
        <Choice
          key={choice.id}
          onClick={() => onSelect(choice.id)}
          selected={isSelected(choice.id)}
          choice={choice}
          context={context}
          isEvaluated={isEvaluated}
          index={index}
        />
      ))}
    </div>
  );
};

interface ChoiceProps {
  choice: ActivityTypes.Choice;
  index: number;
  selected: boolean;
  context: WriterContext;
  onClick: () => void;
  isEvaluated: boolean;
}

const Choice = ({ choice, index, selected, context, onClick, isEvaluated }: ChoiceProps) => {
  return (
    <div
      key={choice.id}
      aria-label={`choice ${index + 1}`}
      onClick={isEvaluated ? undefined : onClick}
      className={`choice ${selected ? 'selected' : ''}`}
    >
      <span className="choice-index">{index + 1}</span>
      <HtmlContentModelRenderer text={choice.content} context={context} />
    </div>
  );
};

export const OrderingComponent = (props: DeliveryElementProps<OrderingModelSchema>) => {
  const state = useSelector(
    (state: ActivityDeliveryState & { model: ActivityTypes.HasStem & ActivityTypes.HasChoices }) =>
      state,
  );
  const dispatch = useDispatch();
  const [showDragIndicator, setShowDragIndicator] = useState(false);

  useEffect(() => {
    dispatch(initializeState(props.model, props.state));
  }, []);

  // First render initializes state
  if (!state.model) {
    return null;
  }

  const {
    attemptState,
    model: { stem, choices },
    selectedChoices,
    hints,
    hasMoreHints,
  } = state;

  const writerContext = defaultWriterContext({ sectionSlug: props.sectionSlug });

  const isCorrect = attemptState.score !== 0;
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
    <div className={`activity ordering-activity ${isEvaluated(state) ? 'evaluated' : ''}`}>
      <div className="activity-content">
        <StemDelivery stem={stem} context={writerContext} />
        <GradedPoints
          shouldShow={props.graded && props.review}
          icon={isCorrect ? <IconCorrect /> : <IconIncorrect />}
          attemptState={attemptState}
        />
        {/* <ChoicesDelivery
          unselectedIcon={<Checkbox.Unchecked />}
          selectedIcon={
            !isEvaluated(state) ? (
              <Checkbox.Checked />
            ) : isCorrect ? (
              <Checkbox.Correct />
            ) : (
              <Checkbox.Incorrect />
            )
          }
          choices={choices}
          selected={selectedChoices}
          onSelect={(id) => dispatch(selectChoice(id, props.onSaveActivity))}
          isEvaluated={isEvaluated(state)}
          context={writerContext}
        /> */}
        <DragDropContext
          onDragEnd={({ destination, source }) => {
            if (
              !destination ||
              (destination.droppableId === source.droppableId && destination.index === source.index)
            ) {
              return;
            }

            const choice = choices[source.index];
            const newChoices = Array.from(choices);
            newChoices.splice(source.index, 1);
            newChoices.splice(destination.index, 0, choice);

            dispatch(slice.actions.setSelectedChoices(newChoices.map((c) => c.id)));
          }}
        >
          <Droppable droppableId={'choices'}>
            {(provided) => (
              <div {...provided.droppableProps} className="mt-3" ref={provided.innerRef}>
                {choices.map((choice, index) => (
                  <Draggable draggableId={choice.id} key={choice.id} index={index}>
                    {(provided, snapshot) => (
                      <div
                        ref={provided.innerRef}
                        {...provided.draggableProps}
                        {...provided.dragHandleProps}
                        className="d-flex mb-3 align-items-center ordering-choice-card"
                        style={getStyle(provided.draggableProps.style, snapshot)}
                      >
                        <div
                          style={{
                            cursor: 'move',
                            width: 24,
                            color: 'rgba(0,0,0,0.26)',
                          }}
                          className="material-icons"
                        >
                          drag_indicator
                        </div>
                        <HtmlContentModelRenderer text={choice.content} context={writerContext} />
                      </div>
                    )}
                  </Draggable>
                ))}
                {provided.placeholder}
              </div>
            )}
          </Droppable>
        </DragDropContext>
        <ResetButton
          shouldShow={isEvaluated(state) && !props.graded}
          disabled={!attemptState.hasMoreAttempts}
          onClick={() => dispatch(reset(props.onResetActivity))}
        />
        <SubmitButton
          shouldShow={!isEvaluated(state) && !props.graded}
          disabled={selectedChoices.length === 0}
          onClick={() => dispatch(submit(props.onSubmitActivity))}
        />
        <HintsDelivery
          shouldShow={!isEvaluated(state) && !props.graded}
          onClick={() => dispatch(requestHint(props.onRequestHint))}
          hints={hints}
          hasMoreHints={hasMoreHints}
          isEvaluated={isEvaluated(state)}
          context={writerContext}
        />
        <Evaluation
          shouldShow={isEvaluated(state) && (!props.graded || props.review)}
          attemptState={attemptState}
          context={writerContext}
        />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class OrderingDelivery extends DeliveryElement<OrderingModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<OrderingModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <OrderingComponent {...props} />
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, OrderingDelivery);
