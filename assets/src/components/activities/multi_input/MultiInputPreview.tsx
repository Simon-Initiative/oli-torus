import React from 'react';
import { usePreviewElementContext } from 'components/activities/PreviewElementProvider';
import { ActivityPreviewCard } from 'components/activities/common/preview/ActivityPreviewCard';
import { PreviewChoiceList } from 'components/activities/common/preview/PreviewChoiceList';
import { PreviewExplanationPanel } from 'components/activities/common/preview/PreviewExplanationPanel';
import { PreviewHintsPanel } from 'components/activities/common/preview/PreviewHintsPanel';
import { PreviewRichText } from 'components/activities/common/preview/PreviewRichText';
import { PreviewTab } from 'components/activities/common/preview/types';
import { GradingApproach, Response } from 'components/activities/types';
import { getCorrectChoice } from 'components/activities/multiple_choice/utils';
import { MultiInputDelivery } from 'components/activities/multi_input/schema';
import { getTargetedResponses } from 'components/activities/short_answer/utils';
import {
  getCorrectResponse,
  getIncorrectResponse,
  getOutOfPoints,
} from 'data/activities/model/responses';
import {
  InputKind,
  NumericOperator,
  RangeOperator,
  TextOperator,
  parseInputFromRule,
} from 'data/activities/model/rules';
import { defaultWriterContext } from 'data/content/writers/context';
import { Dropdown, MultiInputSchema } from './schema';
import { friendlyType, getOrderedPartIds } from './utils';

const textOperatorLabels: Record<TextOperator, string> = {
  contains: 'Contains',
  notcontains: "Doesn't Contain",
  regex: 'Regex',
  equals: 'Equals exactly',
  iequals: 'Equals ignoring case',
};

const numericOperatorLabels: Record<NumericOperator, string> = {
  gt: 'Greater than',
  gte: 'Greater than or equal to',
  lt: 'Less than',
  lte: 'Less than or equal to',
  eq: 'Equal to',
  neq: 'Not equal to',
};

const rangeOperatorLabels: Record<RangeOperator, string> = {
  btw: 'Between',
  nbtw: 'Not between',
};

const readonlyControlClasses =
  'flex h-[30px] items-center rounded-[6px] border border-Border-border-default bg-Specially-Tokens-Fill-fill-input-focused px-4 py-2 font-open-sans text-[14px] font-normal leading-[24px] tracking-normal text-Text-text-high';

const readonlyLabelClasses =
  'rounded-[6px] border border-Specially-Tokens-Border-border-input bg-Specially-Tokens-Fill-fill-input px-2 py-2 font-open-sans text-[14px] font-normal leading-[16px] tracking-normal text-Text-text-high';

const sectionTitleClasses =
  'font-open-sans text-[16px] font-semibold leading-[24px] tracking-normal text-Text-text-high';

const supportingTextClasses =
  'font-open-sans text-[14px] font-normal leading-[21px] tracking-normal text-Text-text-low-alpha';

const previewTypeLabel = (inputType: string) =>
  inputType === 'numeric' ? 'Numeric' : friendlyType(inputType as any);

const pointsLabel = (points: number) => `${points} ${points === 1 ? 'point' : 'points'}`;

const CheckboxIndicator: React.FC<{ checked?: boolean }> = ({ checked = false }) => (
  <div
    className={`h-4 w-4 shrink-0 rounded-[2px] border ${
      checked
        ? 'border-Border-border-bold bg-Fill-Buttons-fill-primary-muted'
        : 'border-Border-border-active bg-Surface-surface-primary'
    }`}
    aria-hidden="true"
  >
    {checked ? (
      <div className="flex h-full items-center justify-center text-[10px] leading-none text-Fill-Buttons-fill-primary">
        ✓
      </div>
    ) : null}
  </div>
);

const PreviewCheckboxLabel: React.FC<{ label: string; checked?: boolean }> = ({
  label,
  checked = true,
}) => (
  <div className="flex items-center gap-[5px]">
    <CheckboxIndicator checked={checked} />
    <div className="font-open-sans text-[16px] font-normal leading-[24px] tracking-normal text-Text-text-high">
      {label}
    </div>
  </div>
);

const FeedbackBox: React.FC<{ response: Response }> = ({ response }) => (
  <div className="rounded-[6px] border border-Border-border-default bg-Specially-Tokens-Fill-fill-input-focused px-4 py-2">
    <PreviewRichText
      content={response.feedback.content}
      direction={response.feedback.textDirection || 'auto'}
      className="font-open-sans text-[16px] font-medium leading-[24px] tracking-normal text-Text-text-high [&_.content_p]:my-0"
    />
  </div>
);

const FeedbackSection: React.FC<{
  title: string;
  response?: Response | null;
}> = ({ title, response }) => {
  if (!response) {
    return null;
  }

  return (
    <div className="flex flex-col gap-[9px]">
      <div className={sectionTitleClasses}>{title}</div>
      <FeedbackBox response={response} />
    </div>
  );
};

const RuleRow: React.FC<{ rule: string }> = ({ rule }) =>
  parseInputFromRule(rule).caseOf({
    just: (input) => {
      if (input.kind === InputKind.Text) {
        return (
          <div className="flex flex-wrap items-center gap-[9px]">
            <div className={readonlyLabelClasses}>{textOperatorLabels[input.operator]}</div>
            <div className={`${readonlyControlClasses} min-w-[220px] flex-1`}>{input.value}</div>
          </div>
        );
      }

      if (input.kind === InputKind.Numeric) {
        return (
          <div className="flex flex-wrap items-center gap-[9px]">
            <div className={readonlyLabelClasses}>{numericOperatorLabels[input.operator]}</div>
            <div className={`${readonlyControlClasses} min-w-[40px]`}>{input.value}</div>
            {input.precision !== undefined ? (
              <>
                <PreviewCheckboxLabel label="Significant figures" />
                <div className={`${readonlyControlClasses} min-w-[40px]`}>{input.precision}</div>
              </>
            ) : null}
          </div>
        );
      }

      return (
        <div className="flex flex-wrap items-start gap-[9px]">
          <div className={readonlyLabelClasses}>{rangeOperatorLabels[input.operator]}</div>
          <div className={`${readonlyControlClasses} min-w-[60px]`}>{input.lowerBound}</div>
          <div className="font-open-sans text-[16px] font-normal leading-[24px] tracking-normal text-Text-text-high">
            and
          </div>
          <div className={`${readonlyControlClasses} min-w-[60px]`}>{input.upperBound}</div>
          <div className={readonlyLabelClasses}>{input.inclusive ? 'Inclusive' : 'Exclusive'}</div>
          {input.precision !== undefined ? (
            <>
              <PreviewCheckboxLabel label="Significant figures" />
              <div className={`${readonlyControlClasses} min-w-[40px]`}>{input.precision}</div>
            </>
          ) : null}
        </div>
      );
    },
    nothing: () => <div className="text-sm text-Text-text-high">{rule}</div>,
  });

const MainAnswerKeyFields: React.FC<{
  gradingApproach?: GradingApproach;
  rule: string;
}> = ({ gradingApproach, rule }) => (
  <div className="flex flex-col gap-[9px]">
    <div className="flex flex-wrap items-center gap-[9px]">
      <div className={sectionTitleClasses}>Grading Approach:</div>
      <div className="font-open-sans text-[14px] font-normal leading-[16px] tracking-normal text-Text-text-high">
        {gradingApproach === GradingApproach.manual ? 'Instructor manual grading' : 'Automatic'}
      </div>
    </div>
    <RuleRow rule={rule} />
  </div>
);

const NumericTargetedFeedback: React.FC<{ response: Response }> = ({ response }) => (
  <div className="flex flex-col gap-[9px]">
    <div className="flex flex-wrap items-center gap-[9px]">
      <div className={sectionTitleClasses}>Targeted Feedback</div>
      <div className={supportingTextClasses}>{pointsLabel(response.score ?? 0)}</div>
    </div>
    <RuleRow rule={response.rule} />
    <FeedbackBox response={response} />
  </div>
);

const TextTargetedFeedback: React.FC<{ response: Response }> = ({ response }) => (
  <div className="flex flex-col gap-[9px]">
    <div className="flex flex-wrap items-center justify-between gap-[9px]">
      <div className={sectionTitleClasses}>Targeted Feedback</div>
      {response.correct ? <PreviewCheckboxLabel label="Correct" /> : null}
    </div>
    <FeedbackBox response={response} />
    <RuleRow rule={response.rule} />
  </div>
);

export const MultiInputPreview: React.FC = () => {
  const { model, previewContext, writerContext } = usePreviewElementContext<MultiInputSchema>();
  const [selectedPartId, setSelectedPartId] = React.useState(model.inputs[0]?.partId || '');

  const selectedInput =
    model.inputs.find((input) => input.partId === selectedPartId) || model.inputs[0];
  const partId = selectedInput?.partId || model.authoring.parts[0].id;
  const part =
    model.authoring.parts.find((candidate) => candidate.id === partId) || model.authoring.parts[0];
  const correctResponse = getCorrectResponse(model, part.id);
  const incorrectResponse = getIncorrectResponse(model, part.id);
  const targetedResponses = getTargetedResponses(model, part.id);
  const orderedPartIds = React.useMemo(() => getOrderedPartIds(model), [model]);
  const selectedPartIndex = Math.max(orderedPartIds.indexOf(part.id), 0);
  const showPartHeader = model.inputs.length > 1;

  const previewInputs = React.useMemo(
    () =>
      new Map(
        model.inputs.map((input) => {
          const inputData: MultiInputDelivery =
            input.inputType === 'dropdown'
              ? {
                  id: input.id,
                  inputType: 'dropdown',
                  options: [{ value: '__preview__', displayValue: 'Dropdown' }],
                  size: input.size,
                }
              : {
                  id: input.id,
                  inputType: input.inputType,
                  size: input.size,
                };

          return [
            input.id,
            {
              input: inputData,
              value: previewTypeLabel(input.inputType),
              placeholder: previewTypeLabel(input.inputType),
              hasHints: false,
            },
          ];
        }),
      ),
    [model.inputs],
  );

  const previewStemContext = React.useMemo(
    () =>
      defaultWriterContext({
        ...writerContext,
        inputRefContext: {
          onBlur: () => null,
          onPressEnter: () => null,
          onChange: () => null,
          toggleHints: () => null,
          inputs: previewInputs,
          disabled: true,
          selectedInputId: selectedInput?.id,
          onSelectInput: (id: string) => {
            const input = model.inputs.find((candidate) => candidate.id === id);
            if (input) {
              setSelectedPartId(input.partId);
            }
          },
        },
      }),
    [model.inputs, previewInputs, selectedInput?.id, writerContext],
  );

  const answerKeySummary =
    selectedInput?.inputType === 'dropdown' ? (
      <PreviewChoiceList
        choices={model.choices.filter((choice) =>
          (selectedInput as Dropdown).choiceIds.includes(choice.id),
        )}
        selectedChoiceIds={getCorrectChoice(model, part.id).caseOf({
          just: (choice) => [choice.id],
          nothing: () => [],
        })}
      />
    ) : (
      <MainAnswerKeyFields gradingApproach={part.gradingApproach} rule={correctResponse.rule} />
    );

  const detailsHeader = showPartHeader ? (
    <div className="flex items-center gap-4">
      <div className="font-open-sans text-[16px] font-bold leading-[16px] tracking-normal text-Text-text-high">
        {`Part ${selectedPartIndex + 1}: ${previewTypeLabel(selectedInput?.inputType || 'text')}`}
      </div>
      <div className={supportingTextClasses}>{pointsLabel(getOutOfPoints(model, part.id))}</div>
    </div>
  ) : undefined;

  const detailTabs: PreviewTab[] = [
    {
      id: 'answer-key',
      label: 'Answer Key',
      content: (
        <div className="flex flex-col gap-[9px]">
          {answerKeySummary}
          <FeedbackSection title="Feedback for correct answer:" response={correctResponse} />
          <FeedbackSection title="Feedback for incorrect answer:" response={incorrectResponse} />
          {selectedInput?.inputType === 'numeric'
            ? targetedResponses.map((response) => (
                <NumericTargetedFeedback key={response.id} response={response} />
              ))
            : selectedInput?.inputType === 'text'
              ? targetedResponses.map((response) => (
                  <TextTargetedFeedback key={response.id} response={response} />
                ))
              : null}
        </div>
      ),
    },
    {
      id: 'hints',
      label: 'Hints',
      content: <PreviewHintsPanel hints={part.hints || []} />,
    },
    {
      id: 'explanation',
      label: 'Explanation',
      content: <PreviewExplanationPanel model={model} partId={part.id} />,
    },
  ];

  return (
    <ActivityPreviewCard
      previewContext={previewContext}
      detailTabs={detailTabs}
      detailsHeader={detailsHeader}
    >
      <div className="flex flex-col gap-4">
        <PreviewRichText
          content={model.stem.content}
          context={previewStemContext}
          direction={model.stem.textDirection || 'auto'}
          className="text-lg leading-8 text-Text-text-high"
        />
      </div>
    </ActivityPreviewCard>
  );
};
