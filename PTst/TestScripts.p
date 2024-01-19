// asserts the liveness monitor
test tcTaskWithMultipleWorkers [main = TaskWithMultipleWorkers]: 
    assert GuaranteedCorrectness, GuaranteedTaskProgress in (union TaskWorkerProtocol, { TaskWithMultipleWorkers });
