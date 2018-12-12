function sys = runTonePuffWithCam()
sys.tonepuff = TonePuffSystem;
setup(sys.tonepuff)
sys.braincam = BrainCamSystem;
sys.braincam.experimentSyncObj = sys.tonepuff;
sys.braincam.trialSyncObj = sys.tonepuff;
% start(sys.braincam)
% start(sys.tonepuff)