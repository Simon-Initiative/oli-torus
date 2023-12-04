import React from 'react';
import { Editor } from 'slate';
import { ReactEditor } from 'slate-react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import {
  MultiInput,
  MultiInputSchema,
} from 'components/activities/multi_input/schema';
import { getParts } from 'data/activities/model/utils';
import { Accordion, Card } from 'react-bootstrap';
import { AnswerKeyTab } from './AnswerKeyTab';
import { Part } from 'components/activities/types';

interface Props {
  editor: ReactEditor & Editor;
  input: MultiInput;
  index: number;
}
export const PartsTab: React.FC<Props> = (props) => {
  const { model } = useAuthoringElementContext<MultiInputSchema>();

  const getInputBody = (part: Part) => {
    const inputs: MultiInput[] = model.inputs.filter((input) => input.partId === part.id);
    return inputs ? (
      inputs.map((input) => (
        <AnswerKeyTab key={input.id} input={input} />
      ))
    ) : null;

  };

  return (
    <Accordion>
      {getParts(model).map((part, index) => (
          <Card key={part.id}>
          <Accordion.Toggle as={Card.Header} eventKey={part.id}>
              Part {index+1}
          </Accordion.Toggle>

          <Accordion.Collapse eventKey={part.id}>
              <Card.Body>
                {getInputBody(part)}
              </Card.Body>
          </Accordion.Collapse>
       </Card>

        ))}

    </Accordion>
  );
};

