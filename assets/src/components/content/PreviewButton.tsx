import React from 'react';

export const PreviewButton = ({ projectSlug, resourceSlug, persistence }:
  {projectSlug: string, resourceSlug: string, persistence: string}) => {
  const saving = (persistence === 'inflight' || persistence === 'pending');
  return (
    <div className="btn-group btn-group-sm ml-2" role="group" aria-label="Preview">
      <button
        role="button"
        className="btn btn-sm btn-outline-primary"
        onClick={() => window.open(`/project/${projectSlug}/resource/${resourceSlug}/preview`, 'page-preview')}
        disabled={saving}>
        Preview Page
      </button>
    </div>
  );
};
