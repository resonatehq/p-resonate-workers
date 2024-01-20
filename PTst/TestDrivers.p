// Test driver that checks the system with multiple workers. 
machine TaskWithMultipleWorkers {
    start state Init {
        entry {
            SetupResonateWorkerSystemWithFailureInjector(); 
        }
    }
}

// Setup the resonate worker system with the given number of workers.
fun SetupResonateWorkerSystemWithFailureInjector() {
    var tasks: set[Task];  
    var workers: set[Worker]; 

    // Create two workers. 
    workers += (new Worker()); 
    workers += (new Worker());
    
    // Create the failure injector for workers. 
    new FailureInjector((nodes = workers, nFailures = 1));   

    
    // Create a task with the given number of workers.
    tasks += (new Task((id = 1, w = workers, retries = 3))); 

    // Create the failure injector for the task. 
    new FailureInjector((nodes = tasks, nFailures = 1));
}