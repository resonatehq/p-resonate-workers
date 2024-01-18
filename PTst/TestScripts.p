// asserts the liveness monitor
test tcTaskWithMultipleWorkers [main = TaskWithMultipleWorkers]: 
    assert GuaranteedTaskProgress in (union TaskWorkerProtocol, { TaskWithMultipleWorkers });
