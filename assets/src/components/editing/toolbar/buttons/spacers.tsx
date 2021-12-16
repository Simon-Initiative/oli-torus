import React from 'react';

interface VSProps {
  key: string;
}
export const VerticalSpacer = ({ key }: VSProps) => (
  <div key={key} className="button-separator"></div>
);
