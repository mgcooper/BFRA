% function ETS = fitets(T,Q,R,varargin)
function [q,dqdt,dt,tq,rq,dq] = fitets(T,Q,R,varargin) 
%FITETS fits recession event using the exponential timestep method
%
%  Syntax
%     ETS = bfra.fitets(T,Q,R,derivmethod)
%     ETS = bfra.fitets(_,'etsparam',fitwindow)
%     ETS = bfra.fitets(_,'fitab',fitmethod)
%     ETS = bfra.fitets(_,'plotfit',pickmethod)
%     ETS = bfra.fitets(_,'ax',axis_object)
% 
%  Required inputs
%     T     =  time (days)
%     Q     =  discharge (L T^-1, assumed to be m d-1 or m^3 d-1)
%     R     =  rainfall (L T^-1, assumed to be mm d-1)
% 
%  Optional name-value pairs
% 
%     etsparam = scalar, double, parameter that controls window size
%     fitab    =  logical, scalar, indicates whether to fit a/b in -dQ/dt=aQb
%     plotfit  =  logical, scalar, indicates whether to plot the fit
% 
%  See also fitdqdt, fitvts

% note: only pass in identified recession events (not timeseries of
% flow) because this first fits the ENTIRE recession to estimate 'gamma'
% which is just a in the linear model -dq/dt = aQ. Then gamma is used to
% compute 'm', which is the window size, which changes (gets larger) as
% time proceeds. Then it moves over the flow data in windows of size m
% and finds the local linear slope (in linear space, not log-log) which
% is an estimate of dq/dt and the average q within the window and those
% two values are used to compute -dq/dt = aQ^b.

%-------------------------------------------------------------------------------
p              = inputParser;
p.FunctionName = 'fitets';

addRequired(p, 'T',                 @(x)isnumeric(x)|isdatetime(x));
addRequired(p, 'Q',                 @(x)isnumeric(x));
addRequired(p, 'R',                 @(x)isnumeric(x));
addParameter(p,'etsparam', 0.2,     @(x)isnumeric(x)); % default=recommended 20%
addParameter(p,'fitab',    false,   @(x)islogical(x));
addParameter(p,'plotfit',  false,   @(x)islogical(x));

parse(p,T,Q,R,varargin{:});

etsparam = p.Results.etsparam;
fitab    = p.Results.fitab;
plotfit  = p.Results.plotfit;
%-------------------------------------------------------------------------------

   % call the fitting algorithm
   [q,dqdt,dt,tq,rq,dq] = fitdQdt(T,Q,R,etsparam);
   
%    % interpolate to the original timestep. See notes at bottom.
%    ETS = retimeETS(T,Q,R,q,dqdt,dt,tq,rq,rsq);
%    
%    % fit a/b if requested. note, ETS comes back as a struct with
%    % the ETS timetable from retimeETS as a field
%    ETS = fitETSab(ETS,fitab);
%    
%    plotSmoothing(T,Q,plotfit);
   
end



%-------------------------------------------------------------------------------
%  FIT DQDT
%-------------------------------------------------------------------------------


function [q,dqdt,dt,tq,rq,dq,r2] = fitdQdt(T,Q,R,etsparam)
   
   % Fit exponential function on the entire recession event
   T.Format    = 'dd-MMM-uuuu hh:mm';
         T0    = T;
         t     = days(T-T(1)+(T(2)-T(1))); % keep og T
   [xexp,yexp] = prepareCurveData(t, Q./max(Q));
   
   % fit gamma (a in the linear model -dq/dt = aQ)
   b0      = [mean(yexp) 0.2 0];
   opts    = statset('Display','off');
   fnc     = @(b,x)b(1)*exp(-b(2)*x)+b(3);
   try
      abc = nlinfit(xexp,yexp,fnc,b0,opts);
   end
   
   if ~exist('abc','var')
      abc = tryexpfit(xexp,yexp);
   end
   
   gamma = abc(2);    % gamma = b
   
   % gamma checks
   % ------------
   % figure; plot(xexp,yexp,'o',xexp,fnc(abc,xexp),'-');
   % this inequality must be >= 0
   % 1./(gamma.*t) - log(etsparam./(max(t)-1)) 
   % if gamma is between about -0.2 and 0 it blows up
   % gtest = -2:0.0001:-0.2;
   % figure; semilogy(gtest,exp(-1./(gtest.*1)));
   % ------------
   
   nmax  = etsparam*max(t);
   m     = 1+ceil(nmax.*exp(-1./(gamma.*t))); % Eq. 7

   N     = numel(t);   % # of observations
   dqdt  = nan(N,1);
   q     = nan(N,1);
   dt    = nan(N,1);
   tq    = NaT(N,1,'Format','dd-MMM-uuuu HH:mm:ss');
   rq    = nan(N,1);
   r2    = nan(N,1);
   
   % isempty(q) occurs when gamma is very small and m blows up. need to return
   % to this and add a better way to deal with that.
   if all(isempty(q)) || numel(q)<4
      return
   end
   
   % move over the recession in windows of length m and fit dQ/dt
   n = 1;
   while n+m(n)<=N
      x     = t(n:n+m(n));
      X     = [ones(length(x),1) x];
      Y     = Q(n:n+m(n));
      dQdt  = X\Y;                               % eq. 8
      yfit  = X*dQdt;
      r2(n) = 1-sum((Y-yfit).^2)/sum((Y-mean(Y)).^2); r2(r2<0) = 0;
      
      dqdt(n)  = dQdt(2);                 % eq. 9
      q(n)     = nanmean(Y);
      tq(n)    = mean(T0(n:n+m(n)));
      rq(n)    = mean(R(n:n+m(n)));
      dt(n)    = t(n+m(n))-t(n);
      n        = n+1;
   end
   
   inan = dqdt>0 | isnan(r2) | r2<=0;
   dqdt(inan) = NaN;
   
   % retime to the original timestep
   q     = interp1(tq(~isnan(q)),q(~isnan(q)),T);
   dqdt  = interp1(tq(~isnan(dqdt)),dqdt(~isnan(dqdt)),T);
   dq    = dqdt.*dt; % need to check this, right now it isn't used anywhere
   
   % figure; plot(t,q); hold on; plot(tets,qets)
   
   %------------------------------------------------------------------
   % older method that truncated the fit based on parameter m. turns out in some
   % cases this truncates too early for example say q has length 12 and m(9) = 2
   % but m(12) = 3, then on iteration 9, n+m(n) = 11, but N=length(q)-max(m) = 9
   % so the loop would end at 9 when it should go to 10.
   % the # of individual q/dqdt estimates will be less than the q/dqdt
   % values since the step size is increased by the amount m(end)
   %N     = length(t)-m(end);   % new # of events
   
   % i think this would work if we use for 1:N where N is numel(t)-max(m) 
   % tqq   = hours(tq-tq(1)+(tq(2)-tq(1)))./24; % keep og T
   % q     = interp1(tq,q,t,'linear');
   % dqdt  = interp1(tq,dqdt,t,'linear');
end

%-------------------------------------------------------------------------------
%  PLOT SMOOTHING
%-------------------------------------------------------------------------------

function plotSmoothing(T,Q,plotfit)
   
   if plotfit
      % might be worth trying to smooth/gapfill the data here
      Q0    = Q;
      Q     = fillmissing(Q,'spline');
      Q     = smoothdata(Q,'sgolay');
      dQ0   = movingslope(Q0,21,3,T(2)-T(1));
      dQ    = movingslope(Q,21,3,T(2)-T(1));

      figure; 
      subplot(1,2,1); scatter(T,Q0); hold on; plot(T,Q)
      subplot(1,2,2); loglog(Q0,-dQ0); hold on; loglog(Q,-dQ);
   end
   
end

%-------------------------------------------------------------------------------
%  RETIME ETS
%-------------------------------------------------------------------------------


function ETS = retimeETS(T,Q,R,q,dqdt,dt,tq,rq,rsq)
   
   % note: dt = m+1
   
% nov 27, commented this out when added small gamma check in main
%    if all(isnan(q))
%       return
%    end
   
%    if ~isdatetime(T)
%       T  = datetime(T,'ConvertFrom','datenum');
%    end
   
%    q     = q(:);dqdt=dqdt(:);dt=dt(:);tq=tq(:);rq=rq(:);rsq=rsq(:);
%    Time  = datetime(tq,'ConvertFrom','datenum');         % ETS time

   dq    = dqdt.*dt;
   ETS   = timetable(q,dqdt,dq,dt,rq,rsq,'RowTimes',tq);
   
   % might need to add something like this to deal with small gamma all nan
   if all(isnan(q))
      ETS   = retime(ETS,T,'fillwithmissing');
      ETS   = addvars(ETS,T,Q,R);
      return
   end

   % this is needed to get the rain right, will need to revisit for sub-daily
   if T(2)-T(1) == days(1)
      ETS = retime(ETS,'daily','linear');             % retime to daily
      ETS = retime(ETS,T,'fillwithmissing');
   end
   
   if height(ETS) ~= sum(ismember(T,ETS.Time))
      pause;
   end

% % with the second retime above, I may not need to do this
%    % add the original T,Q,R on each day tq
%    iq    = ismember(T,ETS.Time);
%    R     = R(iq);
%    T     = T(iq);
%    Q     = Q(iq);
   
   ETS   = addvars(ETS,T,Q,R);

end

%-------------------------------------------------------------------------------
%  FIT AB
%-------------------------------------------------------------------------------


function ETS = fitETSab(T,fitabOrNot)
   
   % Fit the power law for a and b estimation (Roques et al., 2017)
   a = nan;
   b = nan;
   
   q  = T.q;
   dq = T.dqdt;
   rsq= T.rsq;
   
   if numel(q)>4 % only fit if there are > 4 values
      
      if fitabOrNot == true
         [fitets,~]  = LinRegFitW(log(q),log(-dq),rsq);
            pets     = coeffvalues(fitets);
            b     = pets(1);
            a     = exp(pets(2));
      end
      
      ETS.T    = T;
      ETS.a    = a;
      ETS.b    = b;
      ETS.ets  = true;     % I don't recall what these next two are for
      ETS.cts  = false;
      
   else % don't fit
      ETS = ets_setnan(T);
   end
   
   
end

%-------------------------------------------------------------------------------
%  LINREGFITW
%-------------------------------------------------------------------------------


function [fitted, gof] = LinRegFitW(x, y, weights)
   
   [  xData, ...
      yData, ...
      weights ]   = prepareCurveData( x, y, weights );
   
   % Set up fittype and options.
   ft             = fittype(     'poly1'                         );
   fopts          = fitoptions(  'Method', 'LinearLeastSquares'  );
   fopts.Weights  = weights;
   [fitted,gof]   = fit( xData, yData, ft, fopts );   % Fit model to data.
   
end

%-------------------------------------------------------------------------------
%  SET ETSNAN
%-------------------------------------------------------------------------------


function out = ets_setnan(ETS)
   out.T    = ETS;
   out.a    = nan;
   out.b    = nan;
   out.ets  = nan;
   out.cts  = nan;
end

%-------------------------------------------------------------------------------
%  TRY EXPFIT
%-------------------------------------------------------------------------------


function abc = tryexpfit(xexp,yexp)
   
   % Set up fittype and options.
   ftexp   = fittype(   'a*exp(-b*x)+c' ,                   ...
                        'independent'   , 'x',              ...
                        'dependent'     , 'y'               );
   
   optsexp = fitoptions(   'Method'    , 'NonlinearLeastSquares',  ...
                           'Display'   , 'Off',                    ...
                           'StartPoint', [1e-6 1e-6 1e-6]          );
   
   % Fit model to data.
   fitexp  = fit( xexp, yexp, ftexp, optsexp );
   abc     = coeffvalues(fitexp);
   
end
