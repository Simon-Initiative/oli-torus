import Konva from 'konva';
import { isEqual } from 'lodash';
import React, { useCallback, useEffect, useLayoutEffect, useState } from 'react';

const textFlowHack = (node: any): any => {
  let nodeText = '';
  if (node?.tag === 'text') {
    nodeText = node.text;
  } else if (node?.children?.length > 0) {
    nodeText = textFlowHack(node?.children[0]);
  } else {
    nodeText = '';
  }
  return nodeText;
};

const KonvaStage: React.FC<any> = (props: any) => {
  const {
    size = { width: 800, height: 600 },
    background = { color: '#fff' },
    layers: layersProp = [],
    selected = [],
    onSelectionChange,
  } = props;

  const [stage, setStage] = useState<any>(null);

  const [screenSize, setScreenSize] = useState<{ width: number; height: number }>(size);
  const [screenBg, setScreenBg] = useState<{ color: string }>(background);
  const [layers, setLayers] = useState<any[]>(layersProp);

  useEffect(() => {
    if (!isEqual(size, screenSize)) {
      setScreenSize(size);
    }
    if (!isEqual(background, screenBg)) {
      setScreenBg(background);
    }
    if (!isEqual(layers, layersProp)) {
      setLayers(layersProp);
    }
  }, [size, background, layersProp]);

  const containerRef = useCallback((el) => {
    if (el !== null) {
      const _stage = new Konva.Stage({
        width: el.clientWidth,
        height: el.clientHeight,
        container: el,
      });
      setStage(_stage);
    }
  }, []);

  useLayoutEffect(() => {
    if (!stage) {
      return;
    }

    // TODO: optimize rendering so it isn't a full redraw

    const bgLayer = new Konva.Layer({
      x: 300,
      y: 100,
      width: screenSize.width,
      height: screenSize.height,
    });
    bgLayer.add(
      new Konva.Rect({
        x: 0,
        y: 0,
        width: screenSize.width,
        height: screenSize.height,
        fill: screenBg.color,
      }),
    );

    stage.add(bgLayer);

    layers.forEach((layer: any) => {
      const layerRef = new Konva.Layer({
        x: 300,
        y: 100,
        width: screenSize.width,
        height: screenSize.height,
      });

      layer.parts.forEach((part: { id: string; type: string; custom: any }) => {
        const partGroup = new Konva.Group({
          id: part.id,
          name: part.type,
          x: part.custom.x,
          y: part.custom.y,
          width: part.custom.width,
          height: part.custom.height,
        });

        switch (part.type) {
          case 'janus-image':
            {
              Konva.Image.fromURL(part.custom.src, (imgNode: any) => {
                imgNode.setAttrs({
                  width: part.custom.width,
                  height: part.custom.height,
                });
                partGroup.add(imgNode);
              });
            }
            break;
          case 'janus-text-flow':
            {
              let y = 0;
              part.custom.nodes.forEach((node: any) => {
                const text = textFlowHack(node);
                const textNode = new Konva.Text({
                  y,
                  width: part.custom.width,
                  /* height: part.custom.height, */
                  text,
                  fontSize: 16,
                });
                y = textNode.height() + y + 1;
                partGroup.add(textNode);
              });
            }
            break;
          default:
            {
              console.warn('no renderer for part type', { part });
              const pWidth = part.custom.width;
              const pHeight = part.custom.height > 1 ? part.custom.height : 100;
              const placeholderRect = new Konva.Rect({
                width: pWidth,
                height: pHeight,
                fill: 'magenta',
                strokeWidth: 1,
                stroke: '#000'
              });
              const placeholderText = new Konva.Text({
                x: 2,
                y: 2,
                text: `${part.id}`,
                fontSize: 16,
              });
              partGroup.add(placeholderRect);
              partGroup.add(placeholderText);
            }
            break;
        }

        layerRef.add(partGroup);
      });

      // selection / transform widget per layer
      const tr = new Konva.Transformer({
        name: '_transformer',
        rotateEnabled: false,
      });
      layerRef.add(tr);

      stage.on('click tap', (evt: any) => {
        let selectedNode = evt.target;
        const selectedParent = selectedNode.getParent();
        if (selectedNode === stage) {
          tr.nodes([]);
          onSelectionChange([]);
          return;
        }

        let selectedId = selectedNode.id();
        if ((!selectedId || selectedNode.getType() !== 'Group') && selectedParent) {
          if (selectedParent.getType() === 'Group') {
            selectedId = selectedParent.id();
            selectedNode = selectedParent;
          }
        }

        if (selectedId) {
          if (onSelectionChange) {
            onSelectionChange([selectedId]);
          }
        }

        console.log('SELECTED', { selectedNode: evt.target, selectedParent, stage, selectedId });

        // for now just select it
        tr.nodes([selectedNode]);
      });

      stage.add(layerRef);
    });

    return () => {
      stage.clear();
      stage.destroyChildren();
    };
  }, [stage, screenSize, screenBg, layers]);

  // this one *needs* to be after the stage is setup above
  useLayoutEffect(() => {
    if (stage) {
      // check each layer for selection
      console.log('SELECTION CHANGE', { selected, stage });

      const [selectedId] = selected;
      if (!selectedId) {
        return;
      }
      const selection = stage.find(`#${selectedId}`);
      const [first] = selection;
      if (first) {
        const layer = first.getLayer();
        if (layer) {
          const [tr] = layer.find('._transformer');
          if (tr) {
            tr.nodes([first]);
          }
        }
      }
    }
  }, [stage, selected]);

  return <div style={{ width: '100%', height: '100%' }} ref={containerRef}></div>;
};

export default KonvaStage;
