import { NumericInput } from 'components/activities/common/delivery/short_answer/NumericInput';
import { TextInput } from 'components/activities/common/delivery/short_answer/TextInput';
import { MultiInputSchema } from 'components/activities/multi_input/schema';
import { DropdownInput } from 'components/activities/multi_input/sections/delivery/DropdownInput';
import { toSimpleText } from 'data/content/text';
import { defaultWriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import React from 'react';

interface Props {
  model: MultiInputSchema;
}

export const MultiInputStem: React.FC<Props> = (props) => {
  const inputs = props.model.inputs.map((input) => {
    if (input.type === 'numeric') {
      return <NumericInput onChange={() => {}} value={'Numeric Input'} disabled />;
    }
    if (input.type === 'text') {
      return <TextInput onChange={() => {}} value="Text Input" disabled />;
    }
    if (input.type === 'dropdown') {
      return (
        <DropdownInput
          onChange={() => {}}
          disabled
          options={props.model.choices
            .filter((choice) => input.choiceIds.includes(choice.id))
            .map((choice) => ({
              value: choice.id,
              content: toSimpleText({ children: choice.content.model }),
            }))}
        />
      );
    }
  });

  // Transforms.insertNodes(editor, [{ type: 'hey ' }]);

  return (
    <div className="multiInput__stem form-inline">
      {props.model.stems.map((stem, i) => {
        if (i > 0) {
          return (
            <>
              {inputs[i - 1]}
              <HtmlContentModelRenderer text={stem.content} context={defaultWriterContext()} />
            </>
          );
        }
        return (
          <HtmlContentModelRenderer
            key={stem.id}
            text={stem.content}
            context={defaultWriterContext()}
          />
        );
      })}
    </div>
  );
};
