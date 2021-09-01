import React from 'react';
import ReactDOM from 'react-dom';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
  useAuthoringElementContext,
} from '../AuthoringElement';
import { MultiInputSchema } from './schema';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { AddResourceContent } from 'components/content/add_resource_content/AddResourceContent';
import { MultiInputActions } from 'components/activities/multi_input/actions';
import { zip } from 'utils/common';
import {
  MultiInput,
  MultiInputType,
  multiInputTypeFriendly,
  multiInputTypes,
} from 'components/activities/multi_input/utils';
import { getPartById, getParts } from 'data/activities/model/utils1';
import { RemoveButtonConnected } from 'components/activities/common/authoring/removeButton/RemoveButton';
import { Card } from 'components/misc/Card';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { hintsByPart } from 'data/activities/model/hintUtils';
import { CognitiveHints } from 'components/activities/common/hints/authoring/HintsAuthoring';
import { HintActions } from 'components/activities/common/hints/authoring/hintActions';
import { makeHint, Manifest } from 'components/activities/types';
import { MultiInputStem } from 'components/activities/multi_input/sections/delivery/MultiInputStem';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { DropdownQuestionEditor } from 'components/activities/multi_input/sections/authoring/DropdownQuestionEditor';
import { InputQuestionEditor } from 'components/activities/multi_input/sections/authoring/InputQuestionEditor';

const store = configureStore();

const MultiInput = () => {
  const { dispatch, model, editMode } = useAuthoringElementContext<MultiInputSchema>();

  console.log('model', model);

  // Always display model.stems[0]
  // then zip stems.slice(1) with model.inputs => the sizes should match, because we insert a stem after each input

  const addResourceContent = (index: number) => (
    <div className="activities">
      {multiInputTypes.map((type) => {
        return (
          <button
            className="btn btn-sm insert-activity-btn"
            key={type}
            onClick={(_e) => dispatch(MultiInputActions.addPart(type, index))}
          >
            {multiInputTypeFriendly(type)}
          </button>
        );
      })}
    </div>
  );

  const friendlyType = (type: MultiInputType) => {
    if (type === 'dropdown') {
      return 'Dropdown';
    }
    return 'Fill in the blank';
  };

  const inputNumberings = (inputs: MultiInput[]): { type: string; number: number }[] => {
    return inputs.reduce(
      (acc, input) => {
        const type = friendlyType(input.type);

        if (!acc.seenCount[type]) {
          acc.seenCount[type] = 1;
          acc.numberings.push({ type, number: 1 });
          return acc;
        }
        acc.seenCount[type] = acc.seenCount[type] + 1;
        acc.numberings.push({ type, number: acc.seenCount[type] });
        return acc;
      },
      { seenCount: {}, numberings: [] } as any,
    ).numberings;
  };

  const friendlyTitle = (numbering: any) => {
    return numbering.type + ' ' + numbering.number;
  };

  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <div className="flex-grow-1 mb-3">
            <RichTextEditorConnected
              text={model.stems[0].content}
              onEdit={(content) =>
                dispatch(MultiInputActions.editStemAndPreviewText(content, model.stems[0].id))
              }
              placeholder="Question before your first input..."
            />
          </div>
          {zip(model.stems.slice(1), model.inputs).map(([stem, input], index) => (
            <>
              <Card.Card>
                <Card.Title>
                  <div className="d-flex justify-content-between w-100">
                    <div>
                      <div className="text-muted">Part {index + 1}</div>
                    </div>
                    <select className="custom-select" style={{ flexBasis: '160px' }}>
                      {multiInputTypes.map((type) => (
                        <option selected={input.type === type} key={type}>
                          {multiInputTypeFriendly(type)}
                        </option>
                      ))}
                    </select>
                    {/* {title(model.inputs, input, index)} */}
                    <div className="flex-grow-1"></div>
                    {index > 0 && (
                      <div className="choicesAuthoring__removeButtonContainer">
                        <RemoveButtonConnected
                          onClick={() => dispatch(MultiInputActions.removePart(input.partId))}
                        />
                      </div>
                    )}
                  </div>
                </Card.Title>
                <Card.Content>
                  {input.type === 'dropdown' && (
                    <DropdownQuestionEditor part={getPartById(model, input.partId)} input={input} />
                  )}
                  {(input.type === 'numeric' || input.type === 'text') && (
                    <InputQuestionEditor part={getPartById(model, input.partId)} input={input} />
                  )}
                </Card.Content>
              </Card.Card>
              <div className="flex-grow-1">
                <RichTextEditorConnected
                  text={stem.content}
                  onEdit={(content) =>
                    dispatch(MultiInputActions.editStemAndPreviewText(content, stem.id))
                  }
                  placeholder="Question continued..."
                />
              </div>
              {index < model.inputs.length - 1 && (
                <AddResourceContent editMode={editMode} index={0} isLast={false}>
                  {addResourceContent(index)}
                </AddResourceContent>
              )}
            </>
          ))}
          <AddResourceContent editMode={editMode} index={model.stems.length - 1} isLast={true}>
            {addResourceContent(model.stems.length - 1)}
          </AddResourceContent>
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <MultiInputStem model={model} />
          {getParts(model).map((part, i) => {
            return (
              <>
                <SimpleFeedback partId={part.id} key={part.id}>
                  {({ correctResponse, incorrectResponse, updateFeedback }) => (
                    <Card.Card>
                      <Card.Title>
                        {'Feedback for ' + friendlyTitle(inputNumberings(model.inputs)[i])}
                      </Card.Title>
                      <Card.Content>
                        <div>
                          Correct answer feedback
                          <RichTextEditorConnected
                            text={correctResponse.feedback.content}
                            onEdit={(content) =>
                              updateFeedback(correctResponse.feedback.id, content)
                            }
                          />
                        </div>
                        <div>
                          Incorrect answer feedback
                          <RichTextEditorConnected
                            text={incorrectResponse.feedback.content}
                            onEdit={(content) =>
                              updateFeedback(incorrectResponse.feedback.id, content)
                            }
                          />
                        </div>
                      </Card.Content>
                    </Card.Card>
                  )}
                </SimpleFeedback>

                {/* <TargetedFeedback
                toggleChoice={(choiceId, mapping) => {
                  dispatch(Actions.editTargetedFeedbackChoice(mapping.response.id, choiceId));
                }}
                addTargetedResponse={() => dispatch(Actions.addTargetedFeedback())}
                unselectedIcon={<Radio.Unchecked />}
                selectedIcon={<Radio.Checked />}
              /> */}
              </>
            );
          })}
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Hints">
          <MultiInputStem model={model} />
          {getParts(model).map((part, i) => (
            <CognitiveHints
              key={part.id}
              hints={part.hints}
              updateOne={(id, content) => dispatch(HintActions.editHint(id, content, part.id))}
              addOne={() => dispatch(HintActions.addCognitiveHint(makeHint(''), part.id))}
              removeOne={(id) =>
                dispatch(HintActions.removeHint(id, hintsByPart(part.id), part.id))
              }
              placeholder="Hint"
              title={'Hints for ' + friendlyTitle(inputNumberings(model.inputs)[i])}
            />
          ))}
        </TabbedNavigation.Tab>
        <ActivitySettings settings={[shuffleAnswerChoiceSetting(model, dispatch)]} />
      </TabbedNavigation.Tabs>
    </>
  );
};

export class MultiInputAuthoring extends AuthoringElement<MultiInputSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<MultiInputSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <MultiInput />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.authoring.element, MultiInputAuthoring);
