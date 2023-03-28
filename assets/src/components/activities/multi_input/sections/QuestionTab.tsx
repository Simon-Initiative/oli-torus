import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { RemoveButtonConnected } from 'components/activities/common/authoring/RemoveButton';
import { Dropdown, MultiInput, MultiInputSchema } from 'components/activities/multi_input/schema';
import { DropdownQuestionEditor } from 'components/activities/multi_input/sections/DropdownQuestionEditor';
import { partTitle } from 'components/activities/multi_input/utils';
import { Card } from 'components/misc/Card';
import { getParts } from 'data/activities/model/utils';
import React from 'react';
import { Editor, Element, Transforms } from 'slate';
import { ReactEditor } from 'slate-react';

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
        {props.input.inputType === 'dropdown' && (
          <DropdownQuestionEditor input={props.input as Dropdown} />
        )}
      </Card.Content>
    </Card.Card>
  );
};
