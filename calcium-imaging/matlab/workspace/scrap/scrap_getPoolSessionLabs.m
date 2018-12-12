pool = gcp;
session = pool.hGetSession();
ss = get(session);
dispatcher = session.getDispatcher();
labs = session.getLabs;
lab = labs.getLabInstances();
labarray = lab.toArray();