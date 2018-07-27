function transitions=computeTransitions(sleepstages)

REMToWake=find(sleepstages==3 & [0; sleepstages(1:end-1)]==2);
WakeToREM=find(sleepstages==2 & [0; sleepstages(1:end-1)]==3);
WakeToNREM=find(sleepstages==1 & [0; sleepstages(1:end-1)]==3);
NREMToWake=find(sleepstages==3 & [0; sleepstages(1:end-1)]==1);
NREMToREM=find(sleepstages==2 & [0; sleepstages(1:end-1)]==1);
REMToNREM=find(sleepstages==1 & [0; sleepstages(1:end-1)]==2);

transitions=diff([0 sleepstages(sleepstages>0)' 0]);
nbTransition=length(transitions(transitions~=0));
matTransitions=[0 length(WakeToREM) length(WakeToNREM);
    length(REMToWake) 0 length(REMToNREM);
    length(NREMToWake) length(NREMToREM) 0];
names = {'WAKE' 'REM' 'NREM'};
fig1=figure();
ax=axes();
G=digraph(matTransitions',names,'OmitSelfLoops');
G.Edges.LWidths = 7*G.Edges.Weight/max(G.Edges.Weight);
axes(ax);
p=plot(G,'Layout','circle','EdgeLabel',G.Edges.Weight);
p.LineWidth = G.Edges.LWidths;
highlight(p,[1],'NodeColor','r','MarkerSize',25)
highlight(p,[2],'NodeColor','b','MarkerSize',25)
highlight(p,[3],'NodeColor','g','MarkerSize',25)
