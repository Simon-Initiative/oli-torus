import React from 'react';

interface Props {
  title: string;
}
export const Tooltip = ({ title }: Props) => {
  return (
    <i
      className="ml-2 material-icons-outlined"
      data-toggle="tooltip"
      data-placement="top"
      title={title}
    >
      info
    </i>
  );
};
