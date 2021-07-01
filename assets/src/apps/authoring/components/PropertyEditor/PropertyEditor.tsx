/* eslint-disable react/prop-types */
import React, { Fragment } from 'react';
import Form from '@rjsf/bootstrap-4';
import { JSONSchema7 } from 'json-schema';
import CustomCheckbox from './custom/CustomCheckbox';

interface PropertyEditorProps {
  schema: JSONSchema7;
  uiSchema: any;
  onChangeHandler: any;
  value: any;
}

const widgets = {
  CheckboxWidget: CustomCheckbox,
};
const PropertyEditor: React.FC<PropertyEditorProps> = ({
  schema,
  uiSchema,
  value,
  onChangeHandler,
}) => {
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
