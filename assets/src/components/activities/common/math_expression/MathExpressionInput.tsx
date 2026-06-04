import React, { useCallback, useEffect, useRef, useState } from 'react';
import { previewMathExpressionSyntax } from 'gleam/torusExpression';
import type { MathExpressionPreviewResult, MathExpressionSyntaxKind } from 'gleam/torusExpression';
import { MultiInputSize } from 'components/activities/multi_input/schema';
import { MathJaxLatexFormula } from 'components/common/MathJaxFormula';
import { classNames } from 'utils/classNames';

export type MathExpressionLayout = 'authoring' | 'delivery_single' | 'inline_multi_input';
export type MathExpressionPreviewMode = 'none' | 'below_input' | 'right_of_input';

type ValidationState =
  | MathExpressionPreviewResult
  | { status: 'checking'; debug: string; source: string };

export interface MathExpressionInputProps {
  value: string;
  validationKind: MathExpressionSyntaxKind;
  layout: MathExpressionLayout;
  previewMode: MathExpressionPreviewMode;
  ariaLabel: string;
  describedBy?: string;
  disabled?: boolean;
  placeholder?: string;
  size?: MultiInputSize;
  id?: string;
  className?: string;
  debounceMs?: number;
  validateNowSignal?: unknown;
  onChange: (value: string) => void;
  onBlur?: () => void;
  onKeyUp?: (e: React.KeyboardEvent<HTMLInputElement | HTMLTextAreaElement>) => void;
  onValidationChange?: (result: MathExpressionPreviewResult) => void;
}

const helpUrl = '/help/math-syntax';
const defaultDebounceMs = 200;
let nextInputId = 0;

const safePreview = (
  expression: string,
  validationKind: MathExpressionSyntaxKind,
): MathExpressionPreviewResult => {
  try {
    return previewMathExpressionSyntax(expression, validationKind);
  } catch (_error) {
    // Keep raw author and learner expressions out of logs if generated parser
    // code fails; callers only need the controlled failure category here.
    return { status: 'unknown', debug: 'syntax preview unavailable' };
  }
};

const visibleStatusText = (state: ValidationState): string | undefined => {
  switch (state.status) {
    case 'valid':
      return 'Expression syntax looks valid.';
    case 'invalid':
      return 'Check the math syntax. Open help for examples.';
    case 'unknown':
      return 'Syntax check is unavailable. You can keep typing.';
    case 'checking':
      return 'Checking syntax.';
    case 'empty':
      return undefined;
  }
};

const statusTone = (state: ValidationState) => {
  switch (state.status) {
    case 'valid':
      return 'input-success border-green-600 focus:border-green-700 focus:ring-green-600';
    case 'invalid':
      return 'input-error border-red-600 focus:border-red-700 focus:ring-red-600';
    case 'unknown':
      return 'border-yellow-600 focus:border-yellow-700 focus:ring-yellow-600';
    default:
      return 'border-gray-300 focus:border-blue-600 focus:ring-blue-600 dark:border-gray-600';
  }
};

const layoutClass = (layout: MathExpressionLayout) => {
  switch (layout) {
    case 'inline_multi_input':
      return 'relative inline-flex align-baseline';
    case 'authoring':
      return 'relative w-full max-w-xl';
    case 'delivery_single':
      return 'relative w-full max-w-2xl';
  }
};

const deliverySingleInputWidthClass = (size?: MultiInputSize) => {
  switch (size) {
    case 'small':
      return 'w-[80px] max-w-full';
    case 'large':
      return 'w-[380px] max-w-full';
    case 'medium':
    default:
      return 'w-[180px] max-w-full';
  }
};

const inputRowClass = (layout: MathExpressionLayout, size?: MultiInputSize) =>
  classNames(
    'relative flex items-center',
    layout === 'inline_multi_input' && 'w-full',
    layout === 'authoring' && 'w-full',
    layout === 'delivery_single' && deliverySingleInputWidthClass(size),
  );

const inputClass = (layout: MathExpressionLayout, state: ValidationState, size?: MultiInputSize) =>
  classNames(
    'rounded-md border-2 bg-white text-gray-900 shadow-sm transition-colors',
    'placeholder-gray-400 disabled:bg-gray-100 disabled:text-gray-600',
    'dark:bg-body-dark dark:text-body-color-dark dark:placeholder-gray-500 dark:disabled:bg-gray-800 dark:disabled:text-gray-500',
    'focus:outline-none focus:ring-2 focus:ring-offset-1 dark:focus:ring-offset-gray-900',
    statusTone(state),
    layout === 'inline_multi_input'
      ? 'h-9 min-w-[5rem] pr-8 text-sm'
      : 'min-h-[2.5rem] w-full pr-10',
    size && `input-size-${size}`,
  );

const useMathExpressionValidation = ({
  value,
  validationKind,
  debounceMs,
  validateNowSignal,
  onValidationChange,
}: Pick<
  MathExpressionInputProps,
  'value' | 'validationKind' | 'debounceMs' | 'validateNowSignal' | 'onValidationChange'
>) => {
  const [state, setState] = useState<ValidationState>({ status: 'empty' });
  const lastValidateNowSignal = useRef(validateNowSignal);
  const pendingTimer = useRef<number | undefined>();
  const trimmed = value.trim();

  const clearPendingTimer = useCallback(() => {
    if (pendingTimer.current !== undefined) {
      window.clearTimeout(pendingTimer.current);
      pendingTimer.current = undefined;
    }
  }, []);

  const validate = useCallback(() => {
    clearPendingTimer();
    const result = safePreview(trimmed, validationKind);
    setState(result);
    onValidationChange?.(result);
    return result;
  }, [clearPendingTimer, onValidationChange, trimmed, validationKind]);

  useEffect(() => {
    if (trimmed === '') {
      const empty: MathExpressionPreviewResult = { status: 'empty' };
      setState(empty);
      onValidationChange?.(empty);
      return;
    }

    setState({ status: 'checking', debug: 'checking', source: trimmed });
    // Editing is debounced to avoid parser work on every keystroke; blur and
    // explicit validation signals call the same parser path immediately.
    pendingTimer.current = window.setTimeout(validate, debounceMs ?? defaultDebounceMs);
    return clearPendingTimer;
  }, [clearPendingTimer, debounceMs, onValidationChange, trimmed, validate, validationKind]);

  useEffect(() => {
    if (lastValidateNowSignal.current === validateNowSignal) {
      return;
    }

    lastValidateNowSignal.current = validateNowSignal;
    if (trimmed !== '') validate();
  }, [trimmed, validate, validateNowSignal]);

  return { state, validate };
};

export const MathExpressionInput: React.FC<MathExpressionInputProps> = ({
  value,
  validationKind,
  layout,
  previewMode,
  ariaLabel,
  describedBy,
  disabled,
  placeholder,
  size,
  id,
  className,
  debounceMs,
  validateNowSignal,
  onChange,
  onBlur,
  onKeyUp,
  onValidationChange,
}) => {
  const [generatedId] = useState(() => `math-expression-${nextInputId++}`);
  const inputId = id ?? generatedId;
  const statusId = `${inputId}-status`;
  const helpId = `${inputId}-help`;
  const { state, validate } = useMathExpressionValidation({
    value,
    validationKind,
    debounceMs,
    validateNowSignal,
    onValidationChange,
  });
  const [showDeliveryPreview, setShowDeliveryPreview] = useState(true);
  const statusText = visibleStatusText(state);
  const isInline = layout === 'inline_multi_input';
  const RootTag = isInline ? 'span' : 'div';
  const describedByIds = [describedBy, statusText ? statusId : undefined, helpId]
    .filter(Boolean)
    .join(' ');

  const previewLatex =
    previewMode !== 'none' && state.status === 'valid' && value.trim() !== ''
      ? state.latex
      : undefined;
  const showRightPreview = previewMode === 'right_of_input' && !isInline;
  const useFloatingDeliveryPreview = showRightPreview && layout === 'delivery_single';

  return (
    <RootTag
      className={classNames(layoutClass(layout), className)}
      data-math-expression-layout={layout}
    >
      {useFloatingDeliveryPreview ? (
        <span
          className="flex flex-row flex-wrap items-center gap-3"
          data-math-expression-preview-placement="right_of_input"
        >
          <span className={inputRowClass(layout, size)} data-math-expression-input-row={layout}>
            <input
              id={inputId}
              type="text"
              aria-label={ariaLabel}
              aria-invalid={state.status === 'invalid'}
              aria-describedby={describedByIds || undefined}
              placeholder={placeholder}
              className={inputClass(layout, state, size)}
              value={value}
              disabled={typeof disabled === 'boolean' ? disabled : false}
              onChange={(e) => onChange(e.target.value)}
              onBlur={() => {
                validate();
                onBlur?.();
              }}
              onKeyUp={onKeyUp}
            />
            <MathExpressionHelpPopover describedById={helpId} inline={isInline} />
            {showDeliveryPreview && previewLatex && (
              <MathExpressionPreview latex={previewLatex} placement="right_of_input" floating />
            )}
          </span>
          <label className="inline-flex min-h-[2.5rem] items-center gap-2 text-sm text-gray-700 dark:text-gray-200">
            <input
              type="checkbox"
              className="h-4 w-4 rounded border-gray-300 text-blue-700 focus:ring-blue-600"
              checked={showDeliveryPreview}
              onChange={(event) => setShowDeliveryPreview(event.target.checked)}
            />
            <span>Show Preview</span>
          </label>
        </span>
      ) : showRightPreview ? (
        <span
          className="flex flex-row flex-wrap items-start gap-2"
          data-math-expression-preview-placement="right_of_input"
        >
          <span className={inputRowClass(layout, size)} data-math-expression-input-row={layout}>
            <input
              id={inputId}
              type="text"
              aria-label={ariaLabel}
              aria-invalid={state.status === 'invalid'}
              aria-describedby={describedByIds || undefined}
              placeholder={placeholder}
              className={inputClass(layout, state, size)}
              value={value}
              disabled={typeof disabled === 'boolean' ? disabled : false}
              onChange={(e) => onChange(e.target.value)}
              onBlur={() => {
                validate();
                onBlur?.();
              }}
              onKeyUp={onKeyUp}
            />
            <MathExpressionHelpPopover describedById={helpId} inline={isInline} />
          </span>
          <MathExpressionPreview latex={previewLatex} placement="right_of_input" collapsible />
        </span>
      ) : (
        <span className={inputRowClass(layout, size)} data-math-expression-input-row={layout}>
          <input
            id={inputId}
            type="text"
            aria-label={ariaLabel}
            aria-invalid={state.status === 'invalid'}
            aria-describedby={describedByIds || undefined}
            placeholder={placeholder}
            className={inputClass(layout, state, size)}
            value={value}
            disabled={typeof disabled === 'boolean' ? disabled : false}
            onChange={(e) => onChange(e.target.value)}
            onBlur={() => {
              validate();
              onBlur?.();
            }}
            onKeyUp={onKeyUp}
          />
          <MathExpressionHelpPopover describedById={helpId} inline={isInline} />
        </span>
      )}

      {statusText && (
        <span
          id={statusId}
          role={state.status === 'invalid' ? 'alert' : 'status'}
          className={classNames(
            isInline ? 'sr-only' : 'mt-1 block text-sm',
            state.status === 'valid' && 'text-green-700 dark:text-green-300',
            state.status === 'invalid' && 'text-red-700 dark:text-red-300',
            state.status === 'unknown' && 'text-yellow-700 dark:text-yellow-300',
            state.status === 'checking' && 'text-gray-600 dark:text-gray-300',
          )}
        >
          {statusText}
        </span>
      )}

      {/* Inline blanks live in prose, so previews are intentionally suppressed
          there to avoid layout shifts and MathJax work while students type. */}
      {previewLatex && !isInline && previewMode === 'below_input' && (
        <MathExpressionPreview latex={previewLatex} placement="below_input" />
      )}
    </RootTag>
  );
};

interface HelpPopoverProps {
  describedById: string;
  inline: boolean;
}

export const MathExpressionHelpPopover: React.FC<HelpPopoverProps> = ({
  describedById,
  inline,
}) => {
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLSpanElement>(null);
  const popoverId = `${describedById}-popover`;

  useEffect(() => {
    if (!open) return;

    const closeWhenClickLeaves = (event: MouseEvent) => {
      if (!rootRef.current?.contains(event.target as Node)) setOpen(false);
    };

    // The popover is click-triggered so the pointer can move into the panel
    // and activate the Learn more link without hover or focus loss hiding it.
    document.addEventListener('mousedown', closeWhenClickLeaves);
    return () => {
      document.removeEventListener('mousedown', closeWhenClickLeaves);
    };
  }, [open]);

  return (
    <span
      ref={rootRef}
      className="absolute right-2 top-1/2 z-10 -translate-y-1/2"
      onKeyDown={(event) => {
        if (event.key === 'Escape') {
          setOpen(false);
        }
      }}
    >
      <span id={describedById} className="sr-only">
        Open math expression syntax help for examples.
      </span>
      <button
        type="button"
        aria-label="Math expression syntax help"
        aria-expanded={open}
        aria-controls={popoverId}
        className={classNames(
          'flex h-6 w-6 items-center justify-center rounded-full border text-xs font-bold',
          'border-blue-700 bg-white text-blue-800 shadow-sm hover:bg-blue-50 focus:outline-none focus:ring-2 focus:ring-blue-600',
          'dark:border-blue-300 dark:bg-gray-900 dark:text-blue-200 dark:hover:bg-gray-800',
          inline && 'h-5 w-5 text-[11px]',
        )}
        onClick={() => setOpen((current) => !current)}
        onKeyDown={(event) => {
          if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            setOpen((current) => !current);
          }
        }}
      >
        ?
      </button>
      {open && (
        <span
          id={popoverId}
          className={classNames(
            'absolute right-0 top-8 z-20 block w-72 rounded-md border border-gray-200 bg-white p-3 text-left text-sm text-gray-800 shadow-lg',
            'dark:border-gray-700 dark:bg-gray-900 dark:text-gray-100',
            inline && 'top-7 w-64',
          )}
        >
          <span className="block font-semibold text-gray-900 dark:text-gray-50">
            Math expression syntax
          </span>
          <span className="mt-2 block text-gray-700 dark:text-gray-200">
            Try entries like <code>2x + 6</code>, <code>sqrt(2)/2</code>, <code>x^2</code>,{' '}
            <code>sin(x)</code>, <code>pi</code>, or <code>9.8 m/s^2</code>.
          </span>
          <a
            className="mt-3 inline-flex font-medium text-blue-700 underline hover:text-blue-900 dark:text-blue-300 dark:hover:text-blue-100"
            href={helpUrl}
            target="_blank"
            rel="noreferrer"
          >
            Learn more
          </a>
        </span>
      )}
    </span>
  );
};

interface PreviewProps {
  latex?: string;
  placement?: Exclude<MathExpressionPreviewMode, 'none'>;
  collapsible?: boolean;
  floating?: boolean;
}

export const MathExpressionPreview: React.FC<PreviewProps> = ({
  latex,
  placement = 'below_input',
  collapsible = false,
  floating = false,
}) => {
  const [previewId] = useState(() => `math-expression-preview-${nextInputId++}`);
  const [collapsed, setCollapsed] = useState(false);
  const previewContentId = `${previewId}-content`;

  return (
    <span
      className={classNames(
        'block rounded-md border border-gray-200 bg-gray-50 px-3 py-2 text-gray-900 shadow-lg dark:border-gray-700 dark:bg-gray-900 dark:text-gray-100',
        placement === 'below_input' && 'mt-2 shadow-none',
        placement === 'right_of_input' && 'min-w-[12rem] max-w-[min(24rem,calc(100vw-2rem))]',
        placement === 'right_of_input' && (collapsed ? 'min-h-0' : 'min-h-[4.75rem]'),
        floating && 'absolute bottom-full left-0 z-20 mb-2 sm:left-full sm:ml-3',
      )}
      data-math-expression-preview={placement}
      data-math-expression-preview-collapsed={collapsed ? 'true' : 'false'}
      data-math-expression-preview-floating={floating ? 'true' : undefined}
    >
      <span className="mb-1 flex items-center justify-between gap-2">
        <span className="block text-xs font-semibold uppercase text-gray-500 dark:text-gray-400">
          Preview
        </span>
        {collapsible && (
          <button
            type="button"
            aria-controls={previewContentId}
            aria-expanded={!collapsed}
            className="rounded px-1.5 py-0.5 text-xs font-medium text-blue-700 hover:bg-blue-50 focus:outline-none focus:ring-2 focus:ring-blue-600 dark:text-blue-300 dark:hover:bg-gray-800"
            onClick={() => setCollapsed((current) => !current)}
          >
            {collapsed ? 'Show' : 'Hide'}
          </button>
        )}
      </span>
      {!collapsed && (
        <span id={previewContentId} className="block min-h-[1.875rem]">
          {latex && (
            <MathJaxLatexFormula
              id={previewId}
              src={latex}
              inline={false}
              formulaAltText="Rendered math expression preview"
            />
          )}
        </span>
      )}
    </span>
  );
};
