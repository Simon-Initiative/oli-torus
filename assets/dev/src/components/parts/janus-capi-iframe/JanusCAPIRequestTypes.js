export var JanusCAPIRequestTypes;
(function (JanusCAPIRequestTypes) {
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["HANDSHAKE_REQUEST"] = 1] = "HANDSHAKE_REQUEST";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["HANDSHAKE_RESPONSE"] = 2] = "HANDSHAKE_RESPONSE";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["ON_READY"] = 3] = "ON_READY";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["VALUE_CHANGE"] = 4] = "VALUE_CHANGE";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["CONFIG_CHANGE"] = 5] = "CONFIG_CHANGE";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["VALUE_CHANGE_REQUEST"] = 6] = "VALUE_CHANGE_REQUEST";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["CHECK_REQUEST"] = 7] = "CHECK_REQUEST";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["CHECK_COMPLETE_RESPONSE"] = 8] = "CHECK_COMPLETE_RESPONSE";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["GET_DATA_REQUEST"] = 9] = "GET_DATA_REQUEST";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["GET_DATA_RESPONSE"] = 10] = "GET_DATA_RESPONSE";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["SET_DATA_REQUEST"] = 11] = "SET_DATA_REQUEST";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["SET_DATA_RESPONSE"] = 12] = "SET_DATA_RESPONSE";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["INITIAL_SETUP_COMPLETE"] = 14] = "INITIAL_SETUP_COMPLETE";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["CHECK_START_RESPONSE"] = 15] = "CHECK_START_RESPONSE";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["API_CALL_REQUEST"] = 16] = "API_CALL_REQUEST";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["API_CALL_RESPONSE"] = 17] = "API_CALL_RESPONSE";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["RESIZE_PARENT_CONTAINER_REQUEST"] = 18] = "RESIZE_PARENT_CONTAINER_REQUEST";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["RESIZE_PARENT_CONTAINER_RESPONSE"] = 19] = "RESIZE_PARENT_CONTAINER_RESPONSE";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["ALLOW_INTERNAL_ACCESS"] = 20] = "ALLOW_INTERNAL_ACCESS";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["REGISTER_LOCAL_DATA_CHANGE_LISTENER"] = 21] = "REGISTER_LOCAL_DATA_CHANGE_LISTENER";
    JanusCAPIRequestTypes[JanusCAPIRequestTypes["REGISTERED_LOCAL_DATA_CHANGED"] = 22] = "REGISTERED_LOCAL_DATA_CHANGED";
})(JanusCAPIRequestTypes || (JanusCAPIRequestTypes = {}));
export const getJanusCAPIRequestTypeString = (type) => {
    switch (type) {
        case JanusCAPIRequestTypes.HANDSHAKE_REQUEST:
            return 'HANDSHAKE_REQUEST';
        case JanusCAPIRequestTypes.HANDSHAKE_RESPONSE:
            return 'HANDSHAKE_RESPONSE';
        case JanusCAPIRequestTypes.ON_READY:
            return 'ON_READY';
        case JanusCAPIRequestTypes.VALUE_CHANGE:
            return 'VALUE_CHANGE';
        case JanusCAPIRequestTypes.CONFIG_CHANGE:
            return 'CONFIG_CHANGE';
        case JanusCAPIRequestTypes.VALUE_CHANGE_REQUEST:
            return 'VALUE_CHANGE_REQUEST';
        case JanusCAPIRequestTypes.CHECK_REQUEST:
            return 'CHECK_REQUEST';
        case JanusCAPIRequestTypes.CHECK_COMPLETE_RESPONSE:
            return 'CHECK_COMPLETE_RESPONSE';
        case JanusCAPIRequestTypes.GET_DATA_REQUEST:
            return 'GET_DATA_REQUEST';
        case JanusCAPIRequestTypes.GET_DATA_RESPONSE:
            return 'GET_DATA_RESPONSE';
        case JanusCAPIRequestTypes.SET_DATA_REQUEST:
            return 'SET_DATA_REQUEST';
        case JanusCAPIRequestTypes.SET_DATA_RESPONSE:
            return 'SET_DATA_RESPONSE';
        case JanusCAPIRequestTypes.INITIAL_SETUP_COMPLETE:
            return 'INITIAL_SETUP_COMPLETE';
        case JanusCAPIRequestTypes.CHECK_START_RESPONSE:
            return 'CHECK_START_RESPONSE';
        case JanusCAPIRequestTypes.API_CALL_REQUEST:
            return 'API_CALL_REQUEST';
        case JanusCAPIRequestTypes.API_CALL_RESPONSE:
            return 'API_CALL_RESPONSE';
        case JanusCAPIRequestTypes.RESIZE_PARENT_CONTAINER_REQUEST:
            return 'RESIZE_PARENT_CONTAINER_REQUEST';
        case JanusCAPIRequestTypes.RESIZE_PARENT_CONTAINER_RESPONSE:
            return 'RESIZE_PARENT_CONTAINER_RESPONSE';
        case JanusCAPIRequestTypes.ALLOW_INTERNAL_ACCESS:
            return 'ALLOW_INTERNAL_ACCESS';
        case JanusCAPIRequestTypes.REGISTER_LOCAL_DATA_CHANGE_LISTENER:
            return 'REGISTER_LOCAL_DATA_CHANGE_LISTENER';
        case JanusCAPIRequestTypes.REGISTERED_LOCAL_DATA_CHANGED:
            return 'REGISTERED_LOCAL_DATA_CHANGED';
    }
};
//# sourceMappingURL=JanusCAPIRequestTypes.js.map