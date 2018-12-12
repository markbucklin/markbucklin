usbman = internal.deviceplugindetection.Manager.getInstance();


tg = slrt;
getPCIInfo(tg, 'installed');


chan = asyncio.Channel;
stin = asyncio.InputStream;
stout = asyncio.OutputStream;


unlicfcn = matlab.internal.language.registry.findUnlicensedFunctions;

help matlab.internal.language.structuredeval

lhi = helpUtils.createMatlabLink('hi');
butt = helpUtils.createMatlabCommandWithTitle('disp(''butt'')');

help helpUtils.makeDualCommand

port = connector.securePort;
wserv = connector.internal.webserver
webeng = connector.internal.engine
webconf = connector.internal.buildStartupConfig('www.bu.edu')

ulfcnreg = com.mathworks.mlwidgets.help.functionregistry.UnlicensedFunctionRegistry('_gpu_getMetadata');
ulfc = ulfcnreg.getClass;
sfcn = get(ulfc);



getProdList = @() com.mathworks.install.InstalledProductFactory.getInstalledProducts(matlabroot);
getProdArray = @() toArray(getProdList());
prod = getProdArray();
prodinfo = arrayfun(@get, prod);

getProdInfo = @(name) com.mathworks.product.util.ProductIdentifier.get(name)




[attrNames, methodsData] = methodsview('com.mathworks.product.util.ProductIdentifier', 'libfunctionsview')
[attrNames, methodsData] = methodsview('com.mathworks.product.util.ProductIdentifier', 'noUI')