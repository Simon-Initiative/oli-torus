import React from 'react';

export const PreviewButton = ({projectSlug, resourceSlug, persistence}:
  {projectSlug: string, resourceSlug: string, persistence: string}) => {
  const saving = (persistence === 'inflight' || persistence === 'pending');
  return (
    <div className="btn-group btn-group-sm" role="group" aria-label="Preview">
      <a href={`/project/${projectSlug}/resource/${resourceSlug}/preview`}
        role="button"
        className={`btn btn-sm btn-outline-primary m-2 ${saving ? 'disabled' : ''}`}
        target="_blank">
        Preview Page
      </a>
    </div>
  );
};
