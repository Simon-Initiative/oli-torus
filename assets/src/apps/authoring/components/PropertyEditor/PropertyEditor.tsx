/* eslint-disable react/prop-types */
import Form from '@rjsf/bootstrap-4';
import { UiSchema } from '@rjsf/core';
import { JSONSchema7 } from 'json-schema';
import React, { Fragment } from 'react';
import CustomCheckbox from './custom/CustomCheckbox';
import ScreenDropdownTemplate from './custom/ScreenDropdownTemplate';

interface PropertyEditorProps {
  schema: JSONSchema7;
  uiSchema: UiSchema;
  onChangeHandler: (changes: unknown) => void;
  value: unknown;
}

const widgets: any = {
  CheckboxWidget: CustomCheckbox,
  ScreenDropdownTemplate: ScreenDropdownTemplate,
};

const PropertyEditor: React.FC<PropertyEditorProps> = ({
  schema,
  uiSchema,
  value,
  onChangeHandler,
}) => {
  /* console.log({ value, uiSchema }); */
  return (
    <Form
      schema={schema}
      formData={value}
      onChange={(e) => {
        onChangeHandler(e.formData);
      }}
      uiSchema={uiSchema}
      widgets={widgets}
    >
      <Fragment />
      {/*  this one is to remove the submit button */}
    </Form>
  );
};
export default PropertyEditor;
