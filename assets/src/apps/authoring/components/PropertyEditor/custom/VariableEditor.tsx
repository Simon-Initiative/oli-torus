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

interface CustomFieldProps {
  onAddClick: any;
  items: any[];
  canAdd: any;
}

export const FieldTemplate: React.FC<any> = (props) => {
  return (
    <>
      {!props.hidden ? (
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
      )}
    </>
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
        <div className="flex-grow-1">{props.children}</div>
        <div className="align-self-end mb-3">
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

  const handleClose = () => setShow(false);
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
          {props.items.map((element: any) => VariableArrayItem(element))}
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
