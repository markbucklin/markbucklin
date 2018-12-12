function dirName = establishDir( dirEnvVar, prompt)

if nargin<2, prompt = sprintf('Select %s',dirEnvVar); end


persistent lastDir
if isempty(lastDir), lastDir = pwd; end

dirName = getenv(dirEnvVar);
if isempty(dirName)
    dirName = uigetdir(lastDir, prompt);
    setenv( dirEnvVar, dirName)
end

if ~isfolder(dirName)
  mkdir(dirName); 
end