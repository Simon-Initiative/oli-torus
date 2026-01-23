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
  buttonClassName = 'bg-Fill-Accent-fill-accent-blue-soft rounded-3xl shadow px-3 py-1',
  expandedClassName = 'bg-Fill-Accent-fill-accent-blue-soft/30 rounded-xl shadow px-3 py-1.5',
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
        {buttonLabel}&nbsp;&nbsp; {expanded ? '^' : '\u22C1'}
      </button>
      {expanded && (
        <ul className={classNames('list-disc list-inside py-2 ml-10', listClassName)}>
          {samples.map((sample) => (
            <li key={sample}>"{sample}"</li>
          ))}
        </ul>
      )}
    </div>
  );
};
