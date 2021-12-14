var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import guid from 'utils/guid';
// async because this may change to calling an authoring function of the part component
export const createSimpleText = (msg, style = {}, transform = { x: 10, y: 10, z: 0, width: 330, height: 22 }) => __awaiter(void 0, void 0, void 0, function* () {
    const textComponent = {
        id: `text_${guid()}`,
        type: 'janus-text-flow',
        custom: {
            nodes: [
                {
                    tag: 'p',
                    children: [
                        {
                            tag: 'span',
                            style,
                            children: [
                                {
                                    tag: 'text',
                                    text: msg,
                                    children: [],
                                },
                            ],
                        },
                    ],
                },
            ],
            x: transform.x || 0,
            y: transform.y || 0,
            z: transform.z || 0,
            width: transform.width || 100,
            height: transform.height || 50,
            palette: {
                fillColor: 1.6777215e7,
                fillAlpha: 0.0,
                lineColor: 1.6777215e7,
                lineAlpha: 0.0,
                lineThickness: 0.1,
                lineStyle: 0.0,
            },
            customCssClass: '',
        },
    };
    return textComponent;
});
//# sourceMappingURL=simpleText.js.map