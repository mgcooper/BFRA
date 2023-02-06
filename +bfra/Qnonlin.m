function [Q,dQdt,t,hFig] = Qnonlin(a,b,Q0,t,varargin)
%QNONLIN plots the theoretical discharge predicted by a/b values
% 
% 
% 
% 
% See also taufunc, getfunction, QtauString, QtString
% 
% Matt Cooper, 04-Nov-2022, https://github.com/mgcooper

% if called with no input, open this file
if nargin == 0; open(mfilename('fullpath')); return; end


% the loop is ugly but it's the easiest way to allow any size a,b,Q0.
% if I wanted to restrict two of the three a,b,Q0 to be scalar and let
% a third be a vector, I could check that the vector valued quantity
% and t have the right orientation for matrix multiplication

plotFig = false;
hFig    = [];
if nargin==5
   plotFig = varargin{1};
end

% This lets a scalar t or a vector t to be passed in. In both cases t is
% time elapsed since t=0, so to recover Q0 and dqdt0 we set t(1) = 0
if numel(t) ~= 1 && t(1) ~= 0
   t   = [0;t(:)];
end

numA    = numel(a);
numB    = numel(b);
numQ    = numel(Q0);
numT    = numel(t);

Q       = nan(numA,numB,numQ,numT);
dQdt    = nan(numA,numB,numQ,numT);

f       = @(a,b,Q0,t) (Q0^(1-b)+a*(b-1).*t).^(1/(1-b));

for n = 1:numA
   for m = 1:numB
      for p = 1:numQ
         
         qtmp            = f(a(n),b(m),Q0(p),t);
         Q(n,m,p,:)      = qtmp;
         dQdt(n,m,p,:)   = -a(n).*qtmp.^b(m);
         
      end
   end
end

Q       = squeeze(Q);
dQdt    = squeeze(dQdt);

% only plot the first one for now, if I am getting an ensemble of Q(t)
% I can add functionality later to plot some number of them
if plotFig
   
   % get the characterisitc timescale
   tc  = bfra.characteristicTime(a(1),b(1),Q0(1));
   
   % get formatted strings for the legend
   showAB  = false;
   Qtstr   = bfra.getstring('Q(t)');
%    Qtstr   = bfra.QtString([a,b],Q0,showAB);
%    tcstr   = bfra.tcString(a,b,Q0,showAB);
   
   % make a figure
   tileFigure();
   
   plot(t,Q);
   xlabel('$t \quad [T]$');
   ylabel('$Q(t) \quad [L/T]$');
   legend(Qtstr,'Interpreter','latex');
   axis tight
   
   
   nexttile
   plot(t./tc,Q./Q0); % hold on; plot(t./tc,Q./Q0);
   xlabel('$t/t_c \quad [-]$','Interpreter','latex');
   ylabel('$Q/Q_0 \quad [-]$','Interpreter','latex');
   % legend(tcstr)
   
   axis tight
   ylim([0 1])
   
   % fix the axes if they got misaligned
   %hFig1.backgroundAxis.Position = hFig1.mainAxis.Position;
   %hFig2.backgroundAxis.Position = hFig2.mainAxis.Position;
end

% % NOTE: with the tc value, we can compute the Q(t) like this:
  % Qfunc = @(tc,b,Q0) (Q0.*(1+(exp(b-1)-1).*t./tc).^(1/(1-b)));

% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% % notes from trying to figure out how to handle Q0:

% % not sure what is best. If I do t-t(1), 
    
% % this assumes that t(1) = t0, so Q(t) = Q(t-t0)
%     t = t-t(1);
      
% % this appends a zero ahead of t(1) if t doesn't already start at zero
%     if t(1) ~= 0
%         t   = [0;t(:)];
%     end


%     % append Q0 and t0 to the output
%     dqdt0   = 
%     q       = cat(3,q,Q0);
%     t       = cat(1,0,t);
    
    
%     flin    = @(a,Q0,t) Q0.*exp(-t.*a);
%     out.Qlin    = fnlin(a,Q0,t);
%     out.dQlin   = a.*Qnlin;

