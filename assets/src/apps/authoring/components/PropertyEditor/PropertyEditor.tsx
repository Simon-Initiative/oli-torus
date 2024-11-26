import React, { Fragment, useEffect, useState } from 'react';
import Form from '@rjsf/bootstrap-4';
import { UiSchema } from '@rjsf/core';
import { diff } from 'deep-object-diff';
import { JSONSchema7 } from 'json-schema';
import { at } from 'lodash';
import ColorPickerWidget from './custom/ColorPickerWidget';
import CustomCheckbox from './custom/CustomCheckbox';
import { DropdownOptionsEditor } from './custom/DropdownOptionsEditor';
import { MCQCorrectAnswerEditor } from './custom/MCQCorrectAnswerEditor';
import { MCQCustomErrorFeedbackAuthoring } from './custom/MCQCustomErrorFeedbackAuthoring';
import { MCQOptionsEditor } from './custom/MCQOptionsEditor';
import { OptionsCorrectPicker } from './custom/OptionsCorrectPicker';
import { OptionsCustomErrorFeedbackAuthoring } from './custom/OptionsCustomErrorFeedbackAuthoring';
import ScreenDropdownTemplate from './custom/ScreenDropdownTemplate';
import { TorusAudioBrowser } from './custom/TorusAudioBrowser';
import { TorusImageBrowser } from './custom/TorusImageBrowser';
import { TorusVideoBrowser } from './custom/TorusVideoBrowser';

interface PropertyEditorProps {
  schema: JSONSchema7;
  uiSchema: UiSchema;
  onChangeHandler: (changes: unknown) => void;
  value: unknown;
  onClickHandler?: (changes: unknown) => void;
  triggerOnChange?: boolean | string[];
  onfocusHandler?: (changes: boolean) => void;
}

const widgets: any = {
  ColorPicker: ColorPickerWidget,
  CheckboxWidget: CustomCheckbox,
  ScreenDropdownTemplate: ScreenDropdownTemplate,
  TorusImageBrowser: TorusImageBrowser,
  TorusAudioBrowser: TorusAudioBrowser,
  TorusVideoBrowser: TorusVideoBrowser,
  OptionsCorrectPicker: OptionsCorrectPicker,
  OptionsCustomErrorFeedbackAuthoring: OptionsCustomErrorFeedbackAuthoring,
  MCQCorrectAnswerEditor: MCQCorrectAnswerEditor,
  MCQOptionsEditor: MCQOptionsEditor,
  DropdownOptionsEditor: DropdownOptionsEditor,
  MCQCustomErrorFeedbackAuthoring: MCQCustomErrorFeedbackAuthoring,
};

const PropertyEditor: React.FC<PropertyEditorProps> = ({
  schema,
  uiSchema,
  value,
  onChangeHandler,
  triggerOnChange = false,
  onfocusHandler,
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
        const updatedData = e.formData;
        const changedProp = diff(formData, updatedData);
        const changedPropType = findDiffType(changedProp);

        const shouldTriggerChange =
          typeof triggerOnChange === 'boolean'
            ? triggerOnChange
            : Object.keys(changedProp).some((v) => triggerOnChange.indexOf(v) > -1);
        setFormData(updatedData);

        //console.info('ONCHANGE', { shouldTriggerChange, changedPropType, changedProp });

        if (shouldTriggerChange || changedPropType === 'boolean') {
          // because 'id' is used to maintain selection, it MUST be onBlur or else bad things happen
          if (updatedData.id === formData.id) {
            console.log('ONCHANGE P EDITOR TRIGGERED', {
              e,
              updatedData,
              changedProp,
              changedPropType,
              triggerOnChange,
            });
            onChangeHandler(updatedData);
          }
        }
      }}
      onFocus={() => {
        if (onfocusHandler) {
          onfocusHandler(false);
        }
      }}
      onBlur={(key, changed) => {
        //AdvancedFeedbackNumberRange widget does not call the onFocus hence we are using the onBlur and passing 'partPropertyElementFocus' as key
        // to identify if this was called from onfocus event of the input
        if (key == 'partPropertyElementFocus' && onfocusHandler) {
          onfocusHandler(false);
          return;
        }
        // key will look like root_Position_x
        // changed will be the new value
        // formData will be the current state of the form
        console.info('ONBLUR');
        const dotPath = key.replace(/_/g, '.').replace('root.', '');
        const [newValue] = at(value as any, dotPath);
        // console.log('ONBLUR', { key, changed, formData, value, dotPath, newValue });
        // specifically using != instead of !== because `changed` is always a string
        // and the stakes here are not that high, we are just trying to avoid saving so many times
        if (newValue != changed) {
          onChangeHandler(formData);
        }
        if (onfocusHandler) {
          onfocusHandler(true);
        }
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
