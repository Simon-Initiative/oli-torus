/* eslint-disable react/prop-types */
import Form from '@rjsf/bootstrap-4';
import { UiSchema } from '@rjsf/core';
import { JSONSchema7 } from 'json-schema';
import React, { Fragment, useEffect, useState } from 'react';
import ColorPickerWidget from './custom/ColorPickerWidget';
import CustomCheckbox from './custom/CustomCheckbox';
import ScreenDropdownTemplate from './custom/ScreenDropdownTemplate';
import { diff } from 'deep-object-diff';

interface PropertyEditorProps {
  schema: JSONSchema7;
  uiSchema: UiSchema;
  onChangeHandler: (changes: unknown) => void;
  value: unknown;
  triggerOnChange?: boolean;
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
  triggerOnChange = false,
}) => {
  const [formData, setFormData] = useState<any>(value);

  const findDiffType = (changedProp: any): string => {
    const diffType: Record<string, unknown>[] = Object.values(changedProp);
    if (typeof diffType[0] === 'object') {
      return findDiffType(diffType[0]);
    }
    return typeof diffType[0];
  };

  useEffect(() => {
    setFormData(value);
  }, [value]);

  return (
    <Form
      schema={schema}
      formData={formData}
      onChange={(e) => {
        console.log('ONCHANGE P EDITOR', e);
        const updatedData = e.formData;
        const changedProp = diff(formData, updatedData);
        const changedPropType = findDiffType(changedProp);

        setFormData(updatedData);
        if (triggerOnChange || changedPropType === 'boolean') {
          // because 'id' is used to maintain selection, it MUST be onBlur or else bad things happen
          if (updatedData.id === formData.id) {
            onChangeHandler(updatedData);
          }
        }
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
