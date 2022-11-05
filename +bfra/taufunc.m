function [taufunc,tau] = taufunc(a,b,Q)
%TAUFUNC returns inline function for tau or the value of tau

% first get tau function
taufunc = @(a,b,Q) 1./a.*Q.^(1-b);
if nargin == 0
   tau = taufunc;
elseif nargin == 3
   tau = taufunc(a,b,Q);
else
   error('either zero or three inputs required');
end
    