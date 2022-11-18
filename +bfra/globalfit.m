function GlobalFit = globalfit(K,Events,Fits,varargin)
%GLOBALFIT takes the event-scale recession analysis parameters saved in
%data table K and the event-scale data saved in Events and Fits and computes
%'global' parameters tau, tau0, phi, bhat, ahat, Qexp, and Q0
%
% Syntax:
%
%  FIT = bfra.GLOBALFIT(K,Events,Fits);
%  FIT = bfra.GLOBALFIT(K,Events,Fits,opts);
%  FIT = bfra.GLOBALFIT(K,Events,Fits,Meta,'plotfits',plotfits);
%  FIT = bfra.GLOBALFIT(K,Events,Fits,Meta,'bootfit',bootfit);
%  FIT = bfra.GLOBALFIT(K,Events,Fits,Meta,'bootfit',bootfit,'nreps',nreps);
%  FIT = bfra.GLOBALFIT(___,)
%
% Author: Matt Cooper, 22-Oct-2022, https://github.com/mgcooper

% Required inputs:
%  K, Events, Fits - output of bfra.getevents and bfra.dqdt
%  opts - struct containing fields area, D0, and L (see below)
%  AnnualFlow - timetable or table of annual flow containing field Qcmd which
%  is the average daily flow (units cm/day) posted annually.
%  TODO: make the inputs more general, rather than these hard-coded structures
%  and tables
%
% See also setopts

% NOTE: in the current setup, early/lateqtls are used for eventphi, refqtls for
% point cloud 

%-------------------------------------------------------------------------------
% input parsing
%-------------------------------------------------------------------------------
p                 = inputParser;
p.FunctionName    = 'bfra.globalfit';
p.StructExpand    = true;
% p.PartialMatching = true;

addRequired(p,    'K',                             @(x)isstruct(x)               );
addRequired(p,    'Events',                        @(x)isstruct(x)               );
addRequired(p,    'Fits',                          @(x)isstruct(x)               );
addParameter(p,   'drainagearea',   nan,           @(x)isnumericscalar(x)        );
addParameter(p,   'drainagedens',   nan,           @(x)isnumericscalar(x)        );
addParameter(p,   'aquiferdepth',   nan,           @(x)isnumericscalar(x)        );
addParameter(p,   'streamlength',   nan,           @(x)isnumericscalar(x)        );
addParameter(p,   'aquiferslope',   nan,           @(x)isnumericscalar(x)        );
addParameter(p,   'aquiferbreadth', nan,           @(x)isnumericscalar(x)        );
addParameter(p,   'isflat',         true,          @(x)islogicalscalar(x)        );
addParameter(p,   'plotfits',       false,         @(x)islogicalscalar(x)        );
addParameter(p,   'bootfit',        false,         @(x)islogicalscalar(x)        );
addParameter(p,   'nreps',          1000,          @(x)isdoublescalar(x)         );
addParameter(p,   'phimethod',      'pointcloud',  @(x)ischar(x)                 );
addParameter(p,   'refqtls',        [0.50 0.50],   @(x)isnumericvector(x)        );
addParameter(p,   'earlyqtls',      [0.90 0.90],   @(x)isnumericvector(x)        );
addParameter(p,   'lateqtls',       [0.50 0.50],   @(x)isnumericvector(x)        );


parse(p,K,Events,Fits,varargin{:});

A           = p.Results.drainagearea;     % basin area [m2]
Dd          = p.Results.drainagedens;     % drainage density [km-1]
D           = p.Results.aquiferdepth;     % reference active layer thickness [m]
L           = p.Results.streamlength;     % effective stream network length [m]
theta       = p.Results.aquiferslope;
B           = p.Results.aquiferbreadth;
plotfits    = p.Results.plotfits;
bootfit     = p.Results.bootfit;
nreps       = p.Results.nreps;
phimethod   = p.Results.phimethod;
refqtls     = p.Results.refqtls;
earlyqtls   = p.Results.earlyqtls;
lateqtls    = p.Results.lateqtls;

% if stream lenght and drainage density are both provided, check that they are
% consistent with the provided area. note: Dd comes in as 1/km b/c that's how it
% is almost always reported (km/km2). divide by 1000 to get 1/m.
if ~isnan(Dd) && ~isnan(L)
   if Dd/1000*A ~= L        % 1/m * m^2 = m
      warning('provided streamlength, L, inconsistent with L=A*Dd. Using L=A*Dd');
      L = Dd/1000*A;
   end
end
%-------------------------------------------------------------------------------

% take values out of the data structures that are needed
Q  = Events.Q;       % daily streamflow [m3 d-1]

% fit tau, a, b (tau [days], q [m3 d-1], dqdt [m3 d-2])
%---------------
[tau,q,dqdt,tags] = bfra.eventtau(K,Events,Fits,'usefits',false);
TauFit = bfra.plfitb(tau,'plotfit',plotfits,'bootfit',bootfit,'nreps',nreps);

% [TestFit,testb] = bfra.gpfitb(GlobalFit.x,'xmin',GlobalFit.tau0,'bootfit',true);

% parameters needed for next steps
%---------------------------------
bhat     = TauFit.b;
bhatL    = TauFit.b_L;
bhatH    = TauFit.b_H;
tau0     = TauFit.tau0;
tauexp   = TauFit.tau;
itau     = TauFit.taumask;

% fit a
% -------
[ahat,ahatLH,xbar,ybar] =  bfra.pointcloudintercept(q,dqdt,bhat,'envelope',  ...
                           'refqtls',refqtls,'mask',itau,'bci',[bhatL bhatH]);

% fit Q0 and Qhat
%-----------------
[Qexp,Q0,pQexp,pQ0] = bfra.expectedQ(ahat,bhat,tauexp,q,dqdt,tau0,'qtls',Q,'mask',itau);

% fit phi
%---------
switch phimethod
   case 'distfit'
      phid = bfra.eventphi(K,Fits,A,D,L,bhat,'lateqtls',lateqtls, ...
         'earlyqtls',earlyqtls);
      phi = bfra.fitphidist(phid,'mean','cdf',plotfits);
      
   case 'pointcloud'
      phi = bfra.cloudphi(q,dqdt,bhat,A,D,L,'envelope','lateqtls',refqtls, ...
         'earlyqtls',earlyqtls,'mask',itau);
      
   case 'phicombo'
      phi1 = bfra.eventphi(K,Fits,A,D,L,1,'lateqtls',lateqtls, ...
         'earlyqtls',earlyqtls);
      phi2 = bfra.eventphi(K,Fits,A,D,L,3/2,'lateqtls',lateqtls, ...
         'earlyqtls',earlyqtls);
      phid = vertcat(phi1,phi2); phid(phid>1) = nan; phid(phid<0) = nan;
      phi = bfra.fitphidist(phid,'mean','cdf',plotfits);
end


% PhiFit = bfra.phifitensemble(K,Fits,A,D,L,bhat,true);

% fit k
%---------
[k,Q0_2,D_2] = bfra.aquiferprops(q,dqdt,ahat,bhat,phi,A,D,L,'RS05', ...
   'mask',itau,'lateqtls',refqtls,'earlyqtls',earlyqtls,'Q0',Q0,'Dd',Dd);


% Q0    = Qexp*(3-b)/(2-b);

% note on units: ahat is estimated from the point cloud. the dimensions of ahat
% are T^b-2 L^1-b. The time is in days and length is m3, so ahat has units
% d^b-2 m^3(1-b) (it's easier if you pretend flow is m d-1). For Q0, we get:
% (d^b-2 m^3(1-b) * d)^(1/1-b) = d^(b-1)/(1-b) m^3(1-b)/(1-b) = m^3 d-1

% plot the pointcloud if requested
%----------------------------------
if plotfits == true

   h = bfra.pointcloudplot(q,dqdt,'blate',1,'mask',itau,    ...
   'reflines',{'early','late','userfit'},'reflabels',true, ...
   'userab',[ahat bhat],'addlegend',true);

   h.legend.AutoUpdate = 'off';
   scatter(xbar,ybar,60,'k','filled','s');

end



% package up the data and save it
GlobalFit      = TauFit;
GlobalFit.phi  = phi;
GlobalFit.q    = q;
GlobalFit.dqdt = dqdt;
GlobalFit.tags = tags;
GlobalFit.a    = ahat;
GlobalFit.a_L  = ahatLH(1);
GlobalFit.a_H  = ahatLH(2);
GlobalFit.xbar = xbar;
GlobalFit.ybar = ybar;
GlobalFit.Q0   = Q0;
GlobalFit.Qexp = Qexp;
GlobalFit.pQexp = pQexp;
GlobalFit.pQ0  = pQ0;

