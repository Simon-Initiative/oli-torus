import React from 'react';
import { Editor } from 'slate';
import { ReactEditor } from 'slate-react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { MultiInput, MultiInputSchema } from 'components/activities/multi_input/schema';
import { Part } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import { getParts } from 'data/activities/model/utils';
import { ResponseTab } from '../sections/ResponseTab';

interface Props {
  editor: ReactEditor & Editor;
  input: MultiInput;
  index: number;
}
export const PartsTab: React.FC<Props> = (props) => {
  const { model } = useAuthoringElementContext<MultiInputSchema>();
  const [selectedPart, setSelectedPart] = React.useState<Part | undefined>(
    getParts(model).find((p) => p.id === props.input.partId),
  );
  const parts = getParts(model);

  const getResponsesBody = (part: Part) => {
    return part.responses.map((response, index) => (
      <ResponseTab key={response.id} response={response} index={index} />
    ));
  };

  return (
    <Card.Card key={props.input.id}>
      <Card.Title>
        <SelectPart parts={parts} selected={props.input.partId} onSelect={setSelectedPart} />
      </Card.Title>
      <Card.Content>{selectedPart && getResponsesBody(selectedPart)}</Card.Content>
    </Card.Card>
  );
};

interface SelectPartProps {
  parts: Part[];
  selected: string;
  onSelect: (value: Part | undefined) => void;
}
const SelectPart: React.FC<SelectPartProps> = ({ parts, selected, onSelect }) => {
  return (
    <div className="inline-flex items-baseline mb-2">
      <label className="flex-shrink-0">Move to:</label>
      <select
        className="flex-shrink-0 border py-1 px-1.5 border-neutral-300 rounded w-full disabled:bg-neutral-100 disabled:text-neutral-600 dark:bg-neutral-800 dark:border-neutral-700 dark:text-white ml-2"
        value={selected}
        onChange={({ target: { value } }) => {
          onSelect(parts.find((p) => p.id == value));
        }}
      >
        {parts.map((part, index: number) => (
          <option key={part.id} value={part.id}>
            Part {index + 1}
          </option>
        ))}
      </select>
    </div>
  );
};
