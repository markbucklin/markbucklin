s = daq.createSession('ni');
clk = s.addCounterOutputChannel('Dev1','ctr1','PulseGeneration');
clk.Frequency = 2160;
s.DurationInSeconds = 1;
s.startBackground

