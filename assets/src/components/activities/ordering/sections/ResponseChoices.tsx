import { Choice } from 'components/activities/types';
import { Draggable } from 'components/common/DraggableColumn';
import { defaultWriterContext, WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import React from 'react';

interface Props {
  choices: Choice[];
  disabled?: boolean;
  writerContext: WriterContext;
  setChoices: (choices: Choice[]) => void;
}
export const ResponseChoices: React.FC<Props> = ({
  choices,
  setChoices,
  disabled,
  writerContext: { projectSlug },
}) => {
  return (
    <Draggable.Column displayOutline items={choices} setItems={setChoices}>
      {choices.map((choice, index) => (
        <Draggable.Item
          isDragDisabled={disabled ?? false}
          itemAriaLabel={`choice ${index + 1}`}
          key={choice.id}
          id={choice.id}
          item={choice}
        >
          {(_choice, index) => (
            <>
              <Draggable.DragIndicator isDragDisabled={disabled ?? false} />
              <div style={{ marginRight: '0.5rem' }}>{index + 1}.</div>
              <HtmlContentModelRenderer
                content={choice.content}
                context={defaultWriterContext({ projectSlug: projectSlug })}
              />
            </>
          )}
        </Draggable.Item>
      ))}
    </Draggable.Column>
  );
};
