/* User Defined Events */

// Payload type associated with eSubmitTaskReq. 
type tSubmitTaskReq = (task: Task, taskId: int, counter: int); 
// Payload type associated with eDBWrite. 
type tDBWrite = (worker: any, taskId: int, counter: int);

// Event: submit available task request (from server to client) 
event eSubmitTaskReq : tSubmitTaskReq; 
// Event: task is pending 
event ePromisePending: int;
// Event: task is rejected
event ePromiseRejected: int; 
// Event: task is resolved
event ePromiseResolved: int; 
// Event: db write 
event eDBWrite: tDBWrite;
// Event: task timeedout 
event eTaskTimeOut: int;


/*****************************************************************************************
The task state machine models the behavior of a resonate task that is submitted to a 
set of workers to be completed. The task state machine is responsible for keeping track 
of the number of retries and timers. 
******************************************************************************************/
machine Task {    
    // Volatile memory. 
    var numOfRetriesAvailable : int;
    var i : int;

    // Durable storage. 
    var timer: Timer; 
    var electedWorker: any;
    var taskId : int;
    var taskCounter : int;
    var workers : set[Worker];  
    var totalNumOfRetries : int;
    var completedState: any; 

    // Every task starts in the init state.
    start state init {
        entry (config: (id: int, w: set[Worker], retries: int)) {
            // Volatile state.
            numOfRetriesAvailable = config.retries;

            // Durable state. 
            timer = CreateTimer(this); 
            electedWorker = null;
            taskId = config.id; 
            taskCounter = -1;
            workers = config.w;
            totalNumOfRetries = config.retries;
            completedState = null; 

            announce ePromisePending, taskId; 
            goto TaskPendingWriteToDB; 
        }

        // Simulate server crash and restart.
        on eShutDown goto Recovery with {}
    } 

    state Recovery {
        // On recovery reset all volatile state. Not gonna decrement retries in the db (too many writes). 
        entry {
            // Simulate database read.
            numOfRetriesAvailable = totalNumOfRetries;
            i = 0; 

            if (completedState == RESOLVED) {
                goto TaskResolved;
            } 
            if (completedState == REJECTED) {
                goto TaskRejected;
            }

            goto TaskPendingWriteToDB;
        }

        // Simulate complete task timeout.
        on eTimeOut goto TaskPendingWriteToDB with {
            electedWorker = null;
            announce eTaskTimeOut, taskId;
        }  

        // Simulate server crash and restart.
        on eShutDown goto Recovery with {}
    }

    state TaskPendingWriteToDB {
	    entry {
		    // Keep track of the number of retries. (volatile memory) 
            if (numOfRetriesAvailable == 0) {
	                goto TaskRejected;
            } 
            numOfRetriesAvailable = numOfRetriesAvailable - 1;

            // Simulate database write. Reset the elected worker and update task counter on recovery path.
            electedWorker = null;
            taskCounter = taskCounter + 1;
            announce eDBWrite, (worker = electedWorker, taskId = taskId, counter = taskCounter); 

            goto TaskPendingWriteToQueue; 
        }

        // Simulate complete task timeout.
        on eTimeOut goto TaskPendingWriteToDB with {
            electedWorker = null;
            announce eTaskTimeOut, taskId;
        }  

        // Simulate server crash and restart.
        on eShutDown goto Recovery with {}
    }

    state TaskPendingWriteToQueue {
        // Send task to all workers.
        entry {
            i = 0; 
            while (i < sizeof(workers)) {
                send choose(workers), eSubmitTaskReq, (task = this, taskId = taskId, counter = taskCounter); 
                i = i + 1;
            }

            goto WaitForClaimRequests; 
        }

        // Simulate server crash and restart.
        on eShutDown goto Recovery with {}
    }

    state WaitForClaimRequests {
        // Start timer to wait for claim task requests.
        entry {
            StartTimer(timer); 
        }

        // Simulate claim task timeout.
        on eTimeOut goto TaskPendingWriteToDB with {
            electedWorker = null;
            announce eTaskTimeOut, taskId;
        }  

        // Simulate server crash and restart.
        on eShutDown goto Recovery with {}

        on eClaimTaskReq do (req: tClaimTaskReq) {
            if ((electedWorker == null || req.worker == electedWorker) && req.taskId == taskId && req.counter == taskCounter){
                // Worker claimed the task in time so cancel the timer.
                CancelTimer(timer);
                
                // Write to "db" before sending response.
                electedWorker = req.worker; 
                announce eDBWrite, (worker = electedWorker, taskId = taskId, counter = taskCounter); 
                goto RespondToClaimRequest, (status = CLAIM_SUCCESS, worker = req.worker, taskId = req.taskId, counter = req.counter);
            }

            // Worker gave the wrong task id or counter so reject the claim request.
            send req.worker, eClaimTaskResp, (status = CLAIM_ERROR, worker = req.worker, taskId = req.taskId, counter = req.counter); 
        }   
        
        // Can't complete a task that is not claimed.
       ignore eCompleteTaskReq;
    }

    state RespondToClaimRequest {
        entry (req: tClaimTaskResp)  {
            send req.worker, eClaimTaskResp, (status = req.status, worker = req.worker, taskId = req.taskId, counter = req.counter);     
            goto WaitForCompleteRequest;
        }

         // Simulate claim task timeout.
         on eTimeOut goto TaskPendingWriteToDB with {
            electedWorker = null;
            announce eTaskTimeOut, taskId;
        }  

        // Simulate server crash and restart.
        on eShutDown goto Recovery with {}
    }

    state WaitForCompleteRequest {
        entry {
            // Start timer to wait for complete task requests.
            StartTimer(timer); 
        }

        // Simulate complete task timeout.
        on eTimeOut goto TaskPendingWriteToDB with {
            electedWorker = null;
            announce eTaskTimeOut, taskId;
        }  

        // Simulate server crash and restart.
        on eShutDown goto Recovery with {}

        on eClaimTaskReq do (req: tClaimTaskReq) {
            if (req.worker == electedWorker && taskId == req.taskId && taskCounter == req.counter) {  
                send req.worker, eClaimTaskResp, (status = CLAIM_SUCCESS, worker = req.worker, taskId = req.taskId, counter = req.counter);     
            } else {
                send req.worker, eClaimTaskResp, (status = CLAIM_ERROR, worker = req.worker, taskId = req.taskId, counter = req.counter); 
            }
        } 

       on eCompleteTaskReq do (req: tCompleteTaskReq) {
            if (req.worker == electedWorker && req.taskId == taskId && req.counter == taskCounter){
                // Worker complete the task in time so cancel the timer.
                CancelTimer(timer);

                // Worker resolved the task.
                if (req.status == RESOLVED) {
                    goto TaskResolved;
                }

                // Worker rejected the task. attempt to retry.
                goto TaskPendingWriteToDB;
            }
        }
    }
    
    state TaskResolved {
        entry { 
            if (completedState == null) {
                announce ePromiseResolved, taskId;
                completedState = RESOLVED;
            }
        }

        // Can't claim a task that is resolved.
        on eClaimTaskReq do (req: tClaimTaskReq) {
            send req.worker, eClaimTaskResp, (status = CLAIM_ERROR, worker = req.worker, taskId = req.taskId, counter = req.counter); 
        } 

        // Simulate server crash and restart.
        on eShutDown goto Recovery with {}

        // Can't do anything else with this task once it is resolved.
        ignore eCompleteTaskReq, eTimeOut;
    }

    state TaskRejected {
        entry {
            if (completedState == null) {
                announce ePromiseRejected, taskId;
                completedState = REJECTED;
            }
        }

        // Can't claim a task that is rejected.
        on eClaimTaskReq do (req: tClaimTaskReq) {
            send req.worker, eClaimTaskResp, (status = CLAIM_ERROR, worker = req.worker, taskId = req.taskId, counter = req.counter); 
        } 
        
        // Simulate server crash and restart.
        on eShutDown goto Recovery with {}
        
        // Can't do anything else with this task once it is rejected. 
        ignore eCompleteTaskReq, eTimeOut;
    }
}
