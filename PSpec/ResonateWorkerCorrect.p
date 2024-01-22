/*****************************************************
This file defines two P specifications
1. Safety 
2. Liveness
*****************************************************/


/****************************************************
Checks the global invariant that the response to a task request is always correct and there is no error on the
server side with the implementation of the task logic.

2 invariants:
    1. A task is completed only once.
    2. Only one worker can claim a task at a time and they must claim it with the latest taskId and counter.
****************************************************/

type tRecord = (isComplete: bool, electedWorker: any, currCounter: int); 

spec GuaranteedServerCorrectness observes eDBWrite, eTaskTimeOut, eClaimTaskResp, ePromisePending, ePromiseResolved, ePromiseRejected {
    var registry: map[int, tRecord];

    start state Init {
        entry {
            goto WaitForEvents; 
        }
    }

    state WaitForEvents {
         /* Invariant: a task is completed only once. */

         on ePromisePending do (taskId: int)  {
            assert (taskId in registry == false);

            registry[taskId] = (isComplete = false, electedWorker =  null, currCounter = 0);
        }

        on ePromiseResolved do (taskId: int) {
            assert (taskId in registry); 
            assert (registry[taskId].isComplete == false);
            
            registry[taskId].isComplete = true;
        }

        on ePromiseRejected do (taskId: int) {
            assert (taskId in registry); 
            assert (registry[taskId].isComplete == false);

            registry[taskId].isComplete = true;
        }

        /* Invariant: only one worker can claim a task. */

        // Database is the source of truth for the current task id and counter.
        on eDBWrite do (req: tDBWrite) {
            assert (req.taskId in registry); 

            registry[req.taskId].electedWorker = req.worker;
            registry[req.taskId].currCounter = req.counter;            
        }

        // If the task timesout, it should reset the elected worker.  
        on eTaskTimeOut do (taskId: int) {
            registry[taskId].electedWorker = null;
        }

        on eClaimTaskResp do (resp: tClaimTaskResp) {
            assert (resp.status == CLAIM_SUCCESS || resp.status == CLAIM_ERROR); 

            if (resp.status == CLAIM_SUCCESS) {
                assert (resp.taskId in registry);
                assert (resp.counter == registry[resp.taskId].currCounter);

                if (registry[resp.taskId].electedWorker == null) {
                    registry[resp.taskId].electedWorker = resp.worker;
                } else {
                    assert (registry[resp.taskId].electedWorker == resp.worker); 
                }
            } 

            if (resp.status == CLAIM_ERROR) { 
                if (resp.taskId in registry && registry[resp.taskId].isComplete == false) {
                     assert (resp.worker != registry[resp.taskId].electedWorker || resp.counter != registry[resp.taskId].currCounter);
                }
            }
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