

F = uint16(double(intmax('uint16'))*rand(1024,1024,8));
F = gpuArray(F);
pool = gcp;
import parallel.internal.queue.FutureCreation

fut = parallel.FevalFuture( @ignition.stream.gpu.applyHybridMedianFilterGPU, 1, {F} );

spool = struct(pool);
Q = spool.FevalQueue;
submit(fut,Q)


argsOut = cell(1,1);
[argsOut{:}] = fetchOutputs(fut);