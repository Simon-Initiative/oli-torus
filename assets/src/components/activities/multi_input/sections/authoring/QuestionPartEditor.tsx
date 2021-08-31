import { RemoveButtonConnected } from 'components/activities/common/authoring/removeButton/RemoveButton';
import { DropdownEditor } from 'components/activities/multi_input/sections/authoring/DropdownEditor';
import { DropdownQuestionEditor } from 'components/activities/multi_input/sections/authoring/DropdownQuestionEditor';
import { InputEditor } from 'components/activities/multi_input/sections/authoring/InputEditor';
import { InputQuestionEditor } from 'components/activities/multi_input/sections/authoring/InputQuestionEditor';
import { MultiInput, MultiInputType } from 'components/activities/multi_input/utils';
import { Part } from 'components/activities/types';
import React from 'react';
import { assertNever } from 'utils/common';

interface Props {
  part: Part;
  input: MultiInput;
  onRemove: (partId: string) => void;
}
export const QuestionPartEditor: React.FC<Props> = ({ part, input, onRemove }) => {
  return <>{editorDispatch(part, input)}</>;
};

const editorDispatch = (part: Part, input: MultiInput) => {
  switch (input.type) {
    case 'dropdown':
      return <DropdownQuestionEditor part={part} input={input} />;
    case 'numeric':
    case 'text':
      return <InputQuestionEditor part={part} input={input} />;
    default:
      assertNever(input);
  }
};
