
%% JAVA CLASSES FOR MOUSE CONTROL (ROBOT)
import java.awt.Robot
import java.awt.event.*
robot = Robot;

%%
% clickSequence = @(n) {...
% @() robot.mousePress(InputEvent.BUTTON1_MASK), ...
% @(n) pause(max(.001,n/1000)),...
% @() robot.mouseRelease(InputEvent.BUTTON1_MASK)}


name = 'Plink';
addr = 'http://dinahmoelabs.com/plink';
fprintf('<a  href="%s" >%s</a>\n',addr,name);

clickSequence ={...
	@(~) robot.mousePress(InputEvent.BUTTON1_MASK), ...
	@(n) pause(max(.001,n/1000)),...
	@(~) robot.mouseRelease(InputEvent.BUTTON1_MASK)};


%%
clickForMillisecondsFcn = @(n) cellfun(@feval, clickSequence, repelem({n},numel(clickSequence)));

clickForMillisecondsFcn(50)




%%

screenSize = get(0, 'screensize');

speed = 15
absOffset = 750
jumpSize = 60
toneLength = 75;

chooseAbs = @() randn*200 + absOffset;
getCurrentPositionFcn = @() int32(get(0,'PointerLocation'));
move = @(p) robot.mouseMove( 800, int32( (chooseAbs() + p(2))/2 + jumpSize*(randn^2)*sign(randn)) )


%%
K = 24;
continueFlag = 'Yes';
k=K;
while true
	
	
	while k>1
		pause(rand/speed);
		curpos = int32(get(0,'PointerLocation'));
		move(curpos);
		clickForMillisecondsFcn(round((rand+sum(rand(5,1)<.05))*toneLength))
		k=k-1;
	end
	
% 	command = input('Q -> quit\nF -> faster\nS -> slower\n', 's');
	continueFlag = questdlg('keep going?','stop or change','longer','same','shorter','same');	
	if isempty(continueFlag) %~strcmpi(continueFlag,'cancel')
		break
	else
		
		switch continueFlag
			case 'longer'
				toneLength = toneLength *1.05;
			case 'shorter'
				toneLength = toneLength *.95;
		end
		k = K;
	end
end











