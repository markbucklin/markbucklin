matlab.desktop.editor.getActiveFilename
allDocs = matlab.desktop.editor.getAll
docmeta = metaclass( allDocs)
strvcat(docmeta.PropertyList.Name)
methodsview(allDocs(2).JavaEditor)

% allDocs(2).JavaEditor.replaceText


