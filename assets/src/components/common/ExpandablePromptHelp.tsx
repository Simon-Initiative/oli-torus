import React, { useState } from 'react';
import { classNames } from 'utils/classNames';

interface ExpandablePromptHelpProps {
  samples: string[];
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

  return (
    <div className={classNames('mt-2', className, expanded ? expandedClassName : '')}>
      <button
        type="button"
        className={buttonClassName}
        onClick={() => setExpanded(!expanded)}
      >
        {buttonLabel}
        <i
          className={classNames(
            'fa-solid fa-chevron-down ml-2 text-Icon-icon-active',
            expanded ? '-rotate-180' : ''
          )}
        ></i>
      </button>
      {expanded && (
        <ul
          className={classNames(
            'list-disc list-inside py-2 ml-10 mb-0 !my-0',
            listClassName
          )}
        >
          {samples.map((sample) => (
            <li key={sample} className="!my-0 !mb-0 leading-normal">
              "{sample}"
            </li>
          ))}
        </ul>
      )}
    </div>
  );
};
