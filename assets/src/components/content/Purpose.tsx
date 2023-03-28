import React, { PropsWithChildren, useState } from 'react';
import { Dropdown, OverlayTrigger, Popover } from 'react-bootstrap';
import guid from 'utils/guid';
import { PurposeTypes } from 'data/content/resource';
import { Tooltip } from 'components/common/Tooltip';

export type PurposeProps = {
  editMode: boolean; // Whether or not we can edit
  canEditPurpose: boolean;
  purpose: string;
  onEdit: (purpose: string) => void;
};

export const Purpose = (props: PurposeProps) => {
  const { editMode, canEditPurpose, purpose, onEdit } = props;

  const purposeLabel = PurposeTypes.find((p) => p.value === purpose)?.label;
  const disabled = !editMode || !canEditPurpose;

  return (
    <MaybePurposeTooltip canEditPurpose={canEditPurpose}>
      <div className="form-inline">
        <Dropdown>
          <Dropdown.Toggle className="my-2" variant="outline-primary" size="sm" disabled={disabled}>
            {purposeLabel}
            <i className="fa-solid fa-caret-down ml-2"></i>
          </Dropdown.Toggle>

          <Dropdown.Menu>
            {PurposeTypes.map((p) => (
              <Dropdown.Item key={p.value} onClick={() => onEdit(p.value)}>
                {p.label}
              </Dropdown.Item>
            ))}
          </Dropdown.Menu>
        </Dropdown>
      </div>
    </MaybePurposeTooltip>
  );
};

interface MaybePurposeTooltipProps {
  canEditPurpose: boolean;
}

const MaybePurposeTooltip = ({
  canEditPurpose,
  children,
}: PropsWithChildren<MaybePurposeTooltipProps>) => {
  if (canEditPurpose) {
    return <>{children}</>;
  }

  return (
    <Tooltip title="A purpose is already set on either a parent or child group.">
      <div>{children}</div>
    </Tooltip>
  );
};
