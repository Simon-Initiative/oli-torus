var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import ConfigurationModal from 'apps/authoring/components/EditingCanvas/ConfigurationModal';
import CustomFieldTemplate from 'apps/authoring/components/PropertyEditor/custom/CustomFieldTemplate';
import PropertyEditor from 'apps/authoring/components/PropertyEditor/PropertyEditor';
import partSchema, { partUiSchema, transformModelToSchema as transformPartModelToSchema, transformSchemaToModel as transformPartSchemaToModel, } from 'apps/authoring/components/PropertyEditor/schemas/part';
import { NotificationContext, NotificationType, subscribeToNotification, } from 'apps/delivery/components/NotificationContext';
import EventEmitter from 'events';
import { isEqual } from 'lodash';
import React, { useCallback, useContext, useEffect, useRef, useState } from 'react';
import { Col, Container, Row } from 'react-bootstrap';
import { clone } from 'utils/common';
import { convertPalette } from '../common/util';
import AddPartToolbar from './AddPartToolbar';
import LayoutEditor from './LayoutEditor';
const screenSchema = {
    type: 'object',
    properties: {
        /* Position: {
          type: 'object',
          title: 'Dimensions',
          properties: {
            x: { type: 'number' },
            y: { type: 'number' },
            z: { type: 'number' },
          },
        }, */
        Size: {
            type: 'object',
            title: 'Dimensions',
            properties: {
                width: { type: 'number' },
                height: { type: 'number' },
            },
        },
        palette: {
            type: 'object',
            properties: {
                backgroundColor: { type: 'string', title: 'Background Color' },
                borderColor: { type: 'string', title: 'Border Color' },
                borderRadius: { type: 'string', title: 'Border Radius' },
                borderStyle: { type: 'string', title: 'Border Style' },
                borderWidth: { type: 'string', title: 'Border Width' },
            },
        },
    },
};
const screenUiSchema = {
    'ui:title': 'Screen',
    Position: {
        'ui:ObjectFieldTemplate': CustomFieldTemplate,
        'ui:title': 'Position',
        x: {
            classNames: 'col-4',
        },
        y: {
            classNames: 'col-4',
        },
        z: {
            classNames: 'col-4',
        },
    },
    Size: {
        'ui:ObjectFieldTemplate': CustomFieldTemplate,
        'ui:title': 'Dimensions',
        width: {
            classNames: 'col-6',
        },
        height: {
            classNames: 'col-6',
        },
    },
    palette: {
        'ui:ObjectFieldTemplate': CustomFieldTemplate,
        'ui:title': 'Background & Border',
        backgroundColor: {
            'ui:widget': 'ColorPicker',
        },
        borderColor: {
            'ui:widget': 'ColorPicker',
        },
        borderStyle: { classNames: 'col-6' },
        borderWidth: { classNames: 'col-6' },
    },
};
const ScreenAuthor = ({ screen, onChange }) => {
    const pusherContext = useContext(NotificationContext);
    const [pusher, setPusher] = useState(pusherContext || new EventEmitter().setMaxListeners(50));
    useEffect(() => {
        if (pusherContext) {
            setPusher(pusherContext);
        }
    }, [pusherContext]);
    useEffect(() => {
        if (!pusher) {
            return;
        }
        const notificationsHandled = [
            NotificationType.CONFIGURE,
            NotificationType.CONFIGURE_CANCEL,
            NotificationType.CONFIGURE_SAVE,
        ];
        const notifications = notificationsHandled.map((notificationType) => {
            const handler = (payload) => {
                // nothing to do
                /* console.log(`ScreenAuthor catching ${notificationType.toString()}`, { payload }); */
            };
            const unsub = subscribeToNotification(pusher, notificationType, handler);
            return unsub;
        });
        return () => {
            notifications.forEach((unsub) => {
                unsub();
            });
        };
    }, [pusher]);
    const [currentScreenData, setCurrentScreenData] = useState(screen);
    useEffect(() => {
        if (onChange && !isEqual(screen, currentScreenData)) {
            onChange(currentScreenData);
        }
    }, [screen, currentScreenData, onChange]);
    const [screenWidth, setScreenWidth] = useState(screen.custom.width);
    const [screenHeight, setScreenHeight] = useState(screen.custom.height);
    const [screenBackgroundColor, setScreenBackgroundColor] = useState(screen.custom.palette.backgroundColor || 'lightblue');
    const [selectedPartId, setSelectedPartId] = useState('');
    const [partsList, setPartsList] = useState([]);
    const [showConfigModal, setShowConfigModal] = useState(false);
    useEffect(() => {
        // console.log('SA:Screen Changed', { screen });
        setCurrentScreenData(screen);
        setPartsList([...screen.partsLayout]);
        setScreenHeight(screen.custom.height);
        setScreenWidth(screen.custom.width);
        const palette = convertPalette(screen.custom.palette);
        setScreenBackgroundColor(palette.backgroundColor);
    }, [screen]);
    const [currentPropertySchema, setCurrentPropertySchema] = useState(screenSchema);
    const [currentPropertyUiSchema, setCurrentPropertyUiSchema] = useState(screenUiSchema);
    const [currentPropertyData, setCurrentPropertyData] = useState({});
    useEffect(() => {
        if (!selectedPartId) {
            // current should be screen, formatted to match the schema
            // console.log('screen selected', currentScreenData);
            const data = {
                /* Position: {
                  x: currentScreenData.custom.x || 0,
                  y: currentScreenData.custom.y || 0,
                  z: currentScreenData.custom.z || 0,
                }, */
                Size: {
                    width: currentScreenData.custom.width,
                    height: currentScreenData.custom.height,
                },
                palette: convertPalette(currentScreenData.custom.palette),
            };
            setCurrentPropertyData(data);
            setCurrentPropertySchema(screenSchema);
            setCurrentPropertyUiSchema(screenUiSchema);
        }
        else {
            const part = partsList.find((part) => part.id === selectedPartId);
            if (part) {
                const PartClass = customElements.get(part.type);
                if (PartClass) {
                    const partInstance = new PartClass();
                    if (partInstance.getSchema) {
                        const customPartSchema = partInstance.getSchema();
                        const mergedPartSchema = Object.assign(Object.assign({}, partSchema), { properties: Object.assign(Object.assign({}, partSchema.properties), { custom: { type: 'object', properties: Object.assign({}, customPartSchema) } }) });
                        setCurrentPropertySchema(mergedPartSchema);
                    }
                    else {
                        setCurrentPropertySchema(partSchema);
                    }
                    if (partInstance.getUiSchema) {
                        const customPartUiSchema = partInstance.getUiSchema();
                        const mergedUiSchema = Object.assign(Object.assign({ 'ui:title': 'Selected Part' }, partUiSchema), { custom: Object.assign({ 'ui:ObjectFieldTemplate': CustomFieldTemplate, 'ui:title': 'Custom' }, customPartUiSchema) });
                        setCurrentPropertyUiSchema(mergedUiSchema);
                    }
                    else {
                        setCurrentPropertySchema(partSchema);
                    }
                    let data = clone(part);
                    if (partInstance.transformModelToSchema) {
                        // because the part schema below only knows about the "custom" block
                        data.custom = Object.assign(Object.assign({}, data.custom), partInstance.transformModelToSchema(data.custom));
                    }
                    data = transformPartModelToSchema(data);
                    setCurrentPropertyData(data);
                }
            }
        }
    }, [selectedPartId, currentScreenData, partsList]);
    const handleEditorChange = useCallback((parts) => {
        // console.log('SA:LE CHANGE', { parts });
        const newScreenData = clone(currentScreenData);
        newScreenData.partsLayout = parts;
        setCurrentScreenData(newScreenData);
        setPartsList(parts);
    }, [currentScreenData]);
    const handleEditorSelect = (partId) => {
        // console.log('SA:LE SELECT', { partId });
        setSelectedPartId(partId);
    };
    const handlePropertyEditorChange = useCallback((properties) => {
        // console.log('SA:PE:Change', properties);
        const newScreenData = clone(currentScreenData);
        if (!selectedPartId) {
            // modifying screen properties
            const newWidth = properties.Size.width;
            const newHeight = properties.Size.height;
            setScreenWidth(newWidth);
            setScreenHeight(newHeight);
            newScreenData.custom.width = newWidth;
            newScreenData.custom.height = newHeight;
            newScreenData.custom.palette = properties.palette;
            setScreenBackgroundColor(properties.palette.backgroundColor);
        }
        else {
            // modifying part properties
            const partChanges = transformPartSchemaToModel(properties);
            // console.log('FIRST', { partChanges: clone(partChanges), properties });
            // select by selected part id because id might have been modified
            const part = partsList.find((part) => part.id === selectedPartId);
            if (part) {
                const PartClass = customElements.get(part.type);
                if (PartClass) {
                    const instance = new PartClass();
                    if (instance.transformSchemaToModel) {
                        partChanges.custom = Object.assign(Object.assign({}, partChanges.custom), instance.transformSchemaToModel(partChanges.custom));
                        // console.log('SECOND', { partChanges: clone(partChanges) });
                    }
                }
                // the id may have changed, and the new one should be fully updated, replace it in array
                const clonePartsList = clone(partsList);
                const index = clonePartsList.findIndex((p) => p.id === part.id);
                clonePartsList.splice(index, 1, partChanges);
                // console.log('CHANGING!', { partChanges, clonePartsList });
                setPartsList(clonePartsList);
                setSelectedPartId(partChanges.id);
                newScreenData.partsLayout = clonePartsList;
            }
        }
        setCurrentScreenData(newScreenData);
    }, [currentScreenData, partsList, selectedPartId]);
    // TODO: this is for feedback and popup, configure for other things somewhere
    const allowedParts = [
        'janus_text_flow',
        'janus_image',
        'janus_audio',
        'janus_video',
        'janus_capi_iframe',
    ];
    const handleAddPart = useCallback((part) => {
        const parts = [...partsList, part];
        /* console.log('SA:AddPart', { part, partsList, parts }); */
        setPartsList(parts);
        setSelectedPartId(part.id);
    }, [partsList]);
    const canvasRef = useRef(null);
    const [configEditorId] = useState(`config-editor-${screen.id || `screen${Date.now()}`}`);
    const handlePartConfigure = (part) => __awaiter(void 0, void 0, void 0, function* () {
        /* console.log('[handlePartConfigure]', { part }); */
        setShowConfigModal(true);
    });
    const handlePartCancelConfigure = (partId) => __awaiter(void 0, void 0, void 0, function* () {
        /* console.log('[handlePartCancelConfigure]', { partId }); */
        setShowConfigModal(false);
    });
    return (<NotificationContext.Provider value={pusher}>
      <ConfigurationModal bodyId={configEditorId} isOpen={showConfigModal} headerText={`Configure: ${selectedPartId}`} onClose={() => {
            setShowConfigModal(false);
            pusher.emit(NotificationType.CONFIGURE_CANCEL, { id: selectedPartId });
        }} onSave={() => {
            setShowConfigModal(false);
            pusher.emit(NotificationType.CONFIGURE_SAVE, { id: selectedPartId });
        }}/>
      <Container>
        <Row style={{ padding: 2, borderBottom: '2px solid #eee' }}>
          <Col>
            <AddPartToolbar partTypes={allowedParts} priorityTypes={allowedParts} onAdd={handleAddPart}/>
          </Col>
        </Row>
        <Row style={{ minHeight: (currentScreenData.custom.height || 0) + 100 }}>
          <Col ref={canvasRef} className="canvas-dots" style={{ paddingTop: 50, paddingBottom: 50 }}>
            <LayoutEditor id="screen-designer-1" hostRef={canvasRef.current} width={screenWidth} height={screenHeight} backgroundColor={screenBackgroundColor} parts={partsList} selected={selectedPartId} onChange={handleEditorChange} onSelect={handleEditorSelect} onConfigurePart={handlePartConfigure} onCancelConfigurePart={handlePartCancelConfigure} configurePortalId={configEditorId}/>
          </Col>
          <Col sm={3}>
            <PropertyEditor key={currentPropertyData.id || 'screen'} schema={currentPropertySchema} uiSchema={currentPropertyUiSchema} value={currentPropertyData} onChangeHandler={handlePropertyEditorChange} triggerOnChange={true}/>
          </Col>
        </Row>
      </Container>
    </NotificationContext.Provider>);
};
export default ScreenAuthor;
//# sourceMappingURL=ScreenAuthor.jsx.map