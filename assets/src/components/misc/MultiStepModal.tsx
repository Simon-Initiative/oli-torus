import React, { ReactNode, useCallback, useEffect, useRef, useState } from 'react';
import { useToggle } from '../hooks/useToggle';
import { Button } from './Button';
import { Card } from './Card';

interface MultiStepModalProps {
  title: string;
  steps: ReactNode[];
  stepTitles: string[];
  onFinish: () => void;
  onCancel: () => void;
  finishText?: string;
  cancelText?: string;
  nextText?: string;
  backText?: string;
  allowBack?: boolean;
  className?: string;
}

// Selector for focusable elements
const FOCUSABLE_SELECTOR =
  'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

export const MultiStepModal: React.FC<MultiStepModalProps> = ({
  title,
  steps,
  stepTitles,
  onFinish,
  onCancel,
  finishText,
  cancelText,
  nextText,
  backText,
  allowBack,
  className,
}) => {
  const [currentStep, setCurrentStep] = useState(0);
  const totalSteps = steps.length;
  const modalRef = useRef<HTMLDivElement>(null);
  const previousActiveElement = useRef<HTMLElement | null>(null);
  const modalId = useRef(`multi-step-modal-${Math.random().toString(36).substr(2, 9)}`);

  const isLastStep = currentStep === totalSteps - 1;
  const isFirstStep = currentStep === 0;

  const handleNext = () => {
    if (!isLastStep) setCurrentStep((prev) => prev + 1);
  };

  const handleBack = () => {
    if (!isFirstStep) setCurrentStep((prev) => prev - 1);
  };

  const handleFinish = () => {
    onFinish();
  };

  // Focus trap handler
  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onCancel();
        return;
      }

      if (e.key !== 'Tab' || !modalRef.current) return;

      const focusableElements = modalRef.current.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR);
      if (focusableElements.length === 0) return;

      const firstElement = focusableElements[0];
      const lastElement = focusableElements[focusableElements.length - 1];

      if (e.shiftKey) {
        if (document.activeElement === firstElement) {
          e.preventDefault();
          lastElement.focus();
        }
      } else {
        if (document.activeElement === lastElement) {
          e.preventDefault();
          firstElement.focus();
        }
      }
    },
    [onCancel],
  );

  useEffect(() => {
    // Save the currently focused element to restore later
    previousActiveElement.current = document.activeElement as HTMLElement;

    // Focus the first focusable element when modal opens
    if (modalRef.current) {
      const focusableElements = modalRef.current.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR);
      if (focusableElements.length > 0) {
        focusableElements[0].focus();
      }
    }

    // Add keyboard listener for focus trap and escape
    document.addEventListener('keydown', handleKeyDown);

    return () => {
      document.removeEventListener('keydown', handleKeyDown);
      // Return focus to the element that triggered the modal
      if (previousActiveElement.current) {
        previousActiveElement.current.focus();
      }
    };
  }, [handleKeyDown]);

  const titleId = `${modalId.current}-title`;

  return (
    <div
      ref={modalRef}
      role="dialog"
      aria-modal="true"
      aria-labelledby={titleId}
      className="fixed inset-0 z-50 flex items-center justify-center"
    >
      {/* Backdrop */}
      <div className="fixed inset-0 bg-black/20" aria-hidden="true" onClick={onCancel} />

      <Card.Card
        className={`w-[32rem] relative border-[1px] border-gray-100 dark:border-gray-500 ${className}`}
      >
        <Card.Title>
          {/* Modal Title */}
          <div id={titleId} className="text-center text-xl font-semibold mb-4">
            {title}
          </div>
        </Card.Title>

        <Card.Content>
          {/* Stepper */}
          <hr className="mb-6 border-gray-200 dark:border-gray-600" />
          <div
            className="flex justify-center items-center mb-8 w-full max-w-3xl mx-auto"
            role="group"
            aria-label={`Step ${currentStep + 1} of ${totalSteps}`}
          >
            {stepTitles.map((label, index) => {
              const isCurrent = index === currentStep;

              return (
                <div className="flex flex-col w-full mb-2" key={index}>
                  {/* Top row */}
                  <div className="flex w-full space-x-2 items-center">
                    {/* Left connector */}
                    <div
                      className={`flex-grow h-[2px] ${
                        index > 0 ? 'bg-gray-300 dark:bg-gray-600' : ''
                      }`}
                    ></div>

                    {/* Middle dot (step number) */}
                    <div
                      className={`flex items-center justify-center w-8 h-8 rounded-full border-2 text-sm font-medium flex-shrink-0 ${
                        isCurrent
                          ? 'bg-blue-600 border-blue-600 text-white'
                          : 'bg-white border-gray-300 text-gray-500 dark:bg-gray-800 dark:border-gray-400 dark:text-gray-200'
                      }`}
                      aria-current={isCurrent ? 'step' : undefined}
                    >
                      {index + 1}
                    </div>

                    {/* Right connector */}
                    <div
                      className={`flex-grow h-[2px] ${
                        index < stepTitles.length - 1 ? 'bg-gray-300 dark:bg-gray-600' : ''
                      }`}
                    ></div>
                  </div>

                  {/* Bottom row: Step title */}
                  <div
                    className={`w-full text-xs mt-2 text-center ${
                      isCurrent
                        ? 'text-black dark:text-white font-medium'
                        : 'text-gray-500 dark:text-gray-400'
                    }`}
                  >
                    {label}
                  </div>
                </div>
              );
            })}
          </div>

          {/* Step Content */}
          <div className="mb-8">{steps[currentStep]}</div>

          {/* Footer buttons */}
          <div className="flex justify-end space-x-4">
            <Button className="border-[1px] border-blue-600" onClick={onCancel} variant="secondary">
              {cancelText}
            </Button>
            {allowBack && !isFirstStep && (
              <Button onClick={handleBack} variant="secondary">
                {backText}
              </Button>
            )}
            {!isLastStep ? (
              <Button onClick={handleNext}>{nextText}</Button>
            ) : (
              <Button onClick={handleFinish}>{finishText}</Button>
            )}
          </div>
        </Card.Content>
      </Card.Card>
    </div>
  );
};

MultiStepModal.defaultProps = {
  finishText: 'Finish',
  cancelText: 'Cancel',
  nextText: 'Next',
  backText: 'Back',
  allowBack: true,
  className: '',
};

export const useMultiStepModal = (
  steps: ReactNode[],
  stepTitles: string[],
  onFinish?: () => void,
  onCancel?: () => void,
  options?: {
    title?: string;
    finishText?: string;
    cancelText?: string;
    nextText?: string;
    backText?: string;
    allowBack?: boolean;
    className?: string;
  },
) => {
  const [isOpen, , showModal, hideModal] = useToggle();

  const onFinishHandler = useCallback(() => {
    hideModal();
    onFinish && onFinish();
  }, [hideModal, onFinish]);

  const onCancelHandler = useCallback(() => {
    hideModal();
    onCancel && onCancel();
  }, [hideModal, onCancel]);

  const Modal = isOpen ? (
    <MultiStepModal
      steps={steps}
      stepTitles={stepTitles}
      onFinish={onFinishHandler}
      onCancel={onCancelHandler}
      title={options?.title ?? 'Multi-Step Process'}
      finishText={options?.finishText}
      cancelText={options?.cancelText}
      nextText={options?.nextText}
      backText={options?.backText}
      allowBack={options?.allowBack}
      className={options?.className}
    />
  ) : null;

  return {
    isOpen,
    showModal,
    hideModal,
    Modal,
  };
};
