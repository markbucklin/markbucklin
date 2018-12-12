


asm.system = NET.addAssembly('System')
asm.syscore = NET.addAssembly('System.Core')
asm.sysconf = NET.addAssembly('System.Configuration')
asm.sysxml = NET.addAssembly('System.Xml')
ping = System.Net.NetworkInformation.Ping
ping.SendPingAsync('www.google.com').Result


%pps = System.IO.Pipes.PipeStream
npss = System.IO.Pipes.NamedPipeServerStream('pipename')
npcs = System.IO.Pipes.NamedPipeClientStream('pipename')

npcsa = npcs.ConnectAsync