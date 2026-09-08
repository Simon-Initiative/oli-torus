import React, { useState } from 'react';
import { AccessibilityFindingItem } from 'apps/authoring/store/groups/layouts/deck/actions/accessibilityAudit';
import guid from 'utils/guid';
import { SolutionProps } from './SolutionProps';
import { getAccessibilityFixConfig } from './accessibilityFixConfig';

interface FixAccessibilityFieldProps extends SolutionProps {
  item: AccessibilityFindingItem;
  onMarkDecorative?: () => Promise<void>;
}

export const FixAccessibilityField: React.FC<FixAccessibilityFieldProps> = ({
  suggestion,
  onClick,
  item,
  onMarkDecorative,
}: FixAccessibilityFieldProps): JSX.Element | null => {
  const config = getAccessibilityFixConfig(item);
  const [isApplying, setIsApplying] = useState(false);
  const [isMarkingDecorative, setIsMarkingDecorative] = useState(false);
  const txtRef = React.useRef<HTMLInputElement | HTMLTextAreaElement>(null);
  const uuid = guid();

  if (!config) {
    return null;
  }

  const handleApply = async () => {
    if (!txtRef.current || !onClick || isApplying) {
      return;
    }
    setIsApplying(true);
    try {
      await onClick(txtRef.current.value);
    } finally {
      setIsApplying(false);
    }
  };

  const handleMarkDecorative = async () => {
    if (!onMarkDecorative || isMarkingDecorative || isApplying) {
      return;
    }
    setIsMarkingDecorative(true);
    try {
      await onMarkDecorative();
    } finally {
      setIsMarkingDecorative(false);
    }
  };

  const isBusy = isApplying || isMarkingDecorative;
  const inputClassName = 'form-control form-control-sm flex-grow-1';

  return (
    <div className="aa-action aa-mutate d-flex mb-2 form-inline align-items-center flex-nowrap">
      <label className="sr-only" htmlFor={`accessibility-fix-${uuid}`}>
        {config.label}
      </label>
      <div className="input-group input-group-sm flex-grow-1">
        {config.inputType === 'textarea' ? (
          <textarea
            ref={txtRef as React.RefObject<HTMLTextAreaElement>}
            id={`accessibility-fix-${uuid}`}
            className={inputClassName}
            defaultValue={suggestion}
            placeholder={config.label}
            rows={2}
            disabled={isBusy}
          />
        ) : (
          <input
            ref={txtRef as React.RefObject<HTMLInputElement>}
            type="text"
            id={`accessibility-fix-${uuid}`}
            className={inputClassName}
            defaultValue={suggestion}
            placeholder={config.label}
            disabled={isBusy}
          />
        )}
      </div>
      {config.allowMarkDecorative && onMarkDecorative && (
        <button
          type="button"
          className="btn btn-sm btn-outline-secondary ml-2"
          onClick={handleMarkDecorative}
          disabled={isBusy}
        >
          {isMarkingDecorative ? (
            <i className="fa fa-spinner fa-spin" aria-hidden="true" />
          ) : (
            'Mark decorative'
          )}
        </button>
      )}
      <button
        type="button"
        className="btn btn-sm btn-primary ml-2 diagnostics-hub__apply-btn"
        onClick={handleApply}
        disabled={isBusy}
      >
        {isApplying ? <i className="fa fa-spinner fa-spin" aria-hidden="true" /> : 'Apply'}
      </button>
    </div>
  );
};

export default FixAccessibilityField;
