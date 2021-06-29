/* eslint-disable react/prop-types */
import React, { Fragment } from 'react';
import Form from "@rjsf/bootstrap-4";
import { JSONSchema7 } from "json-schema";
//import fields from 'react-jsonschema-form-extras';

interface PropertyEditorProps {
  schema: JSONSchema7;
  onChangeHandler: any;
  value: any;
}
const PropertyEditor: React.FC<PropertyEditorProps> = ({ schema, value, onChangeHandler }) => {
  return (
    <Form schema={schema} formData={value}
     onChange={(e) => { onChangeHandler(e.formData)}} >
      <Fragment />{/*  this one is to remove the submit button */}
    </Form>
  );
};
export default PropertyEditor;
