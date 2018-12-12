
%% PRINT HYPER-LINK TO PLINK WEBSITE
site.name = 'Plink';
site.addr = 'http://dinahmoelabs.com/plink';
fprintf('<a  href="%s" >%s</a>\n',site.addr,site.name);

%% SPEECH SYNTHESIZER
% speech.asm = NET.addAssembly('System.Speech');
% speech.synth = System.Speech.Synthesis.SpeechSynthesizer; 
% speech.synth.Volume = 50

%% IMPORT JAVA CLASSES FOR MOUSE CONTROL
import java.awt.Robot
import java.awt.event.*
h.root = groot;

%% CREATE ROBOT (SIMULATED MOUSE CONTROLLER)
% speech.synth.SpeakAsync('Creating rowbot to simulate mouse control');
robot = Robot;
clickSequence ={...
	@(~) robot.mousePress(InputEvent.BUTTON1_MASK), ...
	@(n) pause(max(.001,n/1000)),...
	@(~) robot.mouseRelease(InputEvent.BUTTON1_MASK)};
clickForMillisecondsFcn = @(n) cellfun(@feval, clickSequence, repelem({n},numel(clickSequence)));
clickForMillisecondsFcn(50)

%% CREATE TIMED MOUSE CLICKER
clickTimer = timer;
clickTimer.ExecutionMode = 'singleShot';

%% DEFINE PARAMETERS (STORED IN TIMER USERDATA)
ud.screenSize = get(0, 'screensize');
ud.speed = 15
ud.toneLength = 75;
ud.centerOffset = 640;
ud.jumpSize = 60
clickTimer.UserData = ud;

%% DEFINE SET/GET/UPDATE FUNCTIONS FOR
currentYPosFcn = @() h.root.PointerLocation(2);
%jitterOffsetFcn = @() randn*200 + clickTimer.UserData.centerOffset;
%generateJumpFcn = @(hTimer,evtData) jitterOffsetFcn(hTimer) + currentYPosFcn()/2 + hTimer.UserData.jumpSize*(randn^2)*sign(randn);
%roboMoveMouseFcn = @(dy) robot.mouseMove( int32(h.root.PointerLocation(1)), int32(h.root.PointerLocation(2) + dy) );

%%
%clickTimer.StartFcn = @(hTimer,evtData) set(hTimer,'UserData', hTimer.UserData
%clickTimer.TimerFcn = @(hTimer,evtData) clickForMilliseconds( hTimer.UserData.toneLength)

%% CREATE TIMED MOUSE MOVER
moveTimer = timer;
moveTimer.ExecutionMode = 'fixedRate';
st = struct(moveTimer);
warning off MATLAB:structOnObject

%% DEFINE FUNCTIONS FOR CALCULATING NEXT MOUSE LOCATION
generateRandomJumpFcn = @(a) a .* randn;
showMoveFcn = @(dy) fprintf('%i -> %i\n', round(h.root.PointerLocation(2)), round(h.root.PointerLocation(2)+dy));
moveMouseFcn = @(dy) set(h.root, 'PointerLocation', [h.root.PointerLocation(1) round(h.root.PointerLocation(2)+dy)]);
setJumpSize = @(a) setUserData(struct(moveTimer).jobject, a);


%% SET TIMER FUNCTION TO EITHER MOVE, OR SIMPLY SHOW THE MOVE
%t.TimerFcn = @(hTimer,evtData) showMoveFcn(rjFcn(struct(hTimer).jobject.UserData));
moveTimer.StartFcn = @(varargin) setJumpSize(10)
moveTimer.TimerFcn = @(hTimer,evtData) moveMouseFcn(generateRandomJumpFcn(struct(hTimer).jobject.UserData));

start(moveTimer)
setJumpSize(10)







% return

%% TESTING
% speech.asm =	NET.addAssembly('System.Speech');
% speech.synth = System.Speech.Synthesis.SpeechSynthesizer; 
% speech.synth.Volume = 50
% Speak(ss,'You can use .NET Libraries in MATLAB')
% SpeakAsync( speech.synth, 'Ready to go in 3'), pause(.75)
% SpeakAsync( speech.synth, '2'), pause(.75)
% SpeakAsync( speech.synth, '1'), pause(.5)
% SpeakAsync( speech.synth, 'Here we go')
for k=round(20.*1.3.^(1:15))
	SpeakAsync( speech.synth, sprintf('%d millisecond\n',k) )
	fprintf('%d ms\n',k)
	clickForMillisecondsFcn(k)
	pause(.5)
end





%% CREATE CONTROLS FOR PARAMETERS
%h.fig = uifigure;
%h.sld = uislider('Parent',h.fig);