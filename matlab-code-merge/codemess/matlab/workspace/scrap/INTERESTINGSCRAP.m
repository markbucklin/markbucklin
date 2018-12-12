!cpuid_info
!gpu_info
[~,txt] = system('smpd -help')
% global switches -> /USER /PASSWORD /OUTPUT
!wmic -?
!wmic /user /?
!wmic process /?


% UNSORTED
session = pool.hGetSession()
ss = get(session)
printEvalFcn = @(n)fprintf('condition %d evaluated\n',n)
condit = @(n,b) logical(printEvalFcn(n)) & b
if ( condit(1,true) || condit(2,false) ), fprintf('TRUE\n'), else, fprintf('FALSE\n'), end
if ( condit(1,false) || condit(2,false) ), fprintf('TRUE\n'), else, fprintf('FALSE\n'), end
ptr = ParfevalTaskRunner(pool,4)
ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment
dcor = distcomp.getdistcompobjectroot
microtimer = performance.utils.getMicrosecondTimer
perftracer = PerfTools.Tracer
array2str(randi(0,5,5))
pipe = des.util.cellpipe('despipe')
sysutils=false
if sysutils
	!PsInfo
!PsList
!PsGetSid
!PipeList
!PsService
!Streams
!Sync
!ZoomIt
!NTFSInfo
!NTFSInfo C
!ListDLLs
end
[file.name, file.permission, file.machineformat, file.encoding] = fopen(2);
distcomp.objectroot
t=datenummx(clock), pause(.001), (datenummx(clock) - t)*60*60*24*1000
hLib = extmgr.Library.Instance
load_system('sldelib')
config = extmgr.Configuration('configtype','configname')
fc = matlab.internal.language.introspective.FileContext(func2str(fcn),1)
fc.getLocalVariables
fc.isScript
fc.getLocalFunctions
fc.getCurrentLine
help matlab.internal.language.introspective.FileContext
mshow('internal')
mshow('matlab.internal.container')
precount = getSharedCounter('pre')
postcount = getSharedCounter('post')
firstcount = getSharedCounter('first')
lastcount = getSharedCounter('last')
ssg = Simulink.SubsystemGraph
matlabshared.scopes.source.StreamingSource.getPropertySet
d = org.apache.xerces.parsers.DOMParser

%% UI - UISERVICES - MATLAB.UI.INTERNAL.*
getSystemColor
setActivationAffectsCurrentFigure
Contents
UnsupportedInUifigure
createListener
createMenuPeers
createWinMenu
getClassName
getPanelMargins
getPointerWindow
hasDisplay
isFigureShowEnabled
% COMPONENTFRAMEWORK
matlab.ui.internal.componentframework.WebContainerController
matlab.ui.internal.componentframework.WebComponentController
matlab.ui.internal.componentframework.WebController
matlab.ui.internal.componentframework.WebControllerFactory
matlab.ui.internal.componentframework.services.optional.ControllerInterface
matlab.ui.internal.componentframework.services.optional.BehaviorAddOn
matlab.ui.internal.componentframework.services.optional.HGCommonPropertiesInterface
matlab.ui.internal.componentframework.services.optional.PositionBehaviorAddOn
matlab.ui.internal.componentframework.services.optional.ViewReadyInterface
matlab.ui.internal.componentframework.services.core.eventhandling.WebEventHandlingService
% MIXIN
matlab.ui.internal.mixin.KeyInvokable
matlab.ui.internal.mixin.Positionable
matlab.ui.internal.mixin.ReadOnlyPositionable
matlab.ui.internal.mixin.Selectable
matlab.ui.internal.mixin.TerminalStateRepresentable
matlab.ui.internal.mixin.UIToggleToolMixin
matlab.ui.internal.mixin.UIToolMixin

%DIALOG
matlab.ui.internal.dialog.DialogUtils
matlab.ui.internal.dialog.WebColorChooser
matlab.ui.internal.dialog.ColorChooser
matlab.ui.internal.dialog.Dialog
matlab.ui.internal.dialog.FileChooser
matlab.ui.internal.dialog.FileExtensionFilter
matlab.ui.internal.dialog.FileOpenChooser
matlab.ui.internal.dialog.FileSaveChooser
matlab.ui.internal.dialog.FileSystemChooser
matlab.ui.internal.dialog.FolderChooser
% CONTROLLER
matlab.ui.internal.controller.WebCanvasContainerController
matlab.ui.internal.controller.WebTableController
matlab.ui.internal.controller.WebControllerViewInterface
matlab.ui.internal.controller.FigureController
matlab.ui.internal.controller.FigureContainer
matlab.ui.internal.controller.NumericFormatUtil
matlab.ui.internal.controller.PeerUITableArrayViewModel
matlab.ui.internal.controller.TableView
matlab.ui.internal.controller.UITableArrayDataModel
matlab.ui.internal.controller.UITableArrayViewModel
matlab.ui.internal.controller.UITableVariableEditorMixin
matlab.ui.internal.controller.VariableEditorTableView
matlab.ui.internal.controller.WebMenuController
matlab.ui.internal.componentframework.services.core.identification.IdentificationService
matlab.ui.internal.componentframework.services.core.identification.WebIdentificationService
matlab.ui.internal.componentframework.services.optional.ControllerInterface
matlab.ui.internal.componentframework.services.optional.BehaviorAddOn
matlab.ui.internal.componentframework.services.optional.HGCommonPropertiesInterface
matlab.ui.internal.componentframework.services.optional.PositionBehaviorAddOn
matlab.ui.internal.componentframework.services.optional.ViewReadyInterface
% TOOLSTRIP
matlab.ui.internal.toolstrip.Button
matlab.ui.internal.toolstrip.ButtonGroup
matlab.ui.internal.toolstrip.CheckBox
matlab.ui.internal.toolstrip.Column
matlab.ui.internal.toolstrip.DropDown
matlab.ui.internal.toolstrip.DropDownButton
matlab.ui.internal.toolstrip.EditField
matlab.ui.internal.toolstrip.EmptyControl
matlab.ui.internal.toolstrip.Gallery
matlab.ui.internal.toolstrip.GalleryCategory
matlab.ui.internal.toolstrip.GalleryItem
matlab.ui.internal.toolstrip.GalleryPopup
matlab.ui.internal.toolstrip.Icon
matlab.ui.internal.toolstrip.Label
matlab.ui.internal.toolstrip.ListBox
matlab.ui.internal.toolstrip.ListItem
matlab.ui.internal.toolstrip.ListItemWithCheckBox
matlab.ui.internal.toolstrip.ListItemWithEditField
matlab.ui.internal.toolstrip.ListItemWithPopup
matlab.ui.internal.toolstrip.ListItemWithRadioButton
matlab.ui.internal.toolstrip.Panel
matlab.ui.internal.toolstrip.PopupList
matlab.ui.internal.toolstrip.PopupListHeader
matlab.ui.internal.toolstrip.PopupListPanel
matlab.ui.internal.toolstrip.PopupListSeparator
matlab.ui.internal.toolstrip.RadioButton
matlab.ui.internal.toolstrip.Section
matlab.ui.internal.toolstrip.Slider
matlab.ui.internal.toolstrip.Spinner
matlab.ui.internal.toolstrip.SplitButton
matlab.ui.internal.toolstrip.Tab
matlab.ui.internal.toolstrip.TabGroup
matlab.ui.internal.toolstrip.TextArea
matlab.ui.internal.toolstrip.ToggleButton
matlab.ui.internal.toolstrip.Toolstrip
matlab.ui.internal.toolstrip.base.Control
matlab.ui.internal.toolstrip.base.Component
matlab.ui.internal.toolstrip.base.Node
matlab.ui.internal.toolstrip.base.PeerInterface
matlab.ui.internal.toolstrip.base.Container
matlab.ui.internal.toolstrip.base.Action
matlab.ui.internal.toolstrip.base.ActionService
matlab.ui.internal.toolstrip.base.ToolstripEventData
matlab.ui.internal.toolstrip.base.ToolstripService
matlab.ui.internal.toolstrip.base.Utility

%% LOTS OF METHODS
which('disp','-all')
hdlturnkey.data.StreamChannel

uiservices.DataBuffer

internal.matlab.imagesci.nc.createVariable

PropertyList = sigutils.internal.emission.PropertyDef.empty
PropertyList(1).Name = 'prop1'

f = uint16(randi(65535,1024,1024));
fDim = coder.opaque('int32', int32(size(f)))


%% SHARE ENGINE
matlab.engine.engineName
matlab.engine.shareEngine
matlab.engine.engineName

%% MATLAB.INTERNAL.LANGUAGE.INTROSPECTIVE
fname = which('ign.core.Operation');
fname = which('bwmorphn')
NR = matlab.internal.language.introspective.resolveName(fname)
matlab.internal.language.introspective.helpParts(fname)
%matlab.internal.language.introspective.callHelpFunction
matlab.internal.language.introspective.extractCaseCorrectedName
matlab.internal.language.introspective.extractFile
matlab.internal.language.introspective.extractHelpText(fname)
pkgname = matlab.internal.language.introspective.getPackageName(fname)
matlab.internal.language.introspective.makePackagedName(pkgname,'Operation')
matlab.internal.language.introspective.isClassMFile(fname)
matlab.internal.language.introspective.fixFileNameCase
matlab.internal.language.introspective.fixLocalFunctionCase
matlab.internal.language.introspective.MCOSMetaResolver

%% DATA QUEUE
cq = parallel.pool.Constant(@() parallel.internal.pool.DataQueue, @delete)
idx=1
idx=idx+1; fut = parfeval( @(id) struct('ID', id, 'DataQueue', cq.Value), 1, idx)
out = fut.fetchOutputs()
pq(out.ID) = struct('WorkerID',fut.WorkerID, 'DataQueue',out.DataQueue)

%% CONNECTOR?
connector.ensureServiceOn()
cso = ans
cso.host
chromiumType = javaMethod('valueOf', 'com.mathworks.mlwidgets.html.HtmlComponentFactory$HtmlComponentType', 'CHROMIUM')
chromiumType.beforeBrowserCreation()
htmlComponent = com.mathworks.mlwidgets.html.LightweightBrowserFactory.createLightweightBrowser()
javaRichDocument = com.mathworks.mde.richeditor.widget.rtc.RichDocumentFactory.create(htmlComponent , java.io.File(fname))
cleanupObj = onCleanup(@()destroy(javaRichDocument, htmlComponent))
htmlCommunication = htmlComponent
view = htmlCommunication.getComponent()
view.setBounds(java.awt.Rectangle(1280, 1024))
browser = view.getBrowser()
sprintf('Browser is loading = %d', browser.isLoading())
bufferedImage = java.awt.image.BufferedImage(1280, 1024,java.awt.image.BufferedImage.TYPE_4BYTE_ABGR)
imageJ = view.getImage()
graphics = bufferedImage.getGraphics()
graphics.drawImage(imageJ, 0, 0, [])
fileName = fname
[pathstr,name] = fileparts(fileName)
jFileName =java.io.File(fullfile(pathstr,[name '_error.png']))
javax.imageio.ImageIO.write(bufferedImage, 'PNG', jFileName)


%% FUNCTION WRITING WITH CODEGEN.CODEROUTINE & CODEGEN.CODEPROGRAM
hFunc = codegen.coderoutine
hProgram = codegen.codeprogram



%% CURRENT IMPORTS
import java.awt.*
f = Frame
f.getFrames
callerImports = builtin('_toolboxCallerImports')


%% FILE-CONTEXT -> CURRENT LINE, LOCAL FUNCTIONS, LOCAL VARIABLES
fctx = matlab.internal.language.introspective.FileContext(fname,10)
fctx.getCurrentLine
fctx.getInstanceElements
fctx.getLocalFunctions
fctx.getLocalVariables
fctx.isInstanceVariable
fctx.isScript

%% PARALLEL POOL -> TASKS QUEUES
pool = gcp;
Q = parallel.internal.pool.DataQueue
taskrunner = parallel.cluster.TaskRunner
parallel.internal.apishared.getSetTaskCompleteFcn()
javasched = parallel.internal.apishared.LocalUtils.getJavaScheduler
% (unixonly) parallel.internal.apishared.LocalUtils.installLocalSignalHandler
[myHostName, machineToWorkerMapping, myLabIndex] =  ...
	parallel.internal.cluster.getMachineToWorkerMapping()
gmd = parallel.internal.gpu.GPUClusterMediator.getInstance()
[~, sessionObj] = parallel.internal.pool.PoolArrayManager.getCurrent()
clearFcn = @distcomp.clearFunction
runprop = distcomp.runprop

taskFunctionCache = parallel.internal.cluster.TaskFunctionCache
q = java.util.concurrent.LinkedBlockingQueue

%matlab.io.internal.imagesci.tifftagsread

%% SIMULINK PACKAGES
mshow('Simulink')
mshow('Simulink.HMI')
Simulink.HMI.startStreamingToWeb
Simulink.CMI.Subsystem
Simulink.DistributedTarget
Simulink.DistributedTarget.HardwareNode
Simulink.DistributedTarget.AddressAssignmentUtils
Simulink.SoftwareTarget.Task
Simulink.SoftwareTarget.TaskConfiguration
Simulink.SoftwareTarget.BaseTask
Simulink.SoftwareTarget.Trigger
Simulink.SoftwareTarget.AperiodicTrigger
Simulink.SoftwareTarget.PeriodicTrigger
Simulink.SoftwareTarget.Task
Simulink.SoftwareTarget.BlockToTaskMapping
Simulink.SoftwareTarget.TaskTransitionData
Simulink.SoftwareTarget.Mapping
Simulink.SoftwareTarget.concurrentExecution
Simulink.output.Action

Simulink.data.DataSource
Simulink.SimulationData.Storage.RamDatasetStorage

Simulink.FunctionCallInitiatorInfo
Simulink.FunctionSignature
Simulink.FunctionArgument
Simulink.FunctionCallInfo

Simulink.BaseHandleType
Simulink.DeferredMCOSClass

%% BIGDATA CACHE-STORE
import matlab.bigdata.internal.io.DiskCacheStore;
import matlab.bigdata.internal.io.MemoryCacheStore;
cacheStore = [MemoryCacheStore(memoryMaxSize); DiskCacheStore(diskMaxSize)];

%% CONTROLLIB, INPUTOUTPUTMODEL & CODE GENERATION
controllib.internal.codegen.showGeneratedMATLABCode
controllib.internal.codegen.getInputArguments
controllib.internal.codegen.appendMATLABCode
InputOutputModel
DynamicSystem
StaticModel
StateSpaceModel
A = ureal(NAME,NOMINAL,'PlusMinus',[-DL,DR])
lft
help DynamicSystem/mrgios

% LTI -> LTIPACK, LTIBLOCK
ltipack.ssdata
ltipack.AbstractPID
ltipack.allprops
ltipack.checkStateInfo
ltipack.checkRowColIndices
ltipack.checkVariable
ltipack.getFeedbackPath
ltipack.findNamesInList
ltipack.dotref
ltiblock.gain.matchChannelNames
D = ltipack.ssdata
D.Ts=0
D.Delay = ltipack.utDelayStruct(0,0,true)

%% NODE INFO
spmd,
	[lab_myHostName, lab_machineToWorkerMapping, lab_myLabIndex] =  ...
		parallel.internal.cluster.getMachineToWorkerMapping();
	lab_gmd = parallel.internal.gpu.GPUClusterMediator.getInstance();
	lab_nodeinfo = ignition.alpha.NodeInfo( lab_gmd, [1 2], []);
end

%% LEAD WORKERS
pool = gcp;
lw = parallel.internal.pool.LeadWorkers.getForPool(pool)
getreminfoFcn = @() struct(...
	'LabIndex',labindex,...
	'NumLabs',numlabs,...
	'CurrentWorker',getCurrentWorker())
fut = fevalOnLeadWorkers(lw, getreminfoFcn , 1)
wait(fut); % while ~strcmp(fut.State,'finished'), pause(.001), end
lout = fut.OutputArguments{1}{1};
lout_consume = fut.fetchOutputs
lout.CurrentWorker

tic
fut = parallel.internal.queue.FilteringFuture.createAndSubmit(pool, 1, 3, getreminfoFcn, 1)
wait(fut)
wout = fetchOutputs(fut)
toc



timeit(@() distcompdeserialize(distcompserialize64(gather(ccell))), 1) * 1000
allcrdistributedutil.Allocator


tens = distcompMakeByteBufferHandle(uint8([10,2]))
parallel.internal.pool.serialize(10) % -> java ByteBufferHandle
%vs
distcompserialize(10) % -> uint8
distcompserialize64(10) % -> uint8


session = pool.hGetSession();
p = parallel.internal.getJavaFutureInterruptibly(...
	session.createParforController());
data = parallel.internal.pool.serialize(varargin);
OK = obj.ParforController.addInterval(tag, data);
OK = obj.ParforController.addFinalInterval(tag, data);


% ??
poolWorker = parallel.internal.pool.PoolWorker()
parallel.internal.pool.PoolArrayManager.add(poolWorker)
tc = parallel.internal.apishared.TaskCreation
taskargchk = tc.createTaskArgCheck
interactiveWorker = parallel.internal.pool.InteractiveWorker( 2, 6, @labBroadcast)
interactiveWorker.WorkerIndex
[diffInMs, startDate] = parallel.internal.cluster.calculateRunningDuration()

%% JAVA STUFF
jt = java.util.Timer('nondaemon', false)
jtd = java.util.Timer('nondaemon', true)
jct = java.lang.Thread.currentThread
jtg = jct.getThreadGroup
jtg.list
Tmillis = java.lang.System.currentTimeMillis();
pq = java.util.PriorityQueue
clq = java.util.concurrent.ConcurrentLinkedQueue
lbq = java.util.concurrent.LinkedBlockingQueue
dq = java.util.concurrent.DelayQueue
chm = java.util.concurrent.ConcurrentHashMap
ltq = java.util.concurrent.LinkedTransferQueue
ltq.getWaitingConsumerCount

java.util.concurrent.ForkJoinWorkerThread.activeCount
t = java.util.concurrent.ForkJoinWorkerThread.currentThread()
tg = t.getThreadGroup
tgsys = getParent(tg)
get(tgsys)
get(tg)

%% CPU LOAD
osbean = java.lang.management.ManagementFactory.getOperatingSystemMXBean();
cpuload = osbean.getSystemLoadAverage() / osbean.getAvailableProcessors();
%memavail
bean = java.lang.management.ManagementFactory.getOperatingSystemMXBean();
memavail = bean.getTotalPhysicalMemorySize - bean.getCommittedVirtualMemorySize;
memfree = java.lang.management.ManagementFactory.getOperatingSystemMXBean().getFreePhysicalMemorySize();
% look in BCILAB/code/helpers for nanocache and microcache

%% PARALLEL CALL LATENCY
tic, pctPreRemoteEvaluation( 'mpi_mi' ), toc
% --> calls private function --> dctRegisterMpiFunctions( type );
% then rehashes: rehash takes 12ms!!!!!!!!!

root = distcomp.getdistcompobjectroot;
job = root.CurrentJob;
task = root.CurrentTask;
runprop = root.CurrentRunprop;

tr = parallel.cluster.TaskRunner


% MPI/SPMD -> LABSEND LABRECEIVE LABPROBE
data = uint8(1:100);
destination = 2:numlabs;
tag = 55;
labFrom = 1;
labTo = 2;

% (on scheduling thread)
labSend( data, destination, tag )
labSend( data, destination) % tag = 0

% (on worker) -> async check
[data_available, source, tag] = labProbe
[data_available, source, tag] = labProbe(labFrom)
[data_available, source, tag] = labProbe( 'any', tag)
% (on worker) -> blocking receive
[data, source, tag] = labReceive(labFrom, tag)
% concurrent send/receive
received = labSendReceive(labTo, labFrom, data, tag)
% broadcast
updated_data = data + 1; % -> data = data + 1
root = 4; % lab that updated data
data = labBroadcast( root, updated_data )

% SPMD-LANG? -> override these functions to transfer data..?
[fcnH, userData] = getRemoteFromSPMD( data )
[fcn, data] = getUserDataToSPMD( Q )
varargout = spmd_feval_fcn( fcnH, argsInCell, varargin ) %??

% VALUE-STORE -> key-val container for worker-side storage of remote object contents
localPropStorage = spmdlang.KeyHolder(key,ressetidx,resourcesetholder)
localPropStorageKey = spmdlang.ValueStore.store( value)

% or % DISTRIBUTED-UTIL -> AUTOTRANSFER
obj = distributedutil.AutoTransfer( data )
obj = distributedutil.AutoTransfer( data , 1) % lab that stores data?
[factory, userData] = getRemoteFromSPMD( obj )
% factory (fcn) -> builds AutoDeref object which transfers data then returns it

% SIMULINK DATA-STORAGE
Simulink.SimulationData.Dataset
%   Simulink.SimulationData.Signal
%   Simulink.SimulationData.DataStoreMemory
%   Simulink.SimulationData.BlockPath

% SYNC ON ERROR
varargout = syncOnError(func, varargin)


% GPU
info = parallel.gpu.NodeInfo
obj = parallel.gpu.GPUDeviceManager.instance();
% events	-> DeviceDeselecting -> move any gpuArray data to cpu
%					-> DeviceSelected

%% INTERVAL TIMER
t = internal.IntervalTimer(0.800)
toolboxdir(fullfile('shared','testmeaslib','general','bin',...
	computer('arch')))
lh = event.listener(t,'Executing',@(src,data) disp(data))
start(t)
stop(t)

%% DAS DEFER OR DELAYED CALLBACK & ACCUMULATOR
%runperf
ignition.shared.Accumulator
DASdeferCallback
DAStudio.delayedCallback()
DASdeferCallback(callback,varargin{:});
DAStudio.makeCallback(   )
StateflowDI.Data

%% PLINK MUSIC PLAYER LINK & WebDDG (HTML Browser)
addr = 'http://dinahmoelabs.com/plink'
name = 'Plink';
plinkLink = sprintf('<a  href="%s" >%s</a>\n',addr,name)
obj = DAStudio.WebDDG(addr)
obj.Title = name
obj.moveTo(200, 0)
obj.moveTo(0, 0)
delete(obj)

%% STREAM
pth = 'Z:\.TEMP\iostreamfile';
strm = matlab.io.datastore.internal.filesys.createStream(pth);
mode = 'rb'; % 'wb' 'rwb' 'rt' 'wt' 'rwt'
strm = matlab.io.datastore.internal.filesys.createStream(pth, mode)
%strm = matlab.io.datastore.internal.filesys.BinaryStream(pth, mode)

udpserv = raspi.internal.udp.ByteServer
udpchan = raspi.internal.udp.Channel

%strm = matlab.io.datastore.internal.filesys.BinaryStream(pth, mode);
% pathLookupLocal
% pathLookupIRI

addLink()

%% GPU USAGE IN COMM-SYSTEM TOOLBOX
f = gpuArray(uint16(50000*rand(1024,1024)));
comm.gpu.internal.getGPUDataType('uint16')
comm.gpu.internal.getGPUDataType('single')
galloc = comm.gpu.internal.gpuArrayAlloc(1024,1024,'single');
comm.gpu.internal.getCPUInfo
decoder = comm.gpu.internal.APPDecoder
decoder.TrellisStructure.nextStates
decoder.TrellisStructure.outputs
cudasys = comm.gpu.internal.CUDAKernelSystemBase
gpubase = comm.gpu.internal.GPUBase

gpubase = matlab.system.internal.gpu.GPUBase
matlab.system.internal.gpu.GPUSystem
mcg = meta.package.fromName('comm.gpu')

% TIME SYNCHRONIZER
comm.internal.TimingSynchronizerBase

% Bit2Int & Int2Bit
comm.internal.convertInt2Bit
comm.internal.convertBit2Int

%% MATLAB SYSTEM (OTHER)
nd = matlab.system.NodeData()
matlab.system.internal.registerBus
matlab.system.internal.CustomDataType
matlab.system.internal.DataTypeSet
matlab.system.internal.PropertyOnly
matlab.system.internal.PropertyOrInput
matlab.system.internal.PropertyOrMethod
matlab.system.internal.toggleFunctionNotationMode


%% HOSTNAME AND OTHER PARALLEL INTERNALS (togglable cleanup)
hostutil = parallel.internal.general.HostNameUtils
togglableCleanup = parallel.internal.general.DisarmableOncleanup(@(varargin) fprintf('cleaning up'))
togglableCleanup.disarm

tCh = parallel.internal.cluster.TaskFunctionCache

%% TYPE CHECKING -> SIGDATATYPES PKG


%% SIGUTILS CLASS & FUNCTION GENERATORS
cgen = sigutils.internal.emission.MatlabClassGenerator
fgen = sigutils.internal.emission.MatlabFunctionGenerator


%% WEB-CONNECTOR (HTML)
[isRunning, hostInfo] = connector('status') %arg, varargin)

%% MOBILE-CONNECTOR
mobconn = mobiledev()


whitelist_serviceoverride = {};
service = mls.internal.FevalService(whitelist_serviceoverride)
connector.version
connector.port
connector.internal.autostart.run
connector.internal.autostart.run
connector.internal.feature.directoryListing
connector.internal.feature.nonce
connector.internal.engine
connector.internal.getHostInfo
connector.internal.getHostName
connector.internal.getMessageStr
connector.internal.MConfig
mcfg = connector.internal.MConfig
mcfg.getWebWidgetLatestVersion
wsrv = connector.internal.webserver.start
connector.internal.webserver.port
connector.internal.webserver.isRunning
connector.internal.webserver.securePort
mproxy = connector.internal.webserver.MobileProxyServer
mproxy.isRunning
connector.internal.webserver.wrapper.getHostName
connector.internal.webserver.wrapper.isRunning
connector.internal.webserver.wrapper.MobileProxyServer
connector.internal.webserver.wrapper.port
connector.internal.webserver.wrapper.start
connector.internal.webserver.wrapper.getCertificateLocation
connector.internal.webserver.wrapper.getEnableSessionNonce
connector.isRunning



% BYTES->FILE (SERIALIZATION)
SimulinkRealTime.utils.bytes2file('SimulinkRealTime_utils_bytes2file', uint8(1:100))

%% TIMESERIES
tsWithUnits = timeseries.createSeed('cam_scmos1_raw');

%% SIMULINK TYPES
% Simulink.Data
f = randi(intmax('uint16'),1024,1024,'uint16');
f = Simulink.Parameter(f)
f.StorageClass = 'SimulinkGlobal'
s = struct('a',5, 'b',5:20)
s = Simulink.Bus.createObject(s)

% SIMULATIONDATA - DATASET
topOut = Simulink.SimulationData.Dataset



sparam = Simulink.Parameter
sbus = Simulink.Bus
cgraph = Simulink.CallGraph
sfinfo = Simulink.FrameInfo
Simulink.TimeInfo
% Simulink.GlobalDataTransfer
% Simulink.Port
stk = Simulink.Structure.Utils.Stack
% Simulink.Structure.Utils.getAllInportHandles
tscope = Simulink.ui.scope.TimeScope

memsec = Simulink.MemorySectionDefn
memsec.getMSPropDetails
memsec.IsVolatile
memsec.convert2struct

sroot = Simulink.Root
sroot.Blocks
sroot.ConditionallyExecuteInputs
sroot.ContinueFcn
sroot.FunctionConnectors
sroot.DisplayBlockIO
sroot.PauseFcn
sroot.StartFcn
sroot.ShowPortDataTypes
sroot.TunableVarsStorageClass

config = Simulink.ConfigSet
config.concurrentExecutionComponents
config.getCommonProperties
config.getDialogController
config.isLinked
config.getParent
config.getComponent
config.view

asyncSigClient = Simulink.AsyncQueue.SignalClient

bdroot

% Data UUID
Simulink.dd.UUID.nil

[~,id] = fileparts(tempname)
Simulink.dd.UUID(id(3:end))
ddcur = Simulink.dd.current

% simulink data inspector
Simulink.sdi.changeLoggedToStreamed
Simulink.sdi.clearSignalsFromCanvas
Simulink.sdi.cacheSessionInfo
Simulink.sdi.autoGroupingFeature
Simulink.sdi.ConnectorAPI
connapi.areControllersInitialized
Simulink.sdi.flushStreamingBackend
eng = Simulink.sdi.Engine
eng.defaultTolAndSyncOptions
eng.getRun(4)
run.MachineName
run.UserID
sm = Simulink.sdi.Map
sm.getCount
ssm.serialization

filesys = SimulinkRealTime.fileSystem

ifcPanel = Stateflow.Interface.Panel;
ifcPanel.createRowForObject

%% SIMULINK DISTRIBUTED TARGET
Simulink.DistributedTarget.Connection
Simulink.DistributedTarget.ChannelInterface
Simulink.DistributedTarget.DistributedTargetUtils.getIndexOfHardwareNode
Simulink.DistributedTarget.SoftwareNode
Simulink.DistributedTarget.BaseMappingEntity
Simulink.DistributedTarget.TargetSpecificProperty
Simulink.DistributedTarget.SignalToConnectionMapping
Simulink.DistributedTarget.evalArchitectureProperties
Simulink.DistributedTarget.isMappedToHardwareNode
Simulink.DistributedTarget.CustomArchForConcurrentExecution
mgr = Simulink.DistributedTarget.internal.getmappingmgr
mgr = Simulink.DistributedTarget.internal.map
Simulink.DistributedTarget.Template
Simulink.DistributedTarget.Node
Simulink.DistributedTarget.Mapping

%% SIMULINK ROOT OBJECT
r = sfroot;
r.addParam('butt')
r.butt = 'hurts';
r.ContinueFcn
r.StartFcn
r.StartTime
r.TunableVars
r.TunableVarsStorageClass
r.VariantConfigurationObject
r.VariantCondition
r.ReportName
r.BufferReuse
r.Blocks
r.getPossibleProperties

%% GENERATE MESSAGE ID ---->>>>> FOR ERRORS & WARNINGS
generatemsgid( 'BasicID' )

% fsbs = matlab.io.datastore.internal.filesys.BinaryStream

%% SYSTEM_DEPENDENT
help system_dependent
system_dependent('_gpu_waitForDevice', gpuDevice) %???


%% LIBMWRTIOSTREAM -> CALLING SHARED LIBRARIES (LIBMX)
binDir = [matlabroot,filesep,'bin',filesep,'win64'];
inclDir = [matlabroot,filesep,'rtw',filesep,'c',filesep,'src'];

% LIBMX LIBRARY
if ~libisloaded('libmx')
	hfile=[matlabroot,'\extern\include\matrix.h'];
	loadlibrary('libmx',hfile);
end

% LIBMEX LIBRARY
if ~libisloaded('libmex')
	hfile=[matlabroot,'\extern\include\mex.h'];
	loadlibrary('libmex',hfile);
end


% PROCESSOR INFO
[status, cpuInfo] = system([binDir,filesep,'cpuid_info.exe'])

% RTIOSTREAM LIBRARY
rtw.connectivity.RtIOStreamHostCommunicator
rtw.connectivity.RtIOStream

'libmwrtiostreamtcpip.dll'
'libmwrtiostreamutils.dll '
'libmwrtiostreamtcpip_stdalone.dll'
'libmwrtiostreamserial.dll'
'libmwsl_AsyncioQueue.dll'

rtiostream_incl_path = [inclDir,filesep,'rtiostream',filesep,'utils']

rtiostream_mod_path = [binDir,filesep,'libmwrtiostreamtcpip.dll'];
rtiostream_def_path = [inclDir,filesep,'rtiostream',filesep,'rtiostream_pc.def']
rtiostream_h_path = [inclDir,filesep,'rtiostream.h'];

rtiostreamutils_mod_path = [binDir,filesep,'libmwrtiostreamutils.dll'];
rtiostreamutils_h_path = [inclDir,filesep,'rtiostream',filesep,'utils',filesep,'rtiostream_utils.h']
rtiostreamuloadlib_h_path = [inclDir,filesep,'rtiostream',filesep,'utils',filesep,'rtiostream_loadlib.h']


addpath( fileparts(rtiostream_mod_path) )
addpath( fileparts(rtiostreamutils_mod_path) )
libname = 'libmwrtiostreamtcpip';
if ~libisloaded(libname)
	[status,loadwarnings] = loadlibrary(libname, rtiostream_h_path)%, 'alias', 'rtiostream')
	%[status,loadwarnings] = loadlibrary(libname, rtiostreamloadlib_h_path)
	%[status,loadwarnings] = loadlibrary(libname, rtiostream_h_path, ...
	%'addheader', rtiostreamuloadlib_h_path)
end
rtiofcns = libfunctions(libname,'-full')

% causes segfault??
%str = 'localhost'
%calllib(libname,'rtIOStreamOpen', int32(730), str)

options.hostname = 'localhost';
options.port = '730';
options.client = '';
options.blocking = '0';
options.verbose = '1';
options.recv_timeout_secs = '';
options.server_info_file = '';
options.protocol = 'udp';
options.udpmaxpacketsize = '';
options.udpsendbuffersize = '';
options.udpreceivebuffersize = '';
str = '';
fld = fields(options);
argc = int32(0);
for k=1:numel(fld)
	if ~isempty(options.(fld{k}))
		str = [ str , ' -',fld{k},' ',options.(fld{k})];
		argc = argc + 1;
	end
end

argv = libpointer('voidPtrPtr',[int8(str) 0] );

calllib(libname,'rtIOStreamOpen', argc, argv)

rtio_stucttype = 'libH_type_tag';
rtio_structtypedef = 'libH_type';


% unloadlibrary(libname)



%% GRAPH FROM INTERNAL CONTAINER PACKAGE
gg = matlab.internal.container.graph.Graph
methodsview(gg)
for k=1:10, vId(k) = gg.addVertex(); end
isVertex(gg, vId(1))
gv = vertex(gg,vId(1))
gv(2) = vertex(gg,vId(2))
eId = addEdge(gg, gv(1), gv(2) )
gedge = edge(gg,eId)
taskOrder = depthFirstTraverse(gg, vid(1))
tclos = gg.transitiveClosure
tclos.EdgeCount
tclos.VertexCount


%% PERFORMANCE MONITORS
perftracer = PerfTools.Tracer
microtimer = performance.utils.getMicrosecondTimer
performance.utils.getModuleList

matlab.io.internal.imagesci.tifftagsread
binDir = [matlabroot,filesep,'bin',filesep,'win64'];
[status, cpuInfo] = system([binDir,filesep,'cpuid_info.exe'])

crviewer % Code Replacement
performance.utils.getModuleList
perftracer = PerfTools.Tracer

%% TIMERS AND TIMING
microtimer = performance.utils.getMicrosecondTimer
matlab.internal.timing.timing('resolution_tictoc')*2^20
t = matlab.internal.timing.timing('cpucount')
matlab.internal.timing.timing('resolution_tictoc')
matlab.internal.timing.timing('overhead_tictoc')*10^6
matlab.internal.timing.timing('getcpuspeed_tictoc')
matlab.internal.timing.timing('cpuspeed')
matlab.internal.timing.timing('clocks_per_sec')
matlab.internal.timing.timing('posixrtperftime')
matlab.internal.timing.timing('posixrtperfspeed')
matlab.internal.timing.timing('cpucount')

datenummx(clock)

% TIMESERIES DATA
tsWithUnits = timeseries.createSeed('cam_scmos1_raw');
java.lang.System.nanoTime()
java.lang.System.currentTimeMillis()
t = java.lang.System.nanoTime(); (java.lang.System.nanoTime()-t)*1/2^10


%% PARALLEL TERMINATION POLICY
parallel.internal.types.TerminationPolicy.Idle
parallel.internal.types.TerminationPolicy.Session
parallel.internal.types.TerminationPolicy.fromName
parallel.internal.types.TerminationPolicy.fromName('butt')


%% FILE ATTRIBUTES
[SUCCESS,MESSAGE,MESSAGEID] = fileattrib(FILE,MODE,USERS,MODIFIER)


%% PACKAGES -> DAStudio, RTW, asyncio, lfsocked, SharedCodeManager, CLUE2 ...
DAStudio
RTW
asyncio
lfsocket
SharedCodeManager
GLUE2

javaObjectMT
javaObjectEDT

GLUE2.Util.getEnabledTransparencyRenderers

tmp = RTW.CodeInterface

lfsocket.ServerSocket

modmap = Simulink.AutosarTarget.ModelMapping

%% GRAPH internal
matlab.internal.container.graph.Graph
mldgraph = matlab.internal.graph.MLDigraph
mlgraph = matlab.internal.graph.MLGraph

%% BINARY STREAM
bs = matlab.io.datastore.internal.filesys.BinaryStream

%% DASTUDIO & RTW
wb = DAStudio.WaitBar
wddg = DAStudio.WebDDG
RTW.StructAccessorVariable
RTW.Variable
RTW.VariantInfo
timifc = RTW.HDLTimingInterface
RTW.SubsystemInterface
RTW.DataInterface
RTW.ClockInterface
RTW.TimingInterface
RTW.FunctionInterface
RTW.ComponentInterface
fcndef = RTW.FcnDefault
ht = rtw.pil.HostTimer;

hLib = RTW.TflTable
entry = RTW.TflCOperationEntry
setTflCOperationEntryParameters(entry, 'Key','RTW_OP_MUL', 'Priority',90, 'ImplementationName','matrix_mul_4x4_s')
arg = getTflArgFromString(hLib, 'y2','void')
arg.IOType = 'RTW_IO_OUTPUT'
entry.Implementation.setReturn(arg)
arg = getTflArgFromString(hLib,'y1','single*')
desc = RTW.ArgumentDescriptor
desc.AlignmentBoundary = 16
arg.Descriptor = desc
entry.Implementation.addArgument(arg)
targReg = RTW.TargetRegistry.getInstance

%% MEMORY SECTION DEFINITION - CSCDefn from mpt.csc_registration

% ( and there's much more, it's an auto-generated file)
defs = [];

h = Simulink.MemorySectionDefn;
set(h, 'Name', 'MemConst');
set(h, 'OwnerPackage', 'mpt');
set(h, 'Comment', '/* Const memory section */');
set(h, 'PragmaPerVar', false);
set(h, 'PrePragma', '');
set(h, 'PostPragma', '');
set(h, 'IsConst', true);
set(h, 'IsVolatile', false);
set(h, 'Qualifier', '');
defs = [defs; h];

h = Simulink.MemorySectionDefn;
set(h, 'Name', 'MemVolatile');
set(h, 'OwnerPackage', 'mpt');
set(h, 'Comment', '/* Volatile memory section */');
set(h, 'PragmaPerVar', false);
set(h, 'PrePragma', '');
set(h, 'PostPragma', '');
set(h, 'IsConst', false);
set(h, 'IsVolatile', true);
set(h, 'Qualifier', '');
defs = [defs; h];

h = Simulink.MemorySectionDefn;
set(h, 'Name', 'MemConstVolatile');
set(h, 'OwnerPackage', 'mpt');
set(h, 'Comment', '/* ConstVolatile memory section */');
set(h, 'PragmaPerVar', false);
set(h, 'PrePragma', '');
set(h, 'PostPragma', '');
set(h, 'IsConst', true);
set(h, 'IsVolatile', true);
set(h, 'Qualifier', '');
defs = [defs; h];


%% SIMULINK BUS & DictionaryAccessIntervalNotifier
Simulink.output.Action
Simulink.Bus
f = Simulink.BusElement
f.DataType = 'uint16'
f.SampleTime = now
f.Dimensions = 4
cg = Simulink.CallGraph
src = Simulink.data.DataSource
Simulink.data.packagesWithDataClasses
mptsignal.CoderInfo
tasksetting = mpt.Parameter
mpt.CustomRTWInfoSignal
mptsig = mpt.Signal
mptsig.getPreferredProperties
mptsig.InitialValue
mptsig.LoggingInfo
dicnot = Simulink.data.internal.DictionaryAccessIntervalNotifier

Simulink.data.DataDictionary()
% unknown

sc = Simulink.AsyncQueue.SignalClient

Simulink.MemorySectionDefn
ans.convert2struct


% coder.descriptor.DataInterfaceContainer
% coder.descriptor.BlockHierarchyMap
% coder.descriptor.DataStore
% coder.descriptor.Port
% coder.descriptor.GraphicalSystem
% coder.descriptor.ExternalInputs
% coder.descriptor.ToAsyncQueueBlock
% coder.descriptor.Region
% coder.descriptor.State
% coder.descriptor.Integer
% coder.descriptor.DataInterfaceContainer
% coder.descriptor.BlockHierarchyMap
% coder.descriptor.DataStore
% coder.descriptor.Port
% coder.descriptor.GraphicalSystem
% coder.descriptor.ExternalInputs
% coder.descriptor.StateList
% coder.descriptor.System
% coder.descriptor.ToAsyncQueueBlock
% coder.descriptor.Region
% coder.algorithm
% coder.ArrayType
% coder.Constant
% coder.IOInterface
% coder.StructType
% coder.mixin.internal.indexing.ParenAssign
% coder.ismatlabthread
% coder.TokenMap
% coder.Token
% coder.wref
% coder.varsize
% coder.Transform
% coder.target
% coder.PrimitiveType
coder.Type
coder.typeof
coder.storageClass
coder.nullcopy
coder.IOInterface % -> Name,   -> Target


%% WORKABLE RTIO-STREAM USING RTIOSTREAM_WRAPPER libmwrtiostreamtcpip
SHARED_LIB = 'libmwrtiostreamtcpip.dll';
port_number = '2345';
stationA = rtiostream_wrapper('libmwrtiostreamtcpip.dll','open',...
	'-client', '0',...
	'-blocking', '0',...
	'-port', port_number);


stationB = rtiostream_wrapper('libmwrtiostreamtcpip.dll','open',...
	'-client','1',...
	'-blocking', '0',...
	'-port', port_number,...
	'-hostname','localhost');

%STATION_ID = rtiostream_wrapper(SHARED_LIB,'open');
%RES = rtiostream_wrapper(SHARED_LIB,'close',STATION_ID);

DATA = distcompserialize64('mark is a dumbass')
SIZE = numel(DATA);
[RES,SIZE_SENT] = rtiostream_wrapper(SHARED_LIB,'send',stationA, DATA, SIZE)
[RES, DATA_RECVD, SIZE_RECVD] = rtiostream_wrapper(SHARED_LIB,'recv',stationB, SIZE);
MSG = distcompdeserialize(DATA_RECVD);
RES = rtiostream_wrapper(SHARED_LIB, 'close', stationA);
RES = rtiostream_wrapper(SHARED_LIB, 'close', stationB);


%GDATA = parallel.internal.pool.serialize(DATA);



% stationA = rtiostream_wrapper('libmwrtiostreamserial.dll','open',...
%                               '-port','COM1',...
%                               '-baud','9600');



% sharedLibExt=system_dependent('GetSharedLibExt');
% rtiostreamLib = ['rtiostreamtcpip' sharedLibExt];
% launcher = rtw.connectivity.Launcher;
% componentArgs = coder.connectivity.ComponentArgs;
% comm = rtw.connectivity.RtIOStreamHostCommunicator;
rtiostreamtest('tcp', 'localhost', '2345')
rtiostreamtest('serial', 'COM1', 9600)



coder.types
coder.types.Aggregate

%% GRAPHICS TEXTURE & HG2 ANIMATORS
tex = matlab.graphics.primitive.world.Texture
hg2.ExampleStackManager
canvas = matlab.graphics.primitive.web.HTMLCanvas
hg2.CubicBezier
hg2.LineAnimator
hg2.PointAnimator
hg2.SegmentedAnimator
hg2.ScopeAnimator

%% GRAPHICS PRIMITIVES -> HGUTILS
matlab.graphics.primitive.world.ColorData
matlab.graphics.internal.NullCanvas
matlab.graphics.primitive.canvas.Canvas
matlab.graphics.primitive.canvas.CanvasFactory
hg2gcv
hgcastvalue
hgfilter
matlab.graphics.internal.drawnow.getRate
matlab.graphics.internal.drawnow.startUpdate
matlab.graphics.internal.drawnow.isReady
matlab.graphics.internal.drawnow.callback

hgutils
matlab.graphics.Graphics
matlab.graphics.internal.ReferenceObject

hg2utils.HGCopyableCI
matlab.graphics.GraphicsDisplay
matlab.graphics.internal.GraphicsCoreProperties
matlab.graphics.internal.GraphicsBaseFunctions


matlab.ui.internal.mixin.KeyInvokable
matlab.ui.internal.mixin.Positionable
matlab.ui.container.CanvasContainer
matlab.ui.control.WebComponent

matlab.io.datastore.internal.filesys.BinaryStream
bs = getByteStreamFromArray(f);
capturescreen
findobjinternal


coder.tokenizer.Code2HTML
coder.trace.TokenLocation
coder.trace.TraceInfo

matlab.internal.container.graph.Graph
matlab.internal.container.graph.Edge
matlab.internal.container.graph.Vertex
mlgraph = matlab.internal.graph.MLGraph
mldgraph = matlab.internal.graph.MLDigraph

% R2016B
matlab.internal.graph.MLGraph
matlab.internal.graph.MLDigraph
matlab.internal.container.graph.Graph
matlab.internal.container.graph.Edge
matlab.internal.container.graph.Vertex
matlab.internal.container.graph.DFSVisitor
matlab.internal.container.graph.TransitiveClosure



%% GET EVERY SINGLE GPU FUNCTION IN PACKAGE
gpuFcns = parallel.internal.types.getRowVectorOfGpuarrayMethods

%% MATLAB.INTERNAL.* -> EDITOR
matlab.internal.editor.BaseEvalWorkspace
matlab.internal.editor.CodeGenerator
matlab.internal.editor.SyntheticMouseEvent
matlab.internal.editor.SyntheticMouseWheelEvent
matlab.internal.editor.VariableAnalyzer
% TIMEIT
matlab.internal.timeit.functionHandleCallOverhead()
matlab.internal.timeit.tictocCallTime()
% VALIDATORS
matlab.internal.validators.
attributes
generateArgumentDescriptor
generateId
getArgumentDescriptor

matlab.internal.getcode.
mlxfile
mfile
mlappfile

mshow('Simulink.scopes')
mshow('matlab.internal.container')
%mshow('internal.Callback')
mshow('internal')


matlab.internal.getCode
matlab.internal.getOpenPort



%% MATLAB.INTERNAL.LANGUAGE.*
import matlab.internal.language.*
isPartialMATArrayAccessEfficient
partialLoad
		partialSave
		findFullMATFilename
		callOrdinaryFunction
		castToBuiltinSuperclass
		structuredeval

%% MATLAB.INTERNAL.LANGUAGE.INTROSPECTIVE.*
matlab.internal.language.introspective.classInformation.abstractMethod
matlab.internal.language.introspective.classInformation.base
matlab.internal.language.introspective.classInformation.classElement
matlab.internal.language.introspective.classInformation.classItem
matlab.internal.language.introspective.classInformation.constructor
matlab.internal.language.introspective.classInformation.fileConstructor
matlab.internal.language.introspective.classInformation.fileMethod
matlab.internal.language.introspective.classInformation.fullConstructor
matlab.internal.language.introspective.classInformation.localConstructor
matlab.internal.language.introspective.classInformation.localMethod
matlab.internal.language.introspective.classInformation.method
matlab.internal.language.introspective.classInformation.package
matlab.internal.language.introspective.classInformation.packagedFunction
matlab.internal.language.introspective.classInformation.packagedItem
matlab.internal.language.introspective.classInformation.packagedUnknown
matlab.internal.language.introspective.classInformation.simpleElement
matlab.internal.language.introspective.classInformation.simpleMCOSConstructor
matlab.internal.language.introspective.classInformation.simpleMCOSElement
matlab.internal.language.introspective.FileContext
matlab.internal.language.introspective.MCOSMetaResolver
matlab.internal.language.introspective.atomicHelpPart
matlab.internal.language.introspective.helpParts
matlab.internal.language.introspective.NameResolver
import matlab.internal.language.introspective.*
separateImplicitDirs
fixLocalFunctionCase
resolveName
isOperator
casedStrCmp
safeWhich
callHelpFunction
errorDocCallback
extractCaseCorrectedName
extractFile
extractHelpText
fixFileNameCase
getAlternateHelpFunction
getDocTopic
getHelpFunction
getMethod
getPackageName
getSimpleElement
getSimpleElementTypes
hashedDirInfo
isAccessible
isClassMFile
isObjectDirectorySpecified
makePackagedName
minimizePath
removeDotsFromFilePath
showAddon
splitOverqualification


%% INTERNAL
internal.Callback
	internal.BannerMessage
	internal.ColorConversion
	internal.ContextMenus
	internal.TimeoutTimer
	internal.ToolTip
	internal.polariAngleMarker
	internal.polariAngleSpan
	internal.polariAntenna
	internal.polariCommon
	internal.polariEvent
	internal.polariMBAngleMarker
	internal.polariMBAngleSpan
	internal.polariMBAngleTicks
	internal.polariMBAntennaReadout
	internal.polariMBDataset
	internal.polariMBGeneral
	internal.polariMBGrid
	internal.polariMBLegend
	internal.polariMBMagTicks
	internal.polariMBNone
	internal.polariMBPeaksTable
	internal.polariMBSpanReadout
	internal.polariMBTitle
	internal.polariMouseBehavior
	internal.polariPeaksTable
	internal.polariReadout
	internal.polari
	internal.DispTable
	internal.DisplayFormatter
	internal.IntervalTimer
	internal.SetGetRenderer
	internal.TimerInfo
	internal.Utility

import internal.*
	findSubClasses
	setJavaCustomData
	LogicalToOnOff
	measureLobes
	antfindpeaks
	Contents
	getJavaCustomData
	CoachingTips
	enablePolariInitBannerMessage
	findpeaks2d
	manager
	DispTableExample


import internal.stats.parallel.*
collectShape
			distributeToPool
			extractParallelAndStreamFields
			freshSubstream
			getParallelPoolSize
			iscompatibleRNGscheme
			muteParallelStore
			pickLarger
			pickSmaller
			prepareStream
			processParallelAndStreamOptions
			processReductionVariableArgument
			reconcileStreamsAfterLoop
			retrieveFromPool
			smartFor
			smartForReduce
			smartForSliceout
			statParallelStore
			unpackRNGscheme
			workerGetValue
			workerUpdateValue
			
			internal.cxxfe.util.getMexCompilerInfo()
			
			
			nc = internal.matlab.imagesci.nc
			
			
			
			internal.matlab.workspace.peer.
			internal.matlab.workspace.MLWorkspaceDataModel
			
			internal.matlab.desktop.preferences.JavaScriptSettings
			internal.matlab.desktop.richeditor
			
			