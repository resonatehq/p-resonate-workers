/*****************************************************
This file defines two P specifications

ServerIsAlwaysCorrect (safety property):
    For checking this property the spec machine observe the claim request and response, and the task completion 
    request and response: 
    CLAIMING: 
        (expired (global, local), wrong worker, already claimed, already completed)
        - On receiving the eClaimTaskReq, it adds the request in the _ so that on receiving a 
        response for this claim we can assert that the task is claimed by the correct worker.
            - monotonically increasing task ids. 
        - On receiving the eClaimTaskResp, it looks up the corresponding claim request and check that: the task is
        claimed by the correct worker and if the claim failed it is because the task is already: 
            - task does not exist (wrong taskId)
            - claimed by another worker (wrong counter) 
            - completed already (taskId is already in the completedTaskReqs set)
            - locally expired (right taskId, wrong counter) -- CLAIMING TIMER
            - globally expired (right taskId, wrong counter)
    COMPLETING: 
        - On receiving the eCompleteTaskReq, it adds the request in the _ so that on receiving a 
        response for this completion we can assert that the task is completed by the correct worker.
        - On receiving the eCompleteTaskResp, it looks up the corresponding completion request and check that: the task is
        completed by the correct worker and if the completion failed it is because the task is already: 
            - task does not exist (wrong taskId)
            - claimed by another worker. -> (wrong counter) 
            - completed already -> promise is resolved (taskId is already in the completedTaskReqs set)
            - locally expired -> promise is retried 
            - globally expired -> promise is rejected if the task is not completed by expiration or number of retries

GuaranteedTaskProgress (liveness property): - server first 
    - GuaranteedTaskProgress checks the liveness (or progress) property that all task 
    requests submitted by the client are eventually completed (a.k.a  promise will 
    eventually be resolved or rejected).
    - Checks that all task requests submitted by the client are eventually responsed. 
    requires global invariants: ( hold cold state )
    - spec has nondetemirnism - implemetntion 
        - promise completed (pending, resolved | rejected) 
        - global/local task claim timer 
        - global/local task completion timer
*****************************************************/


// safety and liveness specifications as P monitors

/****************************************************
Checks the global invariant that the response to a task request is always correct and there is no error on the
server side with the implementation of the task logic.
****************************************************/

// event: initialize the monitor with the initial account balances for all clients when the system starts

/*
spec ServerIsAlwaysCorrect observes eBroadcastTaskReq, eClaimTaskReq,  eClaimTaskResp, eCompleteTaskReq, eCompleteTaskResp, eSpec_ServerIsAlwaysCorrect_Init {
    // keep track of the pending tasks
    var pendingTaskReqs: set[int];
    // keep track of the completed tasks 
    var completedTaskReqs: set[int];
    
    start state init {} 
} 
*/

/**************************************************************************
GuaranteedWithDrawProgress checks the liveness (or progress) property that all tasks
submitted are eventually completed.

 ( hold cold state )
- global task timer - final state of the promise - either resolved or rejected - 
task -- (raise vs sending) event. 
tasks starts ePromisePending raise ePromiseResolved or ePromiseRejected
- asserts every task is eventually completed -- either 
// rejected or resolved. 


--- 


GuaranteedTaskProgress checks that global liveness propety that for every 
eTaskPending raised is eventually followed by a corresponding eTaskResolved or eTaskRejected.

This ensures that the task server moves through the expected states. We want to make 
sure that the task always transitions through the following sequence of states: 

asserts something MUST happen withouth it nothing could happen and still pass. 
Happy path: 
    Pending -> Resolved 
With error: 
    Pending -> Rejected
With timeout: 
    Pending -> Timeout -> Rejected

- testing environment. resolved as hot state to check. 
- bring in one worker. defined the worker machine -- two instances... 
- task is completed only once ? 
- timeouts ? 
- how to enforce once... ! 
***************************************************************************/
spec GuaranteedTaskProgress observes ePromisePending, ePromiseResolved, ePromiseRejected  {
    start state Init {
        on ePromisePending goto Pending;
    } 

    // eventually you want to leave the hot state and go to a cold state. 
    // has to happend... 
    hot state Pending {
        on ePromiseResolved goto Resolved; 
        on ePromiseRejected goto Rejected; 
    } 

    cold state Resolved {} 

    cold state Rejected {} 
} 