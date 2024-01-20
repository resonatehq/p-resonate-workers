/* User Defined Events */

// Payload type associated with eClaimTaskReq. 
type tClaimTaskReq = (worker: Worker, taskId: int, counter: int); 
// Payload type associated with eClaimTaskResp. 
type tClaimTaskResp = (status: tClaimTaskRespStatus, worker: Worker, taskId: int, counter: int);
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
event eClaimTaskResp : tClaimTaskResp; 
// Event: task completion (from worker to server). 
event eCompleteTaskReq : tCompleteTaskReq; 

/*****************************************************************************************
The worker state machine models the worker's stateless protocol when receiving a task. 
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

      // Simulate worker crash and restart.
      on eShutDown goto init; 

      ignore eClaimTaskResp;
    }

    state ClaimTask {
      entry {
        // Simulate message loss.
        if($) {
          send task, eClaimTaskReq, (worker = this, taskId = taskId, counter = counter);
        }
         
        goto WaitForClaimResponse; 
      }

      // Simulate worker crash and restart.
      on eShutDown goto init; 

      defer eSubmitTaskReq;
    }

    state WaitForClaimResponse {
      on eClaimTaskResp do (resp: tClaimTaskResp) {
        if (resp.status == CLAIM_SUCCESS) {
          goto CompleteTask;
        } else {
          goto init; 
        }
      }

      // Simulate worker crash and restart.
      on eShutDown goto init; 

      defer eSubmitTaskReq;
    }

    state CompleteTask  {
      entry {
        // Simulates message loss.
        if($) { 
          if ($) {
            send task, eCompleteTaskReq, (worker = this, status = REJECTED, taskId = taskId, counter = counter);
          } else {
            send task, eCompleteTaskReq, (worker = this, status = RESOLVED, taskId = taskId, counter = counter);
          }
        }
        
        // Regardless of whether the task was completed or not, we go back to the init state to wait for another task.
        goto init; 
      }

      // Simulate worker crash and restart.
      on eShutDown goto init; 

      defer eSubmitTaskReq;
    }
}
