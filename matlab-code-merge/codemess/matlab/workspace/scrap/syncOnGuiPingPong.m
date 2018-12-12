function syncOnGuiPingPong
    pingLevel = MG2.Util.servePingPong;
    while (MG2.Util.getPongLevel < pingLevel)
        pause(0.01);
    end
end