/* User Defined Events */

// event: event sent by the failure injector to delay a node failure
event eDelayNodeFailure;
// event: event sent by the failure injector to shutdown a node
event eShutDown: machine;

/*****************************************************************************************
The failure injector machine randomly selects a replica machine and enqueues the special event "halt". 
******************************************************************************************/
machine FailureInjector {
  var nFailures: int;
  var nodes: set[machine];

  start state Init {
    entry (config: (nodes: set[machine], nFailures: int)) {
      nFailures = config.nFailures;
      nodes = config.nodes;
      assert nFailures <= sizeof(nodes); // can be equal since we restart not halt
      goto FailOneNode;
    }
  }

  state FailOneNode {
    entry {
      var fail: machine;

      if(nFailures == 0)
        raise halt; // done with all failures
      else
      {
        if($)
        {
          fail = choose(nodes);
          send fail, eShutDown, fail;
          nodes -= (fail);
          nFailures = nFailures - 1;
        }
        else {
          send this, eDelayNodeFailure;
        }
      }
    }

    on eDelayNodeFailure goto FailOneNode;
  }
}

// Function to create the failure injection. 
fun CreateFailureInjector(config: (nodes: set[machine], nFailures: int)) {
  new FailureInjector(config);
}
