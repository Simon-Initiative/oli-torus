import React, { PropsWithChildren, useState } from 'react';
import { OverlayTrigger, Popover } from 'react-bootstrap';
import guid from 'utils/guid';
import { PurposeTypes } from 'data/content/resource';
import { classNames } from 'utils/classNames';

export type PurposeProps = {
  editMode: boolean; // Whether or not we can edit
  canEditPurpose: boolean;
  purpose: string;
  onEdit: (purpose: string) => void;
};

export const Purpose = (props: PurposeProps) => {
  const { editMode, canEditPurpose, purpose, onEdit } = props;

  const options = PurposeTypes.map((p) => (
    <button className="dropdown-item" key={p.value} onClick={() => onEdit(p.value)}>
      {p.label}
    </button>
  ));

  const purposeLabel = PurposeTypes.find((p) => p.value === purpose)?.label;
  const disabled = !editMode || !canEditPurpose;

  return (
    <MaybePurposeTooltip canEditPurpose={canEditPurpose}>
      <div className="form-inline">
        <div className="dropdown">
          <button
            type="button"
            disabled={disabled}
            style={disabled ? { pointerEvents: 'none' } : {}}
            className={classNames('btn btn-sm dropdown-toggle btn-purpose', disabled && 'disabled')}
            data-toggle="dropdown"
            aria-haspopup="true"
            aria-expanded="false"
          >
            {purposeLabel}
            <i className="fa-solid fa-caret-down w-2 ml-auto"></i>
          </button>
          <div className="dropdown-menu dropdown-menu-right" aria-labelledby="purposeTypeButton">
            {options}
          </div>
        </div>
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
  const [id] = useState(guid());
  const [isPopoverOpen, setIsPopoverOpen] = useState(false);

  if (canEditPurpose) {
    return <>{children}</>;
  }

  return (
    <OverlayTrigger
      trigger="click"
      overlay={
        <Popover id={id}>
          <Popover.Content>
            A purpose is already set on either a parent or child group.
          </Popover.Content>
        </Popover>
      }
      rootClose={true}
      show={isPopoverOpen}
      onToggle={setIsPopoverOpen}
    >
      <div>{children}</div>
    </OverlayTrigger>
  );
};
