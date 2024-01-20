// asserts the liveness monitor
test tcTaskWithMultipleWorkers [main = TaskWithMultipleWorkers]: 
    assert GuaranteedServerCorrectness, GuaranteedTaskProgress in (union TaskWorkerProtocol, { TaskWithMultipleWorkers });
