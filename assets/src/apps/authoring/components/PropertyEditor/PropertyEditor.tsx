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

/**
 * Module-level state to track focus across re-renders.
 *
 * lastFocusedInputId: The ID of the input that last had focus (e.g., "root_custom_title").
 *                     Used to restore focus after form re-renders caused by Redux updates.
 *
 * lastFocusedInputCursorPosition: The cursor position (start/end) of the last focused input.
 *                                  Used to restore cursor position when focus is restored.
 *
 * pointerDownOutside: Short-lived flag indicating if the last pointer down event occurred
 *                     outside the form. Used to distinguish between user-initiated outside
 *                     clicks and temporary blurs caused by re-renders.
 */
let lastFocusedInputId: string | null = null;
let lastFocusedInputCursorPosition: { start: number; end: number } | null = null;
let pointerDownOutside = false;

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
  const formContainerRef = useRef<HTMLDivElement>(null);

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

  /**
   * Restore focus after formData changes (triggered by Redux updates after debounced save).
   *
   * This effect runs whenever formData changes, which happens when:
   * 1. User types (local update)
   * 2. Redux state updates after debounced save (parent-driven update)
   *
   * We use double requestAnimationFrame to ensure the DOM is fully updated with new
   * form elements before attempting to restore focus.
   */
  useEffect(() => {
    if (!isExpertMode || !lastFocusedInputId) return;

    // Double RAF ensures DOM is fully updated after re-render
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        // Skip restoration if user clicked outside during render
        if (pointerDownOutside) return;

        const el = document.getElementById(lastFocusedInputId!);
        if (!el || !(el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement)) {
          return;
        }

        // Skip restoration if the element is already focused (user is actively editing)
        if (document.activeElement === el) {
          return;
        }

        try {
          el.focus();

          // Restore cursor position if we have it stored, otherwise position at end
          if (lastFocusedInputCursorPosition) {
            const len = el.value?.length ?? 0;
            const start = Math.min(lastFocusedInputCursorPosition.start, len);
            const end = Math.min(lastFocusedInputCursorPosition.end, len);
            el.setSelectionRange(start, end);
          } else {
            // Fallback: position cursor at end
            const len = el.value?.length ?? 0;
            el.setSelectionRange(len, len);
          }
        } catch (err) {
          // Ignore selection errors for input types that don't support setSelectionRange
        }
      });
    });
  }, [formData, isExpertMode]);

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

  /**
   * Track pointer down events to detect when user clicks outside the form.
   *
   * This is used to distinguish between:
   * - User-initiated outside clicks (should clear focus tracking)
   * - Temporary blurs caused by re-renders (should preserve focus tracking)
   *
   * We attach the listener to the document to catch clicks anywhere on the page,
   * but only set the flag if the click is outside this specific form instance.
   * This approach is necessary because we need to detect clicks outside the form
   * before the blur event fires, and using capture phase ensures we catch it early.
   *
   * Uses pointerdown event which unifies mouse, touch, and pen interactions.
   */
  useEffect(() => {
    if (!isExpertMode) return;

    const onPointerDown = (ev: PointerEvent) => {
      const target = ev.target as HTMLElement | null;
      const formRoot = formContainerRef.current?.querySelector('.rjsf');

      // Don't treat clicks on input elements as "outside" clicks
      const isInputElement =
        target &&
        (target.tagName === 'INPUT' ||
          target.tagName === 'TEXTAREA' ||
          target.closest('input, textarea'));

      // Only set flag if click is truly outside this form instance and we have focus to preserve
      const isOutside = formRoot && target && !formRoot.contains(target) && !isInputElement;
      pointerDownOutside = !!(isOutside && lastFocusedInputId);
    };

    /**
     * Track focus events from any input/textarea within the form, including custom widgets.
     * This ensures we capture focus from nested inputs that might not trigger RJSF's onFocus.
     */
    const onFocusCapture = (ev: FocusEvent) => {
      const target = ev.target as HTMLElement | null;
      if (!target) return;

      const formRoot = formContainerRef.current?.querySelector('.rjsf');
      if (!formRoot || !formRoot.contains(target)) return;

      if (target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement) {
        const targetId = target.id;
        // Track any input with an ID (including custom widget inputs)
        if (targetId) {
          lastFocusedInputId = targetId;
          lastFocusedInputCursorPosition = {
            start: target.selectionStart ?? 0,
            end: target.selectionEnd ?? 0,
          };
        }
      }
    };

    /**
     * Capture blur events to save cursor position before focus is lost.
     */
    const onBlurCapture = (ev: FocusEvent) => {
      const target = ev.target as HTMLElement | null;
      if (!target) return;

      const formRoot = formContainerRef.current?.querySelector('.rjsf');
      if (!formRoot || !formRoot.contains(target)) return;

      if (target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement) {
        const targetId = target.id;
        if (targetId && targetId === lastFocusedInputId) {
          lastFocusedInputCursorPosition = {
            start: target.selectionStart ?? 0,
            end: target.selectionEnd ?? 0,
          };
        }
      }
    };

    // Use capture phase to catch events before they bubble to other handlers
    // pointerdown unifies mouse, touch, and pen interactions
    document.addEventListener('pointerdown', onPointerDown, true);

    // Store the container element for cleanup
    const containerElement = formContainerRef.current;
    // Use capture phase for focus/blur to catch events from custom widgets
    containerElement?.addEventListener('focusin', onFocusCapture, true);
    containerElement?.addEventListener('focusout', onBlurCapture, true);

    return () => {
      document.removeEventListener('pointerdown', onPointerDown, true);
      containerElement?.removeEventListener('focusin', onFocusCapture, true);
      containerElement?.removeEventListener('focusout', onBlurCapture, true);
    };
  }, [isExpertMode]);

  return (
    <div
      ref={formContainerRef}
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

          // If backspace triggered skip calling handler until blur
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
        onFocus={(id) => {
          /**
           * Track the focused input ID and cursor position for restoration after re-renders.
           * RJSF may pass either a string ID or an event object depending on version.
           */
          if (isExpertMode) {
            try {
              let targetId: string | null = null;

              if (typeof id === 'string' && id.startsWith('root_')) {
                targetId = id;
                lastFocusedInputId = id;
              } else if (id && (id as any).target?.id) {
                const extractedId = (id as any).target.id;
                if (
                  extractedId &&
                  typeof extractedId === 'string' &&
                  extractedId.startsWith('root_')
                ) {
                  targetId = extractedId;
                  lastFocusedInputId = extractedId;
                }
              }

              // Capture cursor position from the active element
              if (targetId) {
                const el = document.getElementById(targetId);
                if (el && (el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement)) {
                  lastFocusedInputCursorPosition = {
                    start: el.selectionStart ?? 0,
                    end: el.selectionEnd ?? 0,
                  };
                }
              }
            } catch (e) {
              // Silently handle extraction errors
            }
          }

          if (onfocusHandler) {
            onfocusHandler(false);
          }
        }}
        onBlur={(key, changed) => {
          /**
           * Handle blur events with focus tracking logic.
           *
           * Only clear lastFocusedInputId if:
           * 1. User clicked outside the form (pointerDownOutside === true)
           * 2. Focus is not moving to another input within the form
           *
           * This prevents clearing focus tracking on temporary blurs caused by re-renders,
           * allowing focus to be restored after the form updates.
           */
          if (isExpertMode) {
            const wasPointerDownOutside = pointerDownOutside;

            // Capture cursor position before blur if we have a tracked input
            if (lastFocusedInputId) {
              const el = document.getElementById(lastFocusedInputId);
              if (el && (el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement)) {
                lastFocusedInputCursorPosition = {
                  start: el.selectionStart ?? 0,
                  end: el.selectionEnd ?? 0,
                };
              }
            }

            // Check if focus is moving to another input in the form
            const activeElement = document.activeElement;
            const formRoot = formContainerRef.current?.querySelector('.rjsf');
            const focusMovingToFormInput =
              formRoot &&
              activeElement &&
              (activeElement.tagName === 'INPUT' || activeElement.tagName === 'TEXTAREA') &&
              formRoot.contains(activeElement);

            // Only clear if user clicked outside AND focus is not moving to another form input
            if (wasPointerDownOutside && !focusMovingToFormInput) {
              lastFocusedInputId = null;
              lastFocusedInputCursorPosition = null;
            }

            // Reset flag for next interaction
            pointerDownOutside = false;
          }
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
