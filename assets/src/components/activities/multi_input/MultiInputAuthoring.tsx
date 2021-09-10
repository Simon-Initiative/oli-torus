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
import { getPartById, getParts } from 'data/activities/model/utils1';
import { Card } from 'components/misc/Card';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { hintsByPart } from 'data/activities/model/hintUtils';
import { CognitiveHints } from 'components/activities/common/hints/authoring/HintsAuthoring';
import { HintActions } from 'components/activities/common/hints/authoring/hintActions';
import { makeHint, Manifest, Part } from 'components/activities/types';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import {
  Dropdown,
  FillInTheBlank,
  MultiInput,
  MultiInputSchema,
  MultiInputType,
  multiInputTypes,
} from 'components/activities/multi_input/schema';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { ReactEditor, useEditor } from 'slate-react';
import { ID, InputRef, inputRef } from 'data/content/model';
import { Editor, Element, Transforms } from 'slate';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { defaultWriterContext } from 'data/content/writers/context';
import { elementsOfType } from 'components/editing/utils';
import { MultiInputActions } from 'components/activities/multi_input/actions';
import { RemoveButtonConnected } from 'components/activities/common/authoring/removeButton/RemoveButton';
import guid from 'utils/guid';
import { DropdownQuestionEditor } from 'components/activities/multi_input/sections/authoring/DropdownQuestionEditor';
import { InputQuestionEditor } from 'components/activities/multi_input/sections/authoring/InputQuestionEditor';

// eslint-disable-next-line @typescript-eslint/no-empty-interface
interface AddInputRefButtonsProps {
  setInputRefs: React.Dispatch<React.SetStateAction<Map<ID, InputRef>>>;
  setEditor: React.Dispatch<React.SetStateAction<ReactEditor & Editor>>;
}
const AddInputRefButtons: React.FC<AddInputRefButtonsProps> = (props) => {
  const editor = useEditor();
  const { dispatch, model, editMode } = useAuthoringElementContext<MultiInputSchema>();

  React.useEffect(() => {
    props.setEditor(editor);
  }, [editor]);

  React.useEffect(() => {
    if (!editMode) {
      return;
    }
    const difference = (minuend: Map<any, any>, subtrahend: Map<any, any>) =>
      new Set([...minuend].filter(([k]) => !subtrahend.has(k)).map(([, v]) => v));

    // Reconciliation logic
    const inputRefs = (elementsOfType(editor, 'input_ref') as InputRef[]).reduce(
      (acc, ref) => acc.set(ref.partId, ref),
      new Map<ID, InputRef>(),
    );
    const parts = getParts(model).reduce(
      (acc, part) => acc.set(part.id, part),
      new Map<ID, Part>(),
    );
    const extraInputRefs = difference(inputRefs, parts);
    const extraParts = difference(parts, inputRefs);
    if (extraInputRefs.size > 3 || extraParts.size > 3) {
      return;
    }
    console.log('setting input refs', inputRefs);
    // extraInputRefs.forEach((inputRef) => dispatch(MultiInputActions.addPart(inputRef)));
    return props.setInputRefs(() => inputRefs);

    // if (/* Part Ids do not match all input part Ids */) {
    //   // Make sure all input refs match the part ids here
    //   // Figure out how to reconcile if necessary
    // }
  }, [model, editor, editMode]);

  const addInputRef = (type: MultiInputType) => {
    // Insert InputRef node into stem, with choice ids if dropdown
    // Add choices if applicable
    // Add part to model corresponding to the input

    Transforms.insertNodes(
      editor,
      type === 'dropdown' ? inputRef(type, [guid(), guid()]) : inputRef(type),
    );
    // setX(true);
    // dispatch(MultiInputActions.addPart(theInputRef));
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
  // PartID to InputRef
  const [inputRefs, setInputRefs] = React.useState<Map<ID, InputRef>>(new Map());
  const [editor, setEditor] = React.useState<(ReactEditor & Editor) | undefined>();
  console.log('All input refs', inputRefs);

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
              onEdit={(content, editor, operations) => {
                dispatch(MultiInputActions.editStemAndPreviewText(content, editor, operations));
              }}
              placeholder="Question..."
            >
              <AddInputRefButtons setInputRefs={setInputRefs} setEditor={setEditor} />
            </RichTextEditorConnected>
          </div>
          {editor &&
            (elementsOfType(editor, 'input_ref') as InputRef[]).map((inputRef, index) => {
              return (
                <Card.Card key={inputRef.id}>
                  <Card.Title>
                    <>
                      <div className="text-muted">Part {index + 1}: </div>
                      {/* <select className="custom-select" style={{ flexBasis: '160px' }}>
                      {multiInputTypes.map((type) => (
                        <option selected={input.type === type} key={type}>
                          {multiInputTypeFriendly(type)}
                        </option>
                      ))}
                    </select> */}
                      {/* {title(model.inputs, input, index)} */}
                      <div className="flex-grow-1"></div>
                      <div className="choicesAuthoring__removeButtonContainer">
                        {getParts(model).length > 1 && (
                          <RemoveButtonConnected
                            onClick={() => {
                              if (!editor) {
                                return;
                              }
                              Transforms.removeNodes(editor, {
                                at: [],
                                match: (n) =>
                                  Element.isElement(n) &&
                                  n.type === 'input_ref' &&
                                  n.id === inputRef.id,
                              });
                              // dispatch(MultiInputActions.removePart(inputRef.partId));
                            }}
                          />
                        )}
                      </div>
                    </>
                  </Card.Title>
                  <Card.Content>
                    {
                      {
                        dropdown: (
                          <DropdownQuestionEditor
                            part={getPartById(model, inputRef.partId)}
                            input={inputRef as Dropdown}
                          />
                        ),
                        text: (
                          <InputQuestionEditor
                            part={getPartById(model, inputRef.partId)}
                            input={inputRef as FillInTheBlank}
                          />
                        ),
                        numeric: (
                          <InputQuestionEditor
                            part={getPartById(model, inputRef.partId)}
                            input={inputRef as FillInTheBlank}
                          />
                        ),
                      }[inputRef.inputType]
                    }
                  </Card.Content>
                </Card.Card>
              );
              //   if (inputRef.inputType === 'dropdown') {
              //     return (
              //       <DropdownQuestionEditor
              //         part={getPartById(model, inputRef.partId)}
              //         input={inputRef}
              //       />
              //     );
              //   }
              //   if (inputRef.inputType === 'numeric' || inputRef.inputType === 'text') {
              //     return (
              //       <InputQuestionEditor part={getPartById(model, inputRef.partId)} input={inputRef} />
              //     );
              //   }
              // })
            })}
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
