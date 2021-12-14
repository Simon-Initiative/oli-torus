var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { makeRequest } from '../common';
export const getBulkAttemptState = (sectionSlug, attemptGuids) => __awaiter(void 0, void 0, void 0, function* () {
    const params = {
        method: 'POST',
        url: `/state/course/${sectionSlug}/activity_attempt`,
        body: JSON.stringify({ attemptGuids }),
    };
    const response = yield makeRequest(params);
    if (response.result !== 'success') {
        throw new Error(`Server ${response.status} error: ${response.message}`);
    }
    return response.activityAttempts;
});
export const getPageAttemptState = (sectionSlug, resourceAttemptGuid) => __awaiter(void 0, void 0, void 0, function* () {
    const url = `/state/course/${sectionSlug}/resource_attempt/${resourceAttemptGuid}`;
    const result = yield makeRequest({
        url,
        method: 'GET',
    });
    return { result };
});
export const writePageAttemptState = (sectionSlug, resourceAttemptGuid, state) => __awaiter(void 0, void 0, void 0, function* () {
    const method = 'PUT';
    const url = `/state/course/${sectionSlug}/resource_attempt/${resourceAttemptGuid}`;
    const result = yield makeRequest({
        url,
        method,
        body: JSON.stringify(state),
    });
    return { result };
});
export const writeActivityAttemptState = (sectionSlug, attemptGuid, partResponses, finalize = false) => __awaiter(void 0, void 0, void 0, function* () {
    const method = finalize ? 'PUT' : 'PATCH';
    const url = `/state/course/${sectionSlug}/activity_attempt/${attemptGuid}`;
    const result = yield makeRequest({
        url,
        method,
        body: JSON.stringify({ partInputs: partResponses }),
    });
    return { result };
});
export const writePartAttemptState = (sectionSlug, attemptGuid, partAttemptGuid, input, finalize = false) => __awaiter(void 0, void 0, void 0, function* () {
    const method = finalize ? 'PUT' : 'PATCH';
    const url = `/state/course/${sectionSlug}/activity_attempt/${attemptGuid}/part_attempt/${partAttemptGuid}`;
    const result = yield makeRequest({
        url,
        method,
        body: JSON.stringify({ response: input }),
    });
    return { result };
});
export const createNewActivityAttempt = (sectionSlug, attemptGuid, seedResponsesWithPrevious = false) => __awaiter(void 0, void 0, void 0, function* () {
    // type ActivityState ? this is in components currently
    const method = 'POST';
    const url = `/state/course/${sectionSlug}/activity_attempt/${attemptGuid}`;
    const result = yield makeRequest({
        url,
        method,
        body: JSON.stringify({ seedResponsesWithPrevious }),
    });
    return result;
});
export const evalActivityAttempt = (sectionSlug, attemptGuid, partInputs) => __awaiter(void 0, void 0, void 0, function* () {
    const method = 'PUT';
    const url = `/state/course/${sectionSlug}/activity_attempt/${attemptGuid}`;
    const body = JSON.stringify({ partInputs });
    const result = yield makeRequest({
        url,
        method,
        body,
    });
    return { result };
});
//# sourceMappingURL=intrinsic.js.map