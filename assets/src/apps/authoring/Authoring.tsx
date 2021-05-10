import React from 'react';

export interface AuthoringProps {
  isAdmin: boolean;
  projectSlug: string;
  revisionSlug: string;
  content: any;
}


export const Authoring : React.FC<AuthoringProps> = (props: AuthoringProps) => {

  const url = `/project/${props.projectSlug}/preview/${props.revisionSlug}`;
  const windowName = `preview-${props.projectSlug}`;

  const PreviewButton = () => (
    <a
      className="btn btn-sm btn-outline-primary ml-3"
      onClick={() => window.open(url, windowName)}
    >
      Preview <i className="las la-external-link-alt ml-1"></i>
    </a>
  );

  return (
    <div>
      <h3>Advanced Authoring Mode</h3>
      <PreviewButton/>
      <div>{JSON.stringify(props.content)}</div>
    </div>
  );
};
