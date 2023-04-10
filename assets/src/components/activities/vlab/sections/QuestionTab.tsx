import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { RemoveButtonConnected } from 'components/activities/common/authoring/RemoveButton';
import { Dropdown, VlabInput, VlabSchema, VlabValue } from 'components/activities/vlab/schema';
import { DropdownQuestionEditor } from 'components/activities/multi_input/sections/DropdownQuestionEditor';
import { VlabParameterSelector } from 'components/activities/vlab/sections/VlabParameterSelector';
import { partTitle } from 'components/activities/vlab/utils';
import { Card } from 'components/misc/Card';
import { getParts } from 'data/activities/model/utils';
import React from 'react';
import { Editor, Element, Transforms } from 'slate';
import { ReactEditor } from 'slate-react';

interface Props {
  editor: ReactEditor & Editor;
  input: VlabInput;
  index: number;
}
export const QuestionTab: React.FC<Props> = (props) => {
  const { model } = useAuthoringElementContext<VlabSchema>();

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
        {props.input.inputType === 'vlabvalue' && (
          <VlabParameterSelector input={props.input as VlabValue} />
        )}
      </Card.Content>
    </Card.Card>
  );
};
