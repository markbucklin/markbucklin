function showError(me)


  

fprintf(['\n\n\nERROR:\n',...
  '\tidentifier: %s\n',...
  '\tmessage:    %s\n',...
  '\n'], me.identifier, me.message)



for k = 1:numel(me.stack)
  ln = me.stack(k).line;
  fn = me.stack(k).file;
  fprintf('STACK(%i): %s\n\tline: %i \t %s\n',...
    k,me.stack(k).name, ln, fn);
  fprintf('\nContext:\n-------------------------------')
  dbtype(fn, sprintf('%i:%i',max(1,ln-10),ln-1))
  fprintf('**')
  dbtype(fn, sprintf('%i:%i',ln,ln))
  fprintf('**')
  dbtype(fn, sprintf('%i:%i',ln+1,ln+5))
  fprintf('\n')
end
