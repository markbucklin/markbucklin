

pool = gcp;
sess = pool.hGetSession();
labs = pool.hGetSession().getLabs();
lablist = labs.getLabInstances();


lit = lablist.listIterator();
while lit.hasNext()
	k = lit.nextIndex() + 1; 
	procinst = lit.next();
	labInst{k} = procinst;
end
