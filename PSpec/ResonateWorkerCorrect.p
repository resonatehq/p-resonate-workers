/*****************************************************
This file defines two P specifications
1. Safety 
2. Liveness
*****************************************************/


/****************************************************
Checks the global invariant that the response to a task request is always correct and there is no error on the
server side with the implementation of the task logic.
****************************************************/
spec GuaranteedCorrectness observes eClaimTaskReq, eClaimTaskResp {       
    start state Init {
        on eClaimTaskReq do (req: tClaimTaskReq) {}

        on eClaimTaskResp do (resp: tClaimTaskRespStatus) {
            assert (resp == CLAIM_SUCCESS || resp == CLAIM_ERROR);
        }
    }
}

/**************************************************************************
GuaranteedTaskProgress checks the global liveness (or progress) property that for every 
eTaskPending raised a corresponding eTaskResolved or eTaskRejected eventually follows
***************************************************************************/
spec GuaranteedTaskProgress observes ePromisePending, ePromiseResolved, ePromiseRejected  {
    start state Init {
        on ePromisePending goto Pending;
    } 

    // Eventually you want to leave the hot state and go to a cold state. 
    hot state Pending {
        on ePromiseResolved goto Resolved; 
        on ePromiseRejected goto Rejected; 
    } 

    cold state Resolved {} 

    cold state Rejected {} 
} 