/* eslint-disable react/prop-types */
import Form from '@rjsf/bootstrap-4';
import { UiSchema } from '@rjsf/core';
import { JSONSchema7 } from 'json-schema';
import React, { Fragment, useEffect, useState } from 'react';
import ColorPickerWidget from './custom/ColorPickerWidget';
import CustomCheckbox from './custom/CustomCheckbox';
import ScreenDropdownTemplate from './custom/ScreenDropdownTemplate';

interface PropertyEditorProps {
  schema: JSONSchema7;
  uiSchema: UiSchema;
  onChangeHandler: (changes: unknown) => void;
  value: unknown;
}

const widgets: any = {
  ColorPicker: ColorPickerWidget,
  CheckboxWidget: CustomCheckbox,
  ScreenDropdownTemplate: ScreenDropdownTemplate,
};

const PropertyEditor: React.FC<PropertyEditorProps> = ({
  schema,
  uiSchema,
  value,
  onChangeHandler,
}) => {
  const [formData, setFormData] = useState(value);

  useEffect(() => {
    setFormData(value);
  }, [value]);

  return (
    <Form
      schema={schema}
      formData={formData}
      onChange={(e) => {
        // console.log('ONCHANGE P EDITOR', e.formData);
        setFormData(e.formData);
      }}
      onBlur={(...args) => {
        // console.log('ONBLUR', { args, formData });
        onChangeHandler(formData);
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
