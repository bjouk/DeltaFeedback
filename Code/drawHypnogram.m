function drawHypnogram(lines,ax,patches,X,Y)
%Lines => plot lines
%Ax=> Axes to plot on
%patches => Patches to plot (color on the hypnogram)
%X=> timestamps
%Y=> values
X=X';
Y=Y';
vnan = NaN(size(X)) ;
xp = reshape([X;vnan;X],1,[]); xp([1:2 end]) = [] ;
yp = reshape([Y;Y;vnan],1,[]); yp(end-2:end) = [] ;

% prepare the vertical lines, same method but we interleave the NaN at one
% element offset
xv = reshape([X;X;vnan],1,[]); xv([1:3 end]) = [] ;
yv = reshape([Y;vnan;Y],1,[]); yv([1:2 end-1:end]) = [] ;

% prepare colormap and color matrix (same method than above)
[uy,~,colidx] = unique(Y) ;     
ncolor = length(uy) ;           % Number of unique level

          % assign a colormap with this number of color

% create the color matrix wich will be sent to the patch object
% same method of interleaving than for the X and Y coordinates
cd = reshape([colidx.';colidx.';vnan],1,[]); cd(end-2:end) = [] ;
% draw the patch (without vertical lines)


% add the vertical dotted lines
map=[0 0.7 0;0 0 0.7;0.5 0 0];
colormap(ax,map);
try
    set(patches,'XData',xp,'YData',yp,'CData',cd,'LineWidth',2);
    %patches=patch(ax,xp,yp,cd,'EdgeColor','flat',);
catch
end
set(lines,'XData',xv,'YData',yv,'Color','k','LineStyle',':');

% add a label centered colorbar