import React, { Fragment, useEffect, useMemo, useRef, useState } from 'react';
import Form from '@rjsf/bootstrap-4';
import { UiSchema } from '@rjsf/core';
import { diff } from 'deep-object-diff';
import { JSONSchema7 } from 'json-schema';
import { at } from 'lodash';
import { debounce } from 'lodash';
import ColorPickerWidget from './custom/ColorPickerWidget';
import CustomCheckbox from './custom/CustomCheckbox';
import { DropdownOptionsEditor } from './custom/DropdownOptionsEditor';
import { MCQCorrectAnswerEditor } from './custom/MCQCorrectAnswerEditor';
import { MCQCustomErrorFeedbackAuthoring } from './custom/MCQCustomErrorFeedbackAuthoring';
import { MCQOptionsEditor } from './custom/MCQOptionsEditor';
import { OptionsCorrectPicker } from './custom/OptionsCorrectPicker';
import { OptionsCustomErrorFeedbackAuthoring } from './custom/OptionsCustomErrorFeedbackAuthoring';
import ScreenDropdownTemplate from './custom/ScreenDropdownTemplate';
import { SliderOptionsTextEditor } from './custom/SliderOptionsTextEditor';
import { SpokeCompletedOption } from './custom/SpokeCompletedOption';
import { SpokeCustomErrorFeedbackAuthoring } from './custom/SpokeCustomErrorFeedbackAuthoring';
import { SpokeOptionsEditor } from './custom/SpokeOptionsEditor';
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
  isExpertMode?: boolean;
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
  SpokeCustomErrorFeedbackAuthoring: SpokeCustomErrorFeedbackAuthoring,
  MCQCorrectAnswerEditor: MCQCorrectAnswerEditor,
  MCQOptionsEditor: MCQOptionsEditor,
  SpokeOptionsEditor: SpokeOptionsEditor,
  SpokeCompletedOption: SpokeCompletedOption,
  DropdownOptionsEditor: DropdownOptionsEditor,
  MCQCustomErrorFeedbackAuthoring: MCQCustomErrorFeedbackAuthoring,
  SliderOptionsTextEditor: SliderOptionsTextEditor,
};

const PropertyEditor: React.FC<PropertyEditorProps> = ({
  schema,
  uiSchema,
  value,
  onChangeHandler,
  triggerOnChange = false,
  onfocusHandler,
  isExpertMode = false,
}) => {
  const [formData, setFormData] = useState<any>(value);
  const backspacePressed = useRef(false);

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

  const debouncedOnChangeHandler = useMemo(
    () =>
      debounce((data) => {
        onChangeHandler(data);
      }, 500),
    [onChangeHandler],
  );

  useEffect(() => {
    return () => debouncedOnChangeHandler.cancel();
  }, [debouncedOnChangeHandler]);

  return (
    <div
      onKeyDown={(e) => {
        backspacePressed.current = e.key === 'Backspace';
        if (backspacePressed.current) {
          e.stopPropagation(); // prevent global delete shortcut when backspace is pressed
        }
      }}
    >
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

          // If backspace triggered, skip calling handler until blur
          if (backspacePressed.current && isExpertMode) return;

          if (shouldTriggerChange || changedPropType === 'boolean') {
            if (updatedData.id === formData.id) {
              debouncedOnChangeHandler(updatedData);
              if (onfocusHandler) {
                onfocusHandler(true);
              }
            }
          }
        }}
        onFocus={() => {
          if (onfocusHandler) {
            onfocusHandler(false);
          }
        }}
        onBlur={(key, changed) => {
          // If backspace was pressed, trigger save now on blur
          console.log({
            key,
            changed,
            isExpertMode,
            backspacePressedcurrent: backspacePressed.current,
          });
          if (backspacePressed.current && isExpertMode) {
            backspacePressed.current = false;
            onChangeHandler(formData);
            if (onfocusHandler) {
              onfocusHandler(true);
            }
            return;
          }

          if (key === 'partPropertyElementFocus' && onfocusHandler) {
            onfocusHandler(false);
            return;
          }

          const dotPath = key.replace(/_/g, '.').replace('root.', '');
          const [newValue] = at(value as any, dotPath);
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
      </Form>
    </div>
  );
};
export default PropertyEditor;
