import React from 'react';
import ReactDOM from 'react-dom';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
  useAuthoringElementContext,
} from '../AuthoringElement';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { getParts } from 'data/activities/model/utils1';
import { Card } from 'components/misc/Card';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { hintsByPart } from 'data/activities/model/hintUtils';
import { CognitiveHints } from 'components/activities/common/hints/authoring/HintsAuthoring';
import { HintActions } from 'components/activities/common/hints/authoring/hintActions';
import { makeHint, Manifest, PostUndoable } from 'components/activities/types';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import {
  MultiInput,
  MultiInputSchema,
  MultiInputType,
  multiInputTypes,
} from 'components/activities/multi_input/schema';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { useEditor } from 'slate-react';
import { InputRef, inputRef } from 'data/content/model';
import { Transforms } from 'slate';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { defaultWriterContext } from 'data/content/writers/context';
import { StemActions } from 'components/activities/common/authoring/actions/stemActions';
import { elementsOfType } from 'components/editing/utils';
import { Maybe } from 'tsmonad';
import { MultiInputActions } from 'components/activities/multi_input/actions';

interface AddInputRefButtonsProps {
  dispatch: (action: (model: MultiInputSchema, post: PostUndoable) => any) => MultiInputSchema;
  model: MultiInputSchema;
}
const AddInputRefButtons: React.FC<AddInputRefButtonsProps> = (props) => {
  const editor = useEditor();

  React.useEffect(() => {
    // Reconciliation logic
    const inputRefs = elementsOfType(editor, 'input_ref') as InputRef[];
    const parts = getParts(props.model);

    // if (/* Part Ids do not match all input part Ids */) {
    //   // Make sure all input refs match the part ids here
    //   // Figure out how to reconcile if necessary
    // }

    if (inputRefs.length > parts.length) {
      const missingRef = Maybe.maybe(
        inputRefs.find((input) => !parts.map((p) => p.id).includes(input.partId)),
      ).lift((input) => {
        props.dispatch(MultiInputActions.addPart(input));
      });
      // Missing part
    }
    if (parts.length > inputRefs.length) {
      // Missing input ref
    }
  }, [props.model, editor]);

  const addInputRef = (type: MultiInputType) => {
    // Insert InputRef node into stem, with choice ids if dropdown
    // Add choices if applicable
    // Add part to model corresponding to the input
    const theInputRef = inputRef(type);
    Transforms.insertNodes(editor, theInputRef);
  };

  return (
    <div>
      {multiInputTypes.map((type) => (
        <AuthoringButtonConnected
          key={type}
          action={(_e) => {
            addInputRef(type);
          }}
        >
          <input
            readOnly
            style={{ cursor: 'pointer', userSelect: 'none' }}
            type="text"
            value={'Add ' + type}
          />
        </AuthoringButtonConnected>
      ))}
    </div>
  );
};

const store = configureStore();

const MultiInput = () => {
  const { dispatch, model } = useAuthoringElementContext<MultiInputSchema>();

  console.log('model', model);

  const friendlyType = (type: MultiInputType) => {
    if (type === 'dropdown') {
      return 'Dropdown';
    }
    return 'Fill in the blank';
  };

  const inputNumberings = (inputs: MultiInput[]): { type: string; number: number }[] => {
    return inputs.reduce(
      (acc, input) => {
        const type = friendlyType(input.inputType);

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
              text={model.stem.content}
              onEdit={(content) => {
                dispatch(StemActions.editStemAndPreviewText(content));
              }}
              placeholder="Question..."
            >
              <AddInputRefButtons model={model} dispatch={dispatch} />
            </RichTextEditorConnected>
          </div>
          {
            //             <div className="text-muted">Part {index + 1}</div>
            //           <select className="custom-select" style={{ flexBasis: '160px' }}>
            //             {multiInputTypes.map((type) => (
            //               <option selected={input.type === type} key={type}>
            //                 {multiInputTypeFriendly(type)}
            //               </option>
            //             ))}
            //           </select>
            //           {/* {title(model.inputs, input, index)} */}
            //           <div className="flex-grow-1"></div>
            //           {index > 0 && (
            //             <div className="choicesAuthoring__removeButtonContainer">
            //               <RemoveButtonConnected
            //                 onClick={() => dispatch(MultiInputActions.removePart(input.partId))}
            //               />
            //             </div>
            //           )}
            //         </div>
            //         {input.type === 'dropdown' && (
            //           <DropdownQuestionEditor part={getPartById(model, input.partId)} input={input} />
            //         )}
            //         {(input.type === 'numeric' || input.type === 'text') && (
            //           <InputQuestionEditor part={getPartById(model, input.partId)} input={input} />
            //         )}
          }
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <StemDelivery context={defaultWriterContext()} stem={model.stem} />
          {/* <MultiInputStem model={model} /> */}
          {getParts(model).map((part, i) => {
            return (
              <>
                <SimpleFeedback partId={part.id} key={part.id}>
                  {({ correctResponse, incorrectResponse, updateFeedback }) => (
                    <Card.Card>
                      <Card.Title>
                        {/* {'Feedback for ' + friendlyTitle(inputNumberings(model.inputs)[i])} */}
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
          <StemDelivery context={defaultWriterContext()} stem={model.stem} />
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
              // title={'Hints for ' + friendlyTitle(inputNumberings(model.inputs)[i])}
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
