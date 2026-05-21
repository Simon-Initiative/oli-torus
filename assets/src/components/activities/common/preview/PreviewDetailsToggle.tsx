import React from 'react';
import { ChevronDown } from 'components/misc/icons/Icons';

interface Props {
  expanded: boolean;
  controlsId: string;
  onToggle: () => void;
}

export const PreviewDetailsToggle: React.FC<Props> = ({ expanded, controlsId, onToggle }) => (
  <button
    type="button"
    aria-expanded={expanded}
    aria-controls={controlsId}
    className="inline-flex items-center gap-2 self-start border-0 bg-transparent p-0 text-sm font-semibold text-primary hover:text-primary"
    onClick={onToggle}
  >
    <span>{expanded ? 'Hide Details' : 'View Details'}</span>
    <ChevronDown
      className={`transition-transform duration-200 ${expanded ? 'rotate-180' : 'rotate-0'}`}
      width={18}
      height={18}
    />
  </button>
);
