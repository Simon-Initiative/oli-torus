import React from 'react';

export interface AuthoringProps {
  content?: any;
}

export const Authoring : React.FC<AuthoringProps> = (props: AuthoringProps) => {
  return (
    <div>
      <h3>Advanced Authoring Mode</h3>
      <div>{JSON.stringify(props.content)}</div>
    </div>
  );
};
