[loader.config,loader.control,loader.state] = ignition.io.tiff.initializeTiffFileStream()
[videoFrame, streamFinishedFlag, frameIdx] = ignition.io.tiff.readTiffFileStream( loader.config, 1:8);