/* User Defined Events */

// Payload type associated with eClaimTaskReq. 
type tClaimTaskReq = (worker: Worker, taskId: int, counter: int); 
// Payload type associated with eCompleteTaskReq. 
type tCompleteTaskReq = (worker: Worker, status: tCompleteTaskRespStatus, taskId: int, counter: int);

// Enum representing the response status for the claim task request. 
enum tClaimTaskRespStatus {
  CLAIM_SUCCESS,
  CLAIM_ERROR
}

// Enum representing the response status for the complete task request. 
enum tCompleteTaskRespStatus {
  RESOLVED,
  REJECTED
}

// Event: claim task request (from worker to server). 
event eClaimTaskReq : tClaimTaskReq;
// Event: claim task response (from server to worker). 
event eClaimTaskResp : tClaimTaskRespStatus; 
// Event: task completion (from worker to server). 
event eCompleteTaskReq : tCompleteTaskReq; 

/*****************************************************************************************
The worker state machine models the worker's protocol when receiving a task. 
******************************************************************************************/
machine Worker {
    var task: Task; 
    var taskId: int; 
    var counter: int;

    start state init {
      on eSubmitTaskReq goto ClaimTask with (req: tSubmitTaskReq) {
        task = req.task; 
        taskId = req.taskId; 
        counter = req.counter;
      }
    }

    state ClaimTask {
      entry {
        send task, eClaimTaskReq, (worker = this, taskId = taskId, counter = counter); 
        goto WaitForClaimResponse; 
      }
    }

    state WaitForClaimResponse {
      on eClaimTaskResp do (status: tClaimTaskRespStatus) {
        if (status == CLAIM_SUCCESS) {
          goto CompleteTask;
        } else {
          goto init; 
        }
      }

      ignore eSubmitTaskReq;
    }

    state CompleteTask  {
      entry {
        if ($) {
          send task, eCompleteTaskReq, (worker = this, status = REJECTED, taskId = taskId, counter = counter);
        } else {
          send task, eCompleteTaskReq, (worker = this, status = RESOLVED, taskId = taskId, counter = counter);
        }
        
        // Regardless of whether the task was completed or not, we go back to the init state.
        goto init; 
      }

      ignore eSubmitTaskReq;
    }
}
