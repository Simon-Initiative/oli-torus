import { useSelector } from 'react-redux';
import { selectCurrentSequenceId, selectSequence } from '../selectors/deck';
export const getHierarchy = (sequence, parentId = null) => {
    return sequence
        .filter((item) => {
        var _a;
        if (parentId === null) {
            return !item.custom.layerRef;
        }
        return ((_a = item.custom) === null || _a === void 0 ? void 0 : _a.layerRef) === parentId;
    })
        .map((item) => {
        const withChildren = Object.assign(Object.assign({}, item), { children: [] });
        withChildren.children = getHierarchy(sequence, item.custom.sequenceId);
        return withChildren;
    });
};
export const findInHierarchy = (hierarchy, sequenceId) => {
    let found = hierarchy.find((i) => i.custom.sequenceId === sequenceId);
    if (!found) {
        // now need to search all the children recursively
        for (let i = 0; i < hierarchy.length; i++) {
            found = findInHierarchy(hierarchy[i].children, sequenceId);
            if (found) {
                break;
            }
        }
    }
    return found;
};
export const findEldestAncestorInHierarchy = (hierarchy, id) => {
    const me = findInHierarchy(hierarchy, id);
    if (!me) {
        return;
    }
    const parentId = me.custom.layerRef;
    if (!parentId) {
        return me;
    }
    const parent = findInHierarchy(hierarchy, parentId);
    if (!parent) {
        // error!
        return;
    }
    return findEldestAncestorInHierarchy(hierarchy, parent.custom.sequenceId);
};
export const flattenHierarchy = (hierarchy) => {
    const list = [];
    return hierarchy.reduce((result, item) => {
        const childlessEntry = Object.assign(Object.assign({}, item), { children: undefined });
        result.push(childlessEntry);
        if (item.children) {
            result.push(...flattenHierarchy(item.children));
        }
        return result;
    }, list);
};
export const findInSequence = (sequence, sequenceId) => {
    const found = sequence.find((entry) => entry.custom.sequenceId === sequenceId);
    if (!found) {
        return null;
    }
    return found;
};
export const findInSequenceByResourceId = (sequence, resourceId) => {
    const found = sequence.find((entry) => entry.resourceId === resourceId);
    if (!found) {
        return null;
    }
    return found;
};
export const getSequenceLineage = (sequence, childId) => {
    const lineage = [];
    const child = findInSequence(sequence, childId);
    if (child) {
        lineage.unshift(child);
        if (child.custom.layerRef) {
            lineage.unshift(...getSequenceLineage(sequence, child.custom.layerRef));
        }
    }
    return lineage;
};
export const getSequenceInstance = () => {
    const currentSequenceId = useSelector(selectCurrentSequenceId);
    const sequence = useSelector(selectSequence);
    return findInSequence(sequence, currentSequenceId);
};
export const getIsLayer = () => {
    const seq = getSequenceInstance();
    return seq === null || seq === void 0 ? void 0 : seq.custom.isLayer;
};
export const getIsBank = () => {
    const seq = getSequenceInstance();
    return seq === null || seq === void 0 ? void 0 : seq.custom.isBank;
};
//# sourceMappingURL=sequence.js.map