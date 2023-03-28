import React, { useState } from 'react';
import {
  Modal,
  Button,
  Form,
  ListGroup,
  ListGroupItem,
  OverlayTrigger,
  Tooltip,
} from 'react-bootstrap';
import { ObjectFieldTemplateProps } from '@rjsf/core';
import { validateVariables } from 'apps/authoring/store/groups/layouts/deck/actions/validate';
import { useDispatch, useSelector } from 'react-redux';
import { PageError } from '../../Modal/DiagnosticsWindow';
interface CustomFieldProps {
  onAddClick: any;
  items: any[];
  canAdd: any;
}

export const FieldTemplate: React.FC<any> = (props) => {
  return !props.hidden ? (
    <Form.Group className="mb-0">
      <div>{props.children}</div>
      <div>
        {props.rawHelp && props.rawErrors?.length < 1 && (
          <Form.Text
            className={props.rawErrors?.length > 0 ? 'text-danger' : 'text-muted'}
            id={props.id}
          >
            {props.rawHelp}
          </Form.Text>
        )}
      </div>
    </Form.Group>
  ) : (
    <></>
  );
};

export const ObjectFieldTemplate = ({
  DescriptionField,
  description,
  TitleField,
  title,
  properties,
  required,
  uiSchema,
  idSchema,
}: ObjectFieldTemplateProps) => {
  return (
    <>
      {(uiSchema['ui:title'] || title) && (
        <TitleField
          id={`${idSchema.$id}-title`}
          title={uiSchema['ui:title'] || title}
          required={required}
        />
      )}
      {description && (
        <DescriptionField id={`${idSchema.$id}-description`} description={description} />
      )}
      <div className="d-flex">
        {properties.map((element: any, index: number) => (
          <div key={index} className={`mr-2 ${index === 0 ? '' : 'flex-grow-1'}`}>
            {element.content}
          </div>
        ))}
      </div>
    </>
  );
};

const VariableArrayItem: React.FC<any> = (props) => {
  return (
    <div className={`mt-2 border-bottom`}>
      <div className="mb-2 d-flex flex-row align-items-start">
        <div className="self-end mb-3">
          <Button
            disabled={!props.hasMoveUp || props.readonly || props.disabled}
            variant="link"
            size="sm"
            onClick={props.onReorderClick(props.index, props.index - 1)}
          >
            <i className="fa fa-arrow-circle-up fa-2x" />
            <span className="sr-only">Move Up</span>
          </Button>
          <Button
            disabled={!props.hasMoveDown || props.readonly || props.disabled}
            variant="link"
            size="sm"
            onClick={props.onReorderClick(props.index, props.index + 1)}
          >
            <i className="fa fa-arrow-circle-down fa-2x" />
            <span className="sr-only">Move Down</span>
          </Button>
        </div>
        <div className="flex-grow-1">{props.children}</div>
        <div className="self-end mb-3">
          <Button
            variant="danger"
            disabled={props.disabled || props.readonly}
            onClick={props.onDropIndexClick(props.index)}
          >
            <span className="sr-only">Delete</span>
            <i className="fa fa-trash"></i>
          </Button>
        </div>
      </div>
    </div>
  );
};

const VariableEditor: React.FC<CustomFieldProps> = (props) => {
  const [show, setShow] = useState(false);
  const [results, setResults] = useState<any>(null);
  const dispatch = useDispatch();
  const handleClose = async () => {
    const result = await dispatch(validateVariables({}));
    if ((result as any).meta.requestStatus === 'fulfilled') {
      if ((result as any).payload.errors.length > 0) {
        const errors = (result as any).payload.errors;
        const errorList = <PageError key={errors[0].owner.title} error={errors} />;
        setResults(errorList);
      } else {
        setResults(null);
        setShow(false);
      }
    }
  };
  const handleShow = () => setShow(true);

  return (
    <div className="p-3">
      <button
        className="btn btn-primary btn-block"
        type="button"
        disabled={!props.canAdd}
        onClick={handleShow}
      >
        Edit Lesson Variables
      </button>
      <ListGroup className="mt-2" variant="flush">
        {props.items.map((element: any, index: number) => (
          <OverlayTrigger
            key={index}
            placement="left"
            overlay={
              <Tooltip id={`tooltip-${index}`}>
                Expression: <strong>{element?.children?.props?.formData?.expression}</strong>
              </Tooltip>
            }
          >
            <ListGroupItem key={index}>{element?.children?.props?.formData?.name}</ListGroupItem>
          </OverlayTrigger>
        ))}
      </ListGroup>
      <Modal show={show} onHide={handleClose} size="lg">
        <Modal.Header closeButton>
          <Modal.Title>Variable editor</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <div>{results}</div>
          {props.items.map((element: any, idx: number) => (
            <VariableArrayItem key={idx} {...element} />
          ))}
          {props.canAdd && (
            <button className="btn btn-primary mt-2" type="button" onClick={props.onAddClick}>
              <i className="fa fa-plus"></i>
              Add Variable
            </button>
          )}
        </Modal.Body>
        <Modal.Footer>
          <Button variant="secondary" onClick={handleClose}>
            Finished
          </Button>
        </Modal.Footer>
      </Modal>
    </div>
  );
};

export default VariableEditor;
