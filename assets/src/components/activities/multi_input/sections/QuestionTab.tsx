import React from 'react';
import { Editor, Element, Transforms } from 'slate';
import { ReactEditor } from 'slate-react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { RemoveButtonConnected } from 'components/activities/common/authoring/RemoveButton';
import { RespondedUsersList } from 'components/activities/common/authoring/RespondedUsersList';
import {
  MultiInput,
  MultiInputSchema,
  MultiInputSize,
} from 'components/activities/multi_input/schema';
import { DropdownQuestionEditor } from 'components/activities/multi_input/sections/DropdownQuestionEditor';
import { partTitle } from 'components/activities/multi_input/utils';
import { Card } from 'components/misc/Card';
import { getParts } from 'data/activities/model/utils';
import { MultiInputActions } from '../actions';

interface Props {
  editor: ReactEditor & Editor;
  input: MultiInput;
  index: number;
}
export const QuestionTab: React.FC<Props> = (props) => {
  const { model } = useAuthoringElementContext<MultiInputSchema>();

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
          {partTitle(props.input, props.index)}
          <div className="flex-grow-1"></div>
          <div className="choicesAuthoring__removeButtonContainer">
            {getParts(model).length > 1 && <RemoveButtonConnected onClick={removeInputRef} />}
          </div>
        </>
      </Card.Title>
      <Card.Content>
        <InputSizeEditor input={props.input} />

        {['text', 'numeric'].includes(props.input.inputType) && model.authoring.responses ? (
          <div className="mt-5">
            <table>
              <tr>
                <th>Students </th>
                <th>Response</th>
              </tr>
              <tbody>
                {model.authoring.responses
                  ?.filter(
                    (response) =>
                      response.type === props.input.inputType &&
                      response.part_id === props.input.partId,
                  )
                  .map((response, index) => (
                    <tr key={`${index}`}>
                      <td className="whitespace-nowrap">
                        <RespondedUsersList users={response.users} />
                      </td>
                      <td>{response.text}</td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
        ) : null}
        {props.input.inputType === 'dropdown' && <DropdownQuestionEditor input={props.input} />}
      </Card.Content>
    </Card.Card>
  );
};

interface InputSizeEditorProps {
  input: MultiInput;
}

const InputSizeEditor: React.FC<InputSizeEditorProps> = ({ input }) => {
  const { dispatch } = useAuthoringElementContext<MultiInputSchema>();

  return (
    <div className="inline-flex items-baseline mb-2">
      <label className="flex-shrink-0">Size</label>
      <select
        className="flex-shrink-0 border py-1 px-1.5 border-neutral-300 rounded w-full disabled:bg-neutral-100 disabled:text-neutral-600 dark:bg-neutral-800 dark:border-neutral-700 dark:text-white ml-2"
        value={input.size || 'medium'}
        onChange={({ target: { value } }) => {
          dispatch(MultiInputActions.setInputSize(input.id, value as MultiInputSize));
        }}
      >
        <option value="small">Small</option>
        <option value="medium">Medium</option>
        <option value="large">Large</option>
      </select>
    </div>
  );
};
