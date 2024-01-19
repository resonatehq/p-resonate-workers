/* User Defined Events */

// Payload type associated with eSubmitTaskReq. 
type tSubmitTaskReq = (task: Task, taskId: int, counter: int); 

// Event: submit available task request (from server to client) 
event eSubmitTaskReq : tSubmitTaskReq; 
// Event: task is pending 
event ePromisePending;
// Event: task is rejected
event ePromiseRejected; 
// Event: task is resolved
event ePromiseResolved; 


/*****************************************************************************************
The task state machine models the behavior of a resonate task that is submitted to a 
set of workers to be completed. The task state machine is responsible for keeping track 
of the number of retries and timers. 
******************************************************************************************/
machine Task {    
    var taskId : int;
    var taskCounter : int;
    var workers : set[Worker];  
    var numOfRetries : int;
    var timer: Timer; 
    var i : int;

    // Every task starts in the init state.
    start state init {
        entry (config: (id: int, w: set[Worker], retries: int)) {
            taskId = config.id; 
            workers = config.w;
            numOfRetries = config.retries;
            taskCounter = -1;
            timer = CreateTimer(this); 

            announce ePromisePending; 
            
            goto TaskPending; 
        }
    } 

    state TaskPending {
        entry {
            // Keep track of the number of retries.
            if (numOfRetries == 0) {
                goto TaskRejected;
            } 
            numOfRetries = numOfRetries - 1;
            taskCounter = taskCounter + 1;
            
            // Send task to all workers.
            i = 0; 
            while (i < sizeof(workers)) {
                send workers[i], eSubmitTaskReq, (task = this, taskId = taskId, counter = taskCounter); 
                i = i + 1;
            }

            goto WaitForClaimRequests; 
        }
    }

    state WaitForClaimRequests {
        entry {
            // Start timer to wait for claim task requests.
            StartTimer(timer); 
        }

        on eTimeOut goto TaskPending with {}  

        on eClaimTaskReq do (req: tClaimTaskReq) {
            if (req.taskId == taskId && req.counter == taskCounter){
                // Worker claimed the task in time so cancel the timer.
                CancelTimer(timer);
                send req.worker, eClaimTaskResp, (CLAIM_SUCCESS);     
                
                goto WaitForCompleteRequest;
            }

            // Worker gave the wrong task id or counter so reject the claim request.
            send req.worker, eClaimTaskResp, (CLAIM_ERROR); 
        }   
        
        // Can't complete a task that is not claimed.
       ignore eCompleteTaskReq;
    }

    state WaitForCompleteRequest {
        entry {
            // Start timer to wait for complete task requests.
            StartTimer(timer); 
        }

        on eTimeOut goto TaskPending with {}  

        on eClaimTaskReq do (req: tClaimTaskReq) {
            send req.worker, eClaimTaskResp, (CLAIM_ERROR); 
        } 

       on eCompleteTaskReq do (req: tCompleteTaskReq) {
            if (req.taskId == taskId && req.counter == taskCounter){
                // Worker complete the task in time so cancel the timer.
                CancelTimer(timer);

                // Worker resolved the task.
                if (req.status == RESOLVED) {
                    goto TaskResolved;
                }

                // Worker rejected the task. attempt to retry.
                goto TaskPending;
            }
        }
    }
    
    state TaskResolved {
        entry { 
            announce ePromiseResolved;
        }

        on eClaimTaskReq do (req: tClaimTaskReq) {
            send req.worker, eClaimTaskResp, (CLAIM_ERROR); 
        } 

        // Can't do anything else with this task once it is resolved.
        ignore eCompleteTaskReq, eTimeOut;
    }

    state TaskRejected {
        entry {
            announce ePromiseRejected;
        }

        on eClaimTaskReq do (req: tClaimTaskReq) {
            send req.worker, eClaimTaskResp, (CLAIM_ERROR); 
        } 

        // Can't do anything else with this task once it is rejected. 
        ignore eCompleteTaskReq, eTimeOut;
    }
}
