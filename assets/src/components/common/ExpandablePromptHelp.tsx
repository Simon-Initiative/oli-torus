import React, { useRef, useState } from 'react';
import { classNames } from 'utils/classNames';

let expandablePromptHelpId = 0;

interface ExpandablePromptHelpProps {
  samples: readonly string[];
  buttonLabel?: string;
  className?: string;
  buttonClassName?: string;
  expandedClassName?: string;
  listClassName?: string;
}

export const ExpandablePromptHelp: React.FC<ExpandablePromptHelpProps> = ({
  samples,
  buttonLabel = 'View examples of helpful prompts',
  className,
  buttonClassName = 'bg-Fill-fill-info-dropdown text-Text-text-high rounded-3xl shadow px-3 py-1',
  expandedClassName = 'bg-Fill-fill-info-dropdown-expanded rounded-xl shadow px-3 py-1.5',
  listClassName,
}) => {
  const [expanded, setExpanded] = useState<boolean>(false);
  const listIdRef = useRef<string>();
  if (!listIdRef.current) {
    expandablePromptHelpId += 1;
    listIdRef.current = `expandable-prompt-help-${expandablePromptHelpId}`;
  }

  return (
    <div className={classNames('mt-2', className, expanded ? expandedClassName : '')}>
      <button
        type="button"
        className={buttonClassName}
        onClick={() => setExpanded(!expanded)}
        aria-expanded={expanded}
        aria-controls={listIdRef.current}
      >
        {buttonLabel}
        <i
          className={classNames(
            'fa-solid fa-chevron-down ml-2 text-Icon-icon-active',
            expanded ? '-rotate-180' : '',
          )}
          aria-hidden="true"
        ></i>
      </button>
      {expanded && (
        <ul
          id={listIdRef.current}
          className={classNames('list-disc list-inside py-2 ml-10 mb-0 !my-0', listClassName)}
        >
          {samples.map((sample, index) => (
            <li key={`sample-${index + 1}`} className="!my-0 !mb-0 leading-normal">
              {'"' + sample + '"'}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
};
