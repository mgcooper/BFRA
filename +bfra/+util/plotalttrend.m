function h = plotalttrend(t,Db,sigDb,varargin)
   %PLOTALTTREND plot the active layer thickness trend
   %
   % Syntax
   %
   %     h = plotalttrend(t,Db,sigDb,varargin)
   %
   % Description
   %
   %     h = plotalttrend(t,Db,sigDb) plots annual values of active layer
   %     thickness from baseflow recession analysis Db with errorbars
   %     representing estimation uncertainty sigDb and the linear trendline.
   %
   %     h = plotalttrend(t,Db,sigDb,Dc,sigDc) also plots annual values of
   %     measured active layer thickness Dc and measurement uncertainty sigDc.
   %
   % See also prepalttrend


   %-------------- if called with no input, open this file
   if nargin == 0; open(mfilename('fullpath')); return; end


   %-------------- parse inputs
   [Dc, Dg, sigDc, method] = parseinputs(Db, mfilename, varargin{:});


   %-------------- call the subfunction
   if all(isnan(Dc)) && all(isnan(Dg))
      h = plotflowperiod(t, Db, sigDb, method);
      
   elseif all(isnan(Dg))
      h = plotcalmperiod(t, Db, sigDb, Dc, sigDc, method);
      
   else
      h = plotgraceperiod(t, Db, sigDb, Dc, sigDc, Dg, method);
   end

end

% --------------- plot grace period
function h = plotgraceperiod(t, Db, sigDb, Dc, sigDc, Dg, method)

   if all(isempty(Dg))
      h = nan;
      return
   end

   ctxt = 'CALM (measured)';
   btxt = 'BFRA (theory: Eq. 21)';
   gtxt = 'GRACE $\\eta=S_G/\\phi$';

   colors = get(0, 'defaultaxescolororder');
   % p1 plot needs 'reference',Dc where Dc is 1990-2020
   % p1 plot needs 'reference',Db where Db is 1990-2020

   f = figure('Units','centimeters','Position',[5 5 23 19*3/4]); 
   ax = gca;
   
   p1 = bfra.trendplot(t,Dc,'units','cm a$^{-1}$','leg',ctxt,'use',ax, ...
      'errorbounds',true,'errorbars',true,'yerr',sigDc,'reference',Dc, ...
      'method',method);
   p2 = bfra.trendplot(t,Db,'units','cm a$^{-1}$','leg',btxt,'use',ax, ...
      'errorbounds',true,'errorbars',true,'yerr',sigDb,'reference',Db, ...
      'method',method);
   p3 = bfra.trendplot(t,Dg,'units','cm a$^{-1}$','leg',gtxt,'use',ax, ...
      'errorbounds',true,'errorbars',true,'method',method);

   set(ax,'XLim',[2001 2021],'YLim',[-80 80],'XTick',2002:3:2020);

   p3.trend.Color = colors(5,:);
   p3.bounds.FaceColor = colors(5,:);
   p3.plot.MarkerFaceColor = colors(5,:);
   p3.plot.Color = colors(5,:);

   p1.trend.LineWidth = 3;
   p2.trend.LineWidth = 3;
   p3.trend.LineWidth = 3;

   ylabel('$ALT$ anomaly (cm)','Interpreter','latex');

   grid off

   lstr = p1.ax.Legend.String;
   str6 = strrep(lstr{1},'CALM (measured) (','');
   str6 = ['2002:2020 ' strrep(str6,')','')];
   str7 = strrep(lstr{2},[btxt ' ('],'');
   str7 = ['2002:2020 ' strrep(str7,')','')];
   str8 = strrep(lstr{3},[sprintf(gtxt) ' ('],'');
   str8 = ['2002:2020 ' strrep(str8,')','')];

   lobj = [p1.plot p2.plot p3.plot p1.trend p2.trend p3.trend];
   ltxt = {ctxt; btxt; strrep(gtxt,'\\','\'); str6; str7; str8};
   legend(lobj,ltxt,'numcolumns',2,'Interpreter','latex','location', ...
      'northwest','AutoUpdate','off');

   p1.bounds.FaceAlpha = 0.15;
   p2.bounds.FaceAlpha = 0.15;
   p3.bounds.FaceAlpha = 0.05;


   uistack(p1.trend,'top')
   uistack(p2.trend,'top')
   uistack(p3.trend,'top')

   h.figure = f;
   h.bfra.trendplot1 = p1;
   h.bfra.trendplot2 = p2;
   h.bfra.trendplot2 = p3;

end

% --------------- plot streamflow period
function h = plotflowperiod(t, Db, sigDb, method)

   if all(isempty(Db))
      h = nan;
      return
   end

   btxt = 'BFRA (theory: Eq. 21)';

   % this plots 1983-2020, no grace, no calm
   % f = figure('Position',[156    45   856   580]);
   f = figure('Units','centimeters','Position',[5 5 23 19*3/4]);
   p = bfra.trendplot(t,Db,'units','cm/yr','leg',btxt,'use',gca, ...
      'errorbounds',true,'errorbars',true,'yerr',sigDb,'method',method);

   % set transparency of the bars
   set([p.plot.Bar, p.plot.Line], 'ColorType', 'truecoloralpha', ...
      'ColorData', [p.plot.Line.ColorData(1:3); 255*0.5])

   lstr = p.ax.Legend.String;
   str1 = strrep(lstr{1},[btxt ' ('],'');
   str1 = strrep(str1,'cm/yr)','cm a$^{-1}$');

   lobj = [p.plot p.trend];
   ltxt = {btxt; str1};
   legend(lobj,ltxt,'location','north','AutoUpdate','off');

   % if I want to set the tick font to latext
   % ax = gca;
   % ax.TickLabelInterpreter
   ylabel('$ALT$ anomaly (cm)','Interpreter','latex');

   p.trend.LineWidth = 2;

   h.figure = f;
   h.bfra.trendplot = p;

   % xlims = xlim; ylims = ylim; box off; grid on;
   % plot([xlims(2) xlims(2)],[ylims(1) ylims(2)],'k','LineWidth',1);
   % plot([xlims(1) xlims(2)],[ylims(2) ylims(2)],'k','LineWidth',1);

end

% --------------- plot calm period
function h = plotcalmperiod(t, Db, sigDb, Dc, sigDc, method)

   if all(isempty(Dc))
      h = nan;
      return
   end

   % ltext = [num2ltext('1990-2020 trend','',abC.Dc(2),'cm a$^{-1}$',2), ...
   %          num2ltext('2002-2020 trend','',abG.Dc(2),'cm a$^{-1}$',2)];

   ctxt = 'CALM (measured)';
   btxt = 'BFRA (theory: Eq. 21)';
   % btxt = 'BFRA $\\eta=\\tau/[\\phi(N+1)]\\bar{Q}$';


   % this plots 1990-2020, no grace
   % f = figure('Position',[156    45   856   580]);
   f = figure('Units','centimeters','Position',[5 5 23 19*3/4]);
   p1 = bfra.trendplot(t,Dc,'units','cm/yr','leg',ctxt,'use',gca, ...
      'errorbounds',true,'errorbars',true,'yerr',sigDc,'method',method);
   p2 = bfra.trendplot(t,Db,'units','cm/yr','leg',btxt,'use',gca, ...
      'errorbounds',true,'errorbars',true,'yerr',sigDb,'method',method);

   % set transparency of the bars
   set([p1.plot.Bar, p1.plot.Line], 'ColorType', 'truecoloralpha', ...
      'ColorData', [p1.plot.Line.ColorData(1:3); 255*0.5])
   set([p2.plot.Bar, p2.plot.Line], 'ColorType', 'truecoloralpha', ...
      'ColorData', [p2.plot.Line.ColorData(1:3); 255*0.5])

   % % set transparance of marker faces
   % set(p1.plot.MarkerHandle, 'FaceColorType', 'truecoloralpha', ...
   %     'FaceColorData', [p1.plot.Line.ColorData(1:3); 255*0.75])
   % set(p2.plot.MarkerHandle, 'FaceColorType', 'truecoloralpha', ...
   %     'FaceColorData', [p2.plot.Line.ColorData(1:3); 255*0.75])

   lstr = p1.ax.Legend.String;
   str1 = strrep(lstr{1},'CALM (measured) (','');
   str1 = strrep(str1,'cm/yr)','cm a$^{-1}$');
   str2 = strrep(lstr{2},[btxt ' ('],'');
   str2 = strrep(str2,'cm/yr)','cm a$^{-1}$');

   lobj = [p1.plot p2.plot p1.trend p2.trend];
   ltxt = {ctxt; btxt; str1; str2};
   legend(lobj,ltxt,'location','north','AutoUpdate','off');

   % if I want to set the tick font to latext
   % ax = gca;
   % ax.TickLabelInterpreter
   ylabel('$ALT$ anomaly (cm)','Interpreter','latex');

   p1.trend.LineWidth = 2;
   p2.trend.LineWidth = 2;

   axis tight
   set(gca,'XLim',[1990 2020],'XTick',1990:5:2020);

   h.figure = f;
   h.bfra.trendplot1 = p1;
   h.bfra.trendplot2 = p2;

   % xlims = xlim; ylims = ylim; box off; grid on;
   % plot([xlims(2) xlims(2)],[ylims(1) ylims(2)],'k','LineWidth',1);
   % plot([xlims(1) xlims(2)],[ylims(2) ylims(2)],'k','LineWidth',1);

   % ff = figformat('legendlocation','north');
   % ff.backgroundAxis.XLim = [1989 2021];
   % ff.backgroundAxis.YLim = [-29 29];
   % ylabel(ff.mainAxis,'$ALT$ anomaly (cm)');

   % plot(x1,D1-mean(D1),'k','LineWidth',0.75,'HandleVisibility','off')
   % plot(x1,D2-mean(D2),'k','LineWidth',0.75,'HandleVisibility','off')
   % plot(x1,D1-mean(D1),'Color',dc(1,:),'LineWidth',0.75,'HandleVisibility','off')
   % plot(x1,D2-mean(D2),'Color',dc(2,:),'LineWidth',0.75,'HandleVisibility','off')
end

% --------------- parse inputs
function [Dc, Dg, sigDc, method] = parseinputs(Db, mfilename, varargin);

   parser = inputParser;
   parser.FunctionName = mfilename;
   parser.addOptional('Dc', nan(size(Db)), @(x)isnumeric(x));
   parser.addOptional('sigDc', nan(size(Db)), @(x)isnumeric(x));
   parser.addOptional('Dg', nan(size(Db)), @(x)isnumeric(x));
   parser.addParameter('method', 'ols', @(x) ischar(x));
   parser.parse(varargin{:});

   Dc = parser.Results.Dc;
   Dg = parser.Results.Dg;
   sigDc = parser.Results.sigDc;
   method = parser.Results.method;

   % % experimental demonstration of createParser syntax
   % p = createParser( ...
   %    mfilename, ...
   %    'OptionalArguments',    {'Dc','sigDc','Dg'}, ...
   %    'OptionalDefaults',     {nan(size(Db)), nan(size(Db)), nan(size(Db))}, ...
   %    'OptionalValidations',  {@(x)isnumeric(x), @(x)isnumeric(x), @(x)isnumeric(x)}, ...
   %    'ParameterArguments',   {'ax', 'method'}, ...
   %    'ParameterDefaults',    {gca, 'ols'}, ...
   %    'ParameterValidations', {@(x) bfra.validation.isaxis(x), @(x) ischar(x)} ...
   %    );
   % p.parseMagically('caller');

end
