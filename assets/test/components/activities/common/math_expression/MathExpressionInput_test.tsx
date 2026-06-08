import React, { useState } from 'react';
import { act } from 'react-dom/test-utils';
import '@testing-library/jest-dom';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { previewMathExpressionSyntax } from 'gleam/torusExpression';
import { MathExpressionInput } from 'components/activities/common/math_expression/MathExpressionInput';
import type { MathExpressionInputProps } from 'components/activities/common/math_expression/MathExpressionInput';

jest.mock('gleam/torusExpression', () => ({
  previewMathExpressionSyntax: jest.fn(),
}));

const previewMock = previewMathExpressionSyntax as jest.Mock;

const defaultProps: MathExpressionInputProps = {
  value: '',
  validationKind: 'expression',
  layout: 'authoring',
  previewMode: 'below_input',
  ariaLabel: 'answer expression',
  onChange: jest.fn(),
};

const validResult = {
  status: 'valid',
  debug: 'valid expression',
  latex: '2x + 6',
};

const invalidResult = {
  status: 'invalid',
  debug: 'invalid expression',
};

const renderInput = (props: Partial<MathExpressionInputProps> = {}) =>
  render(<MathExpressionInput {...defaultProps} {...props} />);

const renderControlledInput = (props: Partial<MathExpressionInputProps> = {}) => {
  const Harness = () => {
    const [value, setValue] = useState(props.value ?? '');
    const [validateNowSignal, setValidateNowSignal] = useState(0);

    return (
      <>
        <MathExpressionInput
          {...defaultProps}
          {...props}
          value={value}
          validateNowSignal={validateNowSignal}
          onChange={setValue}
        />
        <button onClick={() => setValidateNowSignal((signal) => signal + 1)}>Validate now</button>
      </>
    );
  };

  return render(<Harness />);
};

// @ac "AC-005" Valid examples produce valid feedback through parser-backed results.
// @ac "AC-006" Invalid examples produce accessible invalid feedback.
// @ac "AC-007" Empty fields stay neutral.
// @ac "AC-008" Invalid state is exposed through aria-invalid and status text.
// @ac "AC-009" Validation is debounced during editing and immediate on blur/save signals.
// @ac "AC-010" Covered inputs render attached syntax help.
// @ac "AC-011" Syntax help has an accessible button label.
// @ac "AC-012" Syntax help opens by click and keyboard activation.
// @ac "AC-013" Syntax help closes by Escape and outside click.
// @ac "AC-014" Syntax help links to /help/math-syntax.
// @ac "AC-029" Inline layout avoids visible validation blocks that shift prose.
// @ac "AC-033" Component tests cover valid, invalid, empty, authoring, delivery, and inline modes.
// @ac "AC-034" Component tests cover keyboard help flow and accessible invalid state.
describe('MathExpressionInput', () => {
  let restoreMathJax: any;

  beforeEach(() => {
    jest.useFakeTimers();
    jest.clearAllMocks();
    restoreMathJax = window.MathJax;
    window.MathJax = {
      startup: { promise: Promise.resolve() },
      typesetPromise: jest.fn().mockResolvedValue(undefined),
    };
  });

  afterEach(() => {
    cleanup();
    window.MathJax = restoreMathJax;
    jest.useRealTimers();
  });

  it('keeps empty input neutral without parsing or previewing', () => {
    renderInput();

    const input = screen.getByLabelText('answer expression');
    expect(input).toHaveAttribute('aria-invalid', 'false');
    expect(previewMock).not.toHaveBeenCalled();
    expect(screen.queryByText('Preview')).not.toBeInTheDocument();
  });

  it('debounces valid syntax feedback', () => {
    previewMock.mockReturnValue(validResult);
    renderControlledInput();

    fireEvent.change(screen.getByLabelText('answer expression'), { target: { value: '2x + 6' } });

    expect(previewMock).not.toHaveBeenCalled();

    act(() => {
      jest.advanceTimersByTime(200);
    });

    expect(previewMock).toHaveBeenCalledWith('2x + 6', 'expression');
    expect(screen.getByText('Expression syntax looks valid.')).toBeInTheDocument();
  });

  it('validates immediately on blur without waiting for the debounce', () => {
    previewMock.mockReturnValue(validResult);
    const onBlur = jest.fn();
    renderControlledInput({ onBlur });

    const input = screen.getByLabelText('answer expression');
    fireEvent.change(input, { target: { value: '2x + 6' } });
    fireEvent.blur(input);

    expect(previewMock).toHaveBeenCalledWith('2x + 6', 'expression');
    expect(onBlur).toHaveBeenCalled();
  });

  it('validates immediately when an explicit validation signal changes', () => {
    previewMock.mockReturnValue(validResult);
    renderControlledInput({ value: '2x + 6' });

    fireEvent.click(screen.getByText('Validate now'));

    expect(previewMock).toHaveBeenCalledWith('2x + 6', 'expression');
  });

  it('marks invalid syntax accessibly and suppresses preview', () => {
    previewMock.mockReturnValue(invalidResult);
    renderControlledInput();

    fireEvent.change(screen.getByLabelText('answer expression'), { target: { value: '2^^3' } });
    act(() => {
      jest.advanceTimersByTime(200);
    });

    expect(screen.getByLabelText('answer expression')).toHaveAttribute('aria-invalid', 'true');
    expect(screen.getByRole('alert')).toHaveTextContent('Check the math syntax');
    expect(screen.queryByText('Preview')).not.toBeInTheDocument();
  });

  it('falls back to a controlled unknown state when parser preview fails', () => {
    previewMock.mockImplementation(() => {
      throw new Error('parser failed');
    });
    renderControlledInput();

    fireEvent.change(screen.getByLabelText('answer expression'), { target: { value: '2x + 6' } });
    act(() => {
      jest.advanceTimersByTime(200);
    });

    expect(
      screen.getByText('Syntax check is unavailable. You can keep typing.'),
    ).toBeInTheDocument();
    expect(screen.queryByText('Preview')).not.toBeInTheDocument();
  });

  it('opens help by click and provides an accessible Learn more link', () => {
    renderInput();

    const help = screen.getByRole('button', { name: 'Math expression syntax help' });
    fireEvent.mouseEnter(help);
    expect(screen.queryByText('Math expression syntax')).not.toBeInTheDocument();

    fireEvent.click(help);

    expect(screen.getByText('Math expression syntax')).toBeInTheDocument();
    const link = screen.getByRole('link', { name: 'Learn more' });
    expect(link).toHaveAttribute('href', '/help/math-syntax');
    expect(link).toHaveAttribute('target', '_blank');
    expect(link).toHaveAttribute('rel', 'noreferrer');

    fireEvent.mouseLeave(help);
    expect(screen.getByText('Math expression syntax')).toBeInTheDocument();
  });

  it('supports keyboard activation and Escape close for the help popover', () => {
    renderInput();

    const help = screen.getByRole('button', { name: 'Math expression syntax help' });
    fireEvent.keyDown(help, { key: 'Enter' });

    expect(screen.getByText('Math expression syntax')).toBeInTheDocument();

    fireEvent.keyDown(help, { key: 'Escape' });
    expect(screen.queryByText('Math expression syntax')).not.toBeInTheDocument();
  });

  it('closes help when the user clicks outside', () => {
    render(
      <>
        <MathExpressionInput {...defaultProps} />
        <button>Outside</button>
      </>,
    );

    const help = screen.getByRole('button', { name: 'Math expression syntax help' });
    fireEvent.focus(help);
    expect(screen.queryByText('Math expression syntax')).not.toBeInTheDocument();

    fireEvent.click(help);
    expect(screen.getByText('Math expression syntax')).toBeInTheDocument();

    fireEvent.mouseDown(screen.getByRole('link', { name: 'Learn more' }));
    expect(screen.getByText('Math expression syntax')).toBeInTheDocument();

    fireEvent.mouseDown(document.body);
    expect(screen.queryByText('Math expression syntax')).not.toBeInTheDocument();
  });

  it('does not allocate visible validation text or preview in inline multi-input mode', () => {
    previewMock.mockReturnValue(validResult);
    renderControlledInput({
      layout: 'inline_multi_input',
      previewMode: 'below_input',
      value: '2x + 6',
    });

    act(() => {
      jest.advanceTimersByTime(200);
    });

    expect(screen.queryByText('Preview')).not.toBeInTheDocument();
    expect(screen.getByText('Expression syntax looks valid.')).toHaveClass('sr-only');
  });

  it('anchors the single-response delivery help button to the input width', () => {
    renderInput({ layout: 'delivery_single' });

    const inputRow = screen
      .getByLabelText('answer expression')
      .closest('[data-math-expression-input-row="delivery_single"]');

    expect(inputRow).toHaveClass('w-[180px]');
    expect(inputRow).not.toHaveClass('w-full');
    expect(inputRow).toContainElement(
      screen.getByRole('button', { name: 'Math expression syntax help' }),
    );
  });
});
