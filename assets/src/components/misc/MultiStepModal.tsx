import React, { ReactNode, useCallback, useState } from 'react';
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

  return (
    <Card.Card
      className={`w-[32rem] fixed top-1/3 inset-x-0 mx-auto border-[1px] border-gray-100 dark:border-gray-500 ${className} z-50`}
    >
      <Card.Title>
        {/* Modal Title */}
        <div className="text-center text-xl font-semibold mb-4">{title}</div>
      </Card.Title>

      <Card.Content>
        {/* Stepper */}
        <hr className="mb-6 border-gray-200 dark:border-gray-600" />
        <div className="flex justify-center items-center mb-8 w-full max-w-3xl mx-auto">
          {stepTitles.map((label, index) => {
            const isCurrent = index === currentStep;

            return (
              <div className="flex flex-col w-full mb-2" key={index}>
                {/* Top row */}
                <div className="flex w-full space-x-2 items-center">
                  {/* Left connector */}
                  <div className={`flex-grow h-[2px] ${index > 0 ? 'bg-gray-300' : ''}`}></div>

                  {/* Middle dot (step number) */}
                  <div
                    className={`flex items-center justify-center w-8 h-8 rounded-full border-2 text-sm font-medium flex-shrink-0 ${
                      isCurrent
                        ? 'bg-blue-600 border-blue-600 text-white'
                        : 'bg-white border-gray-300 text-gray-500'
                    }`}
                  >
                    {index + 1}
                  </div>

                  {/* Right connector */}
                  <div
                    className={`flex-grow h-[2px] ${
                      index < stepTitles.length - 1 ? 'bg-gray-300' : ''
                    }`}
                  ></div>
                </div>

                {/* Bottom row: Step title */}
                <div
                  className={`w-full text-xs mt-2 text-center ${
                    isCurrent ? 'text-black font-medium' : 'text-gray-500'
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
          <Button onClick={onCancel} variant="secondary">
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
