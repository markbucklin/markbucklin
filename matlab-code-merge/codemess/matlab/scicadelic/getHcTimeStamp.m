function ts = getHcTimeStamp(info)
 imDes = info.ImageDescription;

[idLines,~] = strsplit(imDes,'\r\n');
tfsLine = idLines{strncmp(' Time_From_Start',idLines,12)};
tfsNum = sscanf(tfsLine,' Time_From_Start = %d:%d:%f');
ts.hours = tfsNum(1) + tfsNum(2)/60 + tfsNum(3)/3600;
ts.minutes = tfsNum(1)*60 + tfsNum(2) + tfsNum(3)/60;
ts.seconds = tfsNum(1)*3600 + tfsNum(2)*60 + tfsNum(3);