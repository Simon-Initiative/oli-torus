import React from 'react';

interface Props {
  hasHints: boolean;
  toggleHints: () => void;
}
export const HintsBadge: React.FC<Props> = (props) => {
  const [active, setActive] = React.useState(false);

  if (!props.hasHints) {
    return null;
  }

  const className = active ? 'material-icons' : 'material-icons-outlined';

  const action = () => {
    props.toggleHints();
    setActive((active) => !active);
  };

  return (
    <span
      tabIndex={0}
      role="button"
      onClick={action}
      onKeyPress={(e) => (e.key === 'Enter' ? action() : null)}
      aria-label="Toggle hints"
      className={'px-1 btn btn-link ' + className}
    >
      lightbulb
    </span>
  );
};
