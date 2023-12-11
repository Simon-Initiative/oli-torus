import React from 'react';
import { Editor, Element, Transforms } from 'slate';
import { ReactEditor } from 'slate-react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { RemoveButtonConnected } from 'components/activities/common/authoring/RemoveButton';
import { MultiInput, MultiInputSize } from 'components/activities/multi_input/schema';
import { ResponseMultiInputSchema } from 'components/activities/response_multi/schema';
import { DropdownQuestionEditor } from 'components/activities/response_multi/sections/DropdownQuestionEditor';
import { inputTitle } from 'components/activities/response_multi/utils';
import { Part } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import { getParts } from 'data/activities/model/utils';
import { ResponseMultiInputActions } from '../actions';

interface Props {
  editor: ReactEditor & Editor;
  input: MultiInput;
  index: number;
}
export const QuestionTab: React.FC<Props> = (props) => {
  const { model } = useAuthoringElementContext<ResponseMultiInputSchema>();

  const removeInputRef = () => {
    getParts(model).length > 1 &&
      Transforms.removeNodes(props.editor, {
        at: [],
        match: (n) => Element.isElement(n) && n.type === 'input_ref' && n.id === props.input.id,
      });
  };

  return (
    <Card.Card key={props.input.id}>
      <Card.Title>
        <>
          {inputTitle(props.input, props.index)}
          <div className="flex-grow-1"></div>
          <div className="choicesAuthoring__removeButtonContainer">
            {<RemoveButtonConnected onClick={removeInputRef} />}
          </div>
        </>
      </Card.Title>
      <Card.Content>
        <InputSizeEditor input={props.input} />

        {['text', 'numeric'].includes(props.input.inputType) && model.authoring.responses ? (
          <div className="mt-5">
            <table>
              <tr>
                <th>Student</th>
                <th>Response</th>
              </tr>
              <tbody>
                {model.authoring.responses?.map((response, index) => (
                  <tr key={index}>
                    <td className="whitespace-nowrap">{response.user_name}</td>
                    <td>{response.text}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : null}

        {props.input.inputType === 'dropdown' && <DropdownQuestionEditor input={props.input} />}

        <div>
          <MoveInputIntoPart input={props.input} parts={getParts(model)} />
        </div>
      </Card.Content>
    </Card.Card>
  );
};

interface InputSizeEditorProps {
  input: MultiInput;
}

const InputSizeEditor: React.FC<InputSizeEditorProps> = ({ input }) => {
  const { dispatch } = useAuthoringElementContext<ResponseMultiInputSchema>();

  return (
    <div className="inline-flex items-baseline mb-2">
      <label className="flex-shrink-0">Size</label>
      <select
        className="flex-shrink-0 border py-1 px-1.5 border-neutral-300 rounded w-full disabled:bg-neutral-100 disabled:text-neutral-600 dark:bg-neutral-800 dark:border-neutral-700 dark:text-white ml-2"
        value={input.size || 'medium'}
        onChange={({ target: { value } }) => {
          dispatch(ResponseMultiInputActions.setInputSize(input.id, value as MultiInputSize));
        }}
      >
        <option value="small">Small</option>
        <option value="medium">Medium</option>
        <option value="large">Large</option>
      </select>
    </div>
  );
};

interface MoveInputIntoPartProps {
  input: MultiInput;
  parts: Part[];
}
const MoveInputIntoPart: React.FC<MoveInputIntoPartProps> = ({ input, parts }) => {
  const { dispatch } = useAuthoringElementContext<ResponseMultiInputSchema>();

  return (
    <div className="inline-flex items-baseline mb-2">
      <label className="flex-shrink-0">
        Move Input from Part {parts.findIndex((p) => p.id === input.partId) + 1} to
      </label>
      <select
        className="flex-shrink-0 border py-1 px-1.5 border-neutral-300 rounded w-full disabled:bg-neutral-100 disabled:text-neutral-600 dark:bg-neutral-800 dark:border-neutral-700 dark:text-white ml-2"
        value={undefined}
        defaultValue={undefined}
        onChange={({ target: { value } }) => {
          if (value !== input.partId) {
            dispatch(ResponseMultiInputActions.moveInputToPart(input.id, value));
          }
        }}
      >
        <option disabled selected value={undefined}>
          select option
        </option>
        {parts.map((part, index: number) => (
          <option key={part.id} value={part.id}>
            Part {index + 1}
          </option>
        ))}
      </select>
    </div>
  );
};
