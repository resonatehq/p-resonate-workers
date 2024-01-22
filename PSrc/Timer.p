
/* User Defined Events */

// Event: timer was started (from timer to client). ) 
event eStartTimer;
// Event: timer was cancelled (from timer to client).
event eCancelTimer;
// Event: timer timed out (from timer to client).
event eTimeOut;
// Event: timer timed out (from timer to timer).
event eDelayedTimeOut;

/*****************************************************************************************
The timer state machine models the non-deterministic behavior of an OS timer. 
******************************************************************************************/
machine Timer
{
  // User of the timer. 
  var client: machine;
  start state Init {
    entry (_client : machine){
      client = _client;
      goto WaitForTimerRequests;
    }
  }

  state WaitForTimerRequests {
    on eStartTimer goto TimerStarted;
    ignore eCancelTimer, eDelayedTimeOut;
  }

  state TimerStarted {
    defer eStartTimer;
    entry {
      if($)
      {
        send client, eTimeOut;
        goto WaitForTimerRequests;
      }
      else
      {
        send this, eDelayedTimeOut;
      }
    }
    on eDelayedTimeOut goto TimerStarted;
    on eCancelTimer goto WaitForTimerRequests;
  }
}

// Create timer. 
fun CreateTimer(client: machine) : Timer
{
  return new Timer(client);
}

// Start timer. 
fun StartTimer(timer: Timer)
{
  send timer, eStartTimer;
}

// Cancel timer. 
fun CancelTimer(timer: Timer)
{
  send timer, eCancelTimer;
}