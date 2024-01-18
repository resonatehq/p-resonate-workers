// Test driver that checks the system with multiple workers. 
machine TaskWithMultipleWorkers {
    start state Init {
        entry {
            SetupResonateWorkerSystem(); 
        }
    }
}

// Setup the resonate worker system with the given number of workers.
fun SetupResonateWorkerSystem() {
    var server: Task;  
    var workers: set[Worker]; 

    // create two workers. 
    workers += (new Worker()); 
    workers += (new Worker());
    
    // create the task/server that will be used to distribute work to the workers. 
    server = new Task((id = 1, w = workers, retries = 3)); 
}