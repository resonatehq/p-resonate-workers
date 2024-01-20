/*****************************************************
This file defines two P specifications
1. Safety 
2. Liveness
*****************************************************/


/****************************************************
Checks the global invariant that the response to a task request is always correct and there is no error on the
server side with the implementation of the task logic.

2 invariants:
    1. A task is completed only once. (ePending == eResolved + eRejected)
    2. Only one worker can claim a task at a time and they must claim it with the latest taskId and counter.
****************************************************/
// todo: handle multiple tasks. 
spec GuaranteedServerCorrectness observes eDBWrite, eTimeOut, eClaimTaskResp, ePromisePending, ePromiseResolved, ePromiseRejected {
    var registry: map[int, (bool, bool)]; // map[taskId: (pending, resolved | rejected)]
    var electedWorker: any; 
    var taskId: int; 
    var currCounter: int; 

    start state Init {
        entry {
            electedWorker = null; 
            goto WaitForEvents; 
        }
    }

    state WaitForEvents {
        // Database is the source of truth for the current task id and counter.
        on eDBWrite do (req: tDBWrite) {
            taskId = req.taskId; 
            currCounter = req.counter; 
        }

        // If the task timesout, it should reset the elected worker. todo: release on global timeout or any timeout ? 
        on eTimeOut do {
            electedWorker = null;
        }

        on eClaimTaskResp do (resp: tClaimTaskResp) {
            assert (taskId in registry);
            assert (resp.status == CLAIM_SUCCESS || resp.status == CLAIM_ERROR); 

            if (resp.status == CLAIM_SUCCESS) {
                if (electedWorker == null) {
                    electedWorker = resp.worker;
                } else {
                    assert (electedWorker == resp.worker); 
                }
	            assert (resp.taskId == taskId); 
                assert (resp.counter == currCounter);
            } else {
                // make sure the server didn't make a mistake and reject the claim when it should have accepted it.    
                // should always return claim error if the task is already completed.        
                if (registry[taskId].1 == false) {
                    assert (resp.worker != electedWorker || (resp.taskId != taskId || resp.counter != currCounter));
                } 
            }
        } 

        // Guarantee that a task is completed only once.
        on ePromisePending do (taskId: int)  {
            assert (taskId in registry == false);

            registry[taskId] = (true, false);
        }

        on ePromiseResolved do (taskId: int) {
            assert (taskId in registry); 
            assert (registry[taskId].0 == true);
            assert (registry[taskId].1 == false);
            
            registry[taskId] = (true, true);
        }

        on ePromiseRejected do (taskId: int) {
            assert (taskId in registry); 
            assert (registry[taskId].0 == true);
            assert (registry[taskId].1 == false); 

            registry[taskId] = (true, true);
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