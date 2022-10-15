function [tf,istart,iend]  = isminlength(tf,nmin)
    rl      = runlength(tf);                % get run lengths
    tf      = rl>=nmin;                     % find run lengths >= min length
    istart  = find(diff([false;tf])==1);    % start index of useable events
    iend    = find(diff([tf;false])==-1);   % end index of useable events
end