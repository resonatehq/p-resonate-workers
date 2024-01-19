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
    var task: Task;  
    var workers: set[Worker]; 

    // create two workers. 
    workers += (new Worker()); 
    workers += (new Worker());
    
    // create the failure injector   
    new FailureInjector((nodes = workers, nFailures = 1));   
    
    // create a task with the given number of workers.
    task = new Task((id = 1, w = workers, retries = 3)); 
}