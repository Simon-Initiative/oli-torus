// MyComponent.story.ts|tsx

import React from 'react';
import { ComponentStory, ComponentMeta } from '@storybook/react';
import { JSONSchema7Object } from 'json-schema';

import * as DropdownSchema from '../../components/parts/janus-dropdown/schema';
import * as SliderSchema from '../../components/parts/janus-slider/schema';
import '../../../styles/index.scss';
import PropertyEditor from '../../apps/authoring/components/PropertyEditor/PropertyEditor';
import {
  simplifiedPartSchema,
  simplifiedPartUiSchema,
} from '../../apps/authoring/components/PropertyEditor/schemas/part';
import { AdvancedAuthorStorybookContext } from './AdvancedAuthorStorybookContext';

interface PanelDef {
  title: string;
  uiSchema: any;
  schema: JSONSchema7Object;
  data: any;
}

const updateUISchema = (uiSchema: any): any => {
  const newUiSchema = {
    ...simplifiedPartUiSchema,
    custom: {
      'ui:title': 'Component Options',
      ...uiSchema,
    },
  };
  return newUiSchema;
};

const updateSchema = (schema: JSONSchema7Object): JSONSchema7Object => {
  const newSchema: any = {
    ...simplifiedPartSchema,
    properties: {
      custom: { type: 'object', properties: { ...schema } },
      ...simplifiedPartSchema.properties,
    },
  };

  if (schema.definitions) {
    newSchema.definitions = schema.definitions;
    delete newSchema.properties.custom.properties.definitions;
  }
  return newSchema;
};

const panels: PanelDef[] = [
  {
    title: 'Dropdown - simple',
    uiSchema: updateUISchema(DropdownSchema.simpleUISchema),
    schema: updateSchema(DropdownSchema.simpleSchema),
    data: DropdownSchema.createSchema(),
  },
  {
    title: 'Slider - simple',
    uiSchema: updateUISchema(SliderSchema.simpleUISchema),
    schema: updateSchema(SliderSchema.simpleSchema),
    data: SliderSchema.createSchema(),
  },
];

export const PanelPicker = () => {
  const [currentPanelIndex, setCurrentPanelIndex] = React.useState(1);
  const panel = panels[currentPanelIndex];
  const [preview, setPreview] = React.useState('');

  return (
    <div className="advanced-authoring" id="advanced-authoring">
      <AdvancedAuthorStorybookContext className="">
        <select
          value={currentPanelIndex}
          onChange={(e) => setCurrentPanelIndex(parseInt(e.target.value))}
        >
          {panels.map((panel, index) => (
            <option key={index} value={index}>
              {panel.title}
            </option>
          ))}
        </select>
        <pre>
          <code>Data: {preview}</code>
          <hr />
          <code>Schema: {JSON.stringify(panel.schema, null, 2)}</code>
          <hr />
          <code>UI Schema:{JSON.stringify(panel.uiSchema, null, 2)}</code>
        </pre>
        <section className="aa-panel right-panel open">
          <div className="aa-panel-inner">
            <div className="tab-content">
              <div className="fade tab-pane active show">
                <div className="screen-tab p-3 overflow-hidden">
                  <PropertyEditor
                    schema={panel.schema}
                    uiSchema={panel.uiSchema}
                    value={panel.data}
                    onChangeHandler={(changes) => setPreview(JSON.stringify(changes, null, 2))}
                    triggerOnChange={true}
                  />
                </div>
              </div>
            </div>
          </div>
        </section>
      </AdvancedAuthorStorybookContext>
    </div>
  );
};

export default {
  /* 👇 The title prop is optional.
   * See https://storybook.js.org/docs/react/configure/overview#configure-story-loading
   * to learn how to generate automatic titles
   */
  title: 'Advanced Authoring/Property Panels',
  component: PanelPicker,
} as ComponentMeta<typeof PanelPicker>;
