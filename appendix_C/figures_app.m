% FIGURES_APP  Figures and tables of Appendix C (sensitivity analyses) of
% "Technological evolution of production networks". INC regime, random targeting.
%
% Columns (one per sensitivity simulation):
%   1 Het. Size        : heterogeneous category sizes           (simHetSize_0_<s>_<k>.mat)
%   2 Het. Homogeneity : heterogeneous homogeneity              (simHetHom_0_<s>_<k>.mat)
%   3 lambda_1 = 0.01  : stronger technological spillovers      (simHighSpill_0_<s>_<k>.mat)
%   4 lambda_0^e = 0.5 : productivity disadvantage of new firms (simDisadv_0_<s>_<k>.mat)
% (s = 0, 1, 2: Scenarios A, B, C; k = run). All simulation files and the initial networks
% i_data_ar.mat, i_data_hetsize.mat and i_data_hethom.mat must be in the current folder.
% The simulations are generated with generateSimulationFiles.m:
%   generateSimulationFiles(k, 0, s, 1, 1,   Inf, 0.004, 50, 0, 1, 1)   % Het. Size
%   generateSimulationFiles(k, 0, s, 1, 1,   Inf, 0.004, 50, 0, 1, 2)   % Het. Homogeneity
%   generateSimulationFiles(k, 0, s, 1, 1,   Inf, 0.01,  50, 0, 1)      % lambda_1 = 0.01
%   generateSimulationFiles(k, 0, s, 1, 0.5, 10,  0.004, 50, 0, 1)      % lambda_0^e = 0.5
%
% Output (numbered as in the paper):
%   graphs/figC1.pdf ... figC9.pdf
%   tables/tab_exits_app.tex (Table C1), tab_corr_app.tex (Table C2),
%   tab_corr_chan_app.tex (Table C3), tab_corr_sup_app.tex (Table C4)

%% ================= SETTINGS =================
clear; clc

% one entry per column
filePat = {'simHetSize_%d_%d_%d.mat','simHetHom_%d_%d_%d.mat','simHighSpill_%d_%d_%d.mat','simDisadv_%d_%d_%d.mat'};
dfile   = {'i_data_hetsize.mat','i_data_hethom.mat','i_data_ar.mat','i_data_ar.mat'};   % initial networks
tnames  = {'Het. Size','Het. Homogeneity','\lambda_1 = 0.01','\lambda_0^e = 0.5, \lambda_0 = 1'};
texG    = {'Het. Size','Het. Homogeneity','$\lambda_1=0.01$','$\lambda_0^e=0.5$, $\lambda_0=1$'};
nSimG   = [100 100 100 100];                        % number of runs per column
nG      = numel(tnames);

index_targeting = 0;                            % random targeting
scen   = 0:2;                                   % index_innovation -> A, B, C (overlaid)
names  = {'A','B','C'};
colors = [0 0.4470 0.7410; 0.8500 0.3250 0.0980; 0.9290 0.6940 0.1250];
set(0,"DefaultLineLineWidth",0.8);
proxVersion = 'before';
wEO    = 10;                                    % smoothing window
Tmax   = 750;
ncp    = 50;                                    % re-categorization interval
none = @(X) X;
ma   = @(X) movmean(X, wEO, 1, 'omitnan');
% ---- figure layout (same as main figures) ----
figW   = 5.4;          % \textwidth in inches
figFS  = 8;            % font size (pt)
figDir = 'graphs';     % figures are exported here as vector PDF
setappdata(0,'figOpts',struct('W',figW,'FS',figFS,'dir',figDir));
if ~exist(figDir,'dir'), mkdir(figDir); end
tabDir = 'tables';     % LaTeX tables are written here
if ~exist(tabDir,'dir'), mkdir(tabDir); end

% initial degree distributions
in0 = cell(1,nG);  out0 = cell(1,nG);
for g = 1:nG
    d = load(dfile{g});  in0{g} = sum(d.A,2);  out0{g} = sum(d.A,1)';
end

%% ================= LOAD =================
for g = 1:nG
for s = 1:numel(scen)
    nS = nSimG(g);
    for k = 1:nS
        f = load(sprintf(filePat{g},index_targeting,scen(s),k), ...
            's_growth','s_logprod','s_logprices','s_indegree','s_outdegree', ...
            'entry_log','s_firm_catlabels');
        nT = min(numel(f.s_growth), Tmax+1);          % states: 1 = initial, t+1 = end of period t
        if k == 1
            R(g,s).nFirms       = zeros(nT,nS);
            R(g,s).nLinks       = zeros(nT,nS);
            R(g,s).meanLogProd  = zeros(nT,nS);
            R(g,s).meanLogPrice = zeros(nT,nS);
            R(g,s).growth       = zeros(nT,nS);
            R(g,s).exits        = zeros(nT-1,nS);
            R(g,s).success      = zeros(nT-1,nS);
            R(g,s).newIn        = nan(nT-1,nS);
            R(g,s).newOut       = nan(nT-1,nS);
            R(g,s).newProd      = nan(nT-1,nS);
            R(g,s).newEss       = nan(nT-1,nS);
            R(g,s).newOpt       = nan(nT-1,nS);
            R(g,s).supProd      = nan(nT-1,nS);   % mean log-prod. of the new firm's suppliers (entry_log row 11)
            R(g,s).essProd      = nan(nT-1,nS);   % mean log-prod. of its essential suppliers (row 12)
            R(g,s).optAvail     = nan(nT-1,nS);   % optional inputs available in the target category (row 13)
            R(g,s).proximity    = nan(nT-1,nS);
            R(g,s).catProd      = nan(nT-1,nS);
        end
        n = cellfun(@numel, f.s_indegree(1:nT));   n = n(:);
        R(g,s).nFirms(:,k) = n;
        tmp = cellfun(@sum,  f.s_indegree(1:nT));   R(g,s).nLinks(:,k)       = tmp(:) ./ n;
        tmp = cellfun(@mean, f.s_logprod(1:nT));    R(g,s).meanLogProd(:,k)  = tmp(:);
        tmp = cellfun(@mean, f.s_logprices(1:nT));  R(g,s).meanLogPrice(:,k) = tmp(:);
        tmp = cell2mat(f.s_growth(1:nT));           R(g,s).growth(:,k)       = tmp(:);

        survived = (f.entry_log(7,1:nT-1) == 1)';
        ex = f.entry_log(5,1:nT-1)';  ex(isnan(ex)) = 0;
        R(g,s).exits(:,k)   = ex;
        % Entry success (1/0). Periods in which no category could be targeted (no entry
        % attempt: entry_log row 2 is NaN) are set to NaN, so they are left out of the
        % denominator of the entry success rate.
        sc = double(f.entry_log(6,1:nT-1) == 1)';
        sc(isnan(f.entry_log(2,1:nT-1))') = NaN;
        R(g,s).success(:,k) = sc;

        for p = find(survived)'                          % new firm = last firm in the network
            inD = f.s_indegree{p+1}(end);
            ess = f.entry_log(10,p);                     % number of essential suppliers
            R(g,s).newIn(p,k)   = inD;
            R(g,s).newOut(p,k)  = f.s_outdegree{p+1}(end);
            R(g,s).newProd(p,k) = f.s_logprod{p+1}(end);
            R(g,s).newEss(p,k)  = ess;
            R(g,s).newOpt(p,k)  = inD - ess;
            % Suppliers of the new firm, measured with the productivities the
            % new firm saw when it chose them (equilibrium of period p-1).
            R(g,s).supProd(p,k)  = f.entry_log(11,p);
            R(g,s).essProd(p,k)  = f.entry_log(12,p);
            R(g,s).optAvail(p,k) = f.entry_log(13,p);
        end
        if strcmp(proxVersion,'before')
            R(g,s).proximity(:,k) = f.entry_log(3,1:nT-1)';
        else
            R(g,s).proximity(:,k) = f.entry_log(4,1:nT-1)';
        end
        % mean log-productivity of the target category before entry (skip re-categorization periods)
        if isfield(f,'s_firm_catlabels')
            for p = 1:nT-1
                if mod(p+1, ncp) == 1, continue; end
                tc = f.entry_log(2,p);
                if ~isnan(tc)
                    lab = f.s_firm_catlabels{p};  lp = f.s_logprod{p};
                    R(g,s).catProd(p,k) = mean(lp(lab == tc));
                end
            end
        end
    end
end
end
hasCatProd = all(arrayfun(@(g) any(~isnan(R(g,1).catProd(:))), 1:nG));
if ~hasCatProd, warning('s_firm_catlabels missing in some files: Table C2, Panel B is skipped.'); end

%% ================= LAST REPORTED PERIOD: 750, truncated only for lambda_1 = 0.01 =================
% With lambda_1 = 0.01, lambda_1*rho(M_t) approaches one and log real value added explodes;
% these simulations are reported up to the last period before the explosion (245).
gThr  = 300;                                         % threshold for log real value added
cutG  = 3;                                          % column(s) to truncate: lambda_1 = 0.01
tEndG = arrayfun(@(g) size(R(g,1).growth,1), 1:nG); % default: all periods (t = 750)
for g = cutG
    bad = false(size(R(g,1).growth,1),1);
    for s = 1:3                                     % first period in which ANY scenario explodes
        G = R(g,s).growth;
        bad = bad | any(~(G >= 0 & G < gThr), 2);     % negative, >= gThr, Inf or NaN
    end
    i = find(bad, 1, 'first');
    if ~isempty(i), tEndG(g) = i - 1; end           % last state before the explosion
end
disp(tEndG - 1)                                     % reported end period per column

%% ================= DEGREES AT tEnd (second pass, pooled over runs) =================
inDeg = cell(nG,3);  outDeg = cell(nG,3);
for g = 1:nG
for s = 1:3
    for k = 1:nSimG(g)
        f = load(sprintf(filePat{g},index_targeting,scen(s),k), 's_indegree','s_outdegree');
        inDeg{g,s}  = [inDeg{g,s};  f.s_indegree{tEndG(g)}(:)];
        outDeg{g,s} = [outDeg{g,s}; f.s_outdegree{tEndG(g)}(:)];
    end
end
end

%% ================= FIGURES (numbered as in Appendix C) =================
% row spec: {field, transform, ylabel, tOff, nonneg, shade}
% shade: +1 = shade where the mean of A is higher than in BOTH B and C,
%        -1 = where it is lower than in both (prices), 0 = none
% Each panel keeps its own axis limits (the simulations differ in level and horizon).

% ---- Figure C1: network density (input links per firm) ----
tsRows('figC1', {'nLinks', none,'Links per firm', 0,false,0}, R,tEndG,colors,names,tnames);

% ---- Figure C2: initial degree distributions (baseline, heterogeneous size, heterogeneous homogeneity) ----
xl    = {'In-degree','Out-degree'};
iCol  = [3 1 2];                                          % column 3 = baseline initial network
iName = {'Baseline','Het. Size','Het. Homogeneity'};
tl = prepFig(2,3);
d0 = {in0, out0};
for r = 1:2
    ax = gobjects(1,3);
    for c = 1:3
        ax(c) = nexttile(tl,(r-1)*3+c);
        [F0,x0] = ecdf(d0{r}{iCol(c)});
        stairs(x0, F0, 'k', 'LineWidth', 1.5);
        xlabel(xl{r})
        if c == 1, ylabel('CDF'); end
        if r == 1, title(iName{c}); end
    end
    syncLim(ax,'XLim');  syncLim(ax,'YLim')               % same axes: differences are comparable
end
finish(tl,'figC2')

% ---- Figure C3: degree distributions at the end of the simulations (A/B/C) ----
tl = prepFig(2,nG);
Dall = {inDeg, outDeg};
for r = 1:2
    for g = 1:nG
        nexttile(tl,(r-1)*nG+g); hold on
        H = gobjects(1,3);
        for s = 1:3
            [F,x] = ecdf(Dall{r}{g,s});
            H(s) = stairs(x, F, 'Color', colors(s,:), 'LineWidth', 1.5);
        end
        xlabel(xl{r})
        if g == 1, ylabel('CDF'); end
        if r == 1, title({tnames{g}, sprintf('t = %d', tEndG(g)-1)}); end
        if g == 1 && r == 1, sharedLegend(tl,H,names); end
    end
end
finish(tl,'figC3')

% ---- Figure C4: proximity of the targeted category ----
tsRows('figC4', {'proximity',none,'Proximity',1,false,0}, R,tEndG,colors,names,tnames);

% ---- Figure C5: new firms' in-degree, essential and optional inputs, out-degree (MA) ----
tsRows('figC5', {'newIn',  ma,'In-degree',        1,false,0; ...
                 'newEss', ma,'Essential inputs', 1,false,0; ...
                 'newOpt', ma,'Optional inputs',  1,false,0; ...
                 'newOut', ma,'Out-degree',       1,false,0}, R,tEndG,colors,names,tnames);

% ---- Figure C6: new firms' productivity vs category homogeneity (Spearman), by period of entry ----
spans  = [1 100; 101 250; 251 400; 401 Inf];
slabel = {'1-100','101-250','251-400','>400'};
corrFigure('figC6', 'Spearman', '', R, tEndG, tnames, names, colors, spans, slabel);

% ---- Figures C7-C8: log real value added, mean log-productivity and mean log-price ----
tsRows('figC7', {'growth',none,'Log real value added',0,false,1}, R,tEndG,colors,names,tnames);
tsRows('figC8', {'meanLogProd', none,'Mean log-productivity',0,false, 1; ...
                 'meanLogPrice',none,'Mean log-price',       0,false,-1}, R,tEndG,colors,names,tnames);

% ---- Figure C9: suppliers of new firms (10-period moving average over entry periods) ----
% Row 1: mean log-productivity of all suppliers; row 2: of the essential suppliers (both in the
% equilibrium before entry); row 3: number of optional inputs available in the target category.
tsRows('figC9', {'supProd',  ma,{'Suppliers''','mean log-prod.'},           1,false,1; ...
                 'essProd',  ma,{'Essential suppliers''','mean log-prod.'}, 1,false,1; ...
                 'optAvail', ma,{'Optional inputs','available'},            1,false,1}, ...
       R,tEndG,colors,names,tnames);

%% ================= TABLES (numbered as in Appendix C) =================
gHead = 'Simulation';
nRow = nG*3;
rn = cell(nRow,1);  rowG = cell(nRow,1);  rowS = cell(nRow,1);
row = 0;
for g = 1:nG
    for s = 1:3
        row = row + 1;
        rn{row} = sprintf('%s | %s', tnames{g}, names{s});
        rowG{row} = texG{g};  rowS{row} = names{s};
    end
end
% Short caption texts. Horizon: the most common end period, with the exceptions in parentheses
% (e.g. "Periods up to 750 (245 for $\lambda_1=0.01$)."). Runs: one number if all are equal.
tEnd0 = mode(tEndG - 1);
exc   = find(tEndG - 1 ~= tEnd0);
excTxt = '';
if ~isempty(exc)
    parts = arrayfun(@(g) sprintf('%d for %s', tEndG(g)-1, texG{g}), exc, 'UniformOutput', false);
    excTxt = sprintf(' (%s)', strjoin(parts, '; '));
end
tEndTxt = sprintf('%d%s', tEnd0, excTxt);
if all(nSimG == nSimG(1))
    runTxt = sprintf('%d runs', nSimG(1));
else
    runTxt = sprintf('%d, %d, %d and %d runs, respectively', nSimG);
end

% ---- Table C1: exits, entry success and final number of firms ----
%   Share Active: share of periods with at least one exit
T1 = nan(nRow,6);  T1h = T1;
row = 0;
for g = 1:nG
    tE = tEndG(g) - 1;  nS = nSimG(g);
    for s = 1:3
        row = row + 1;
        e  = R(g,s).exits(1:tE,:);
        sc = R(g,s).success(1:tE,:);
        T1(row,:) = [mean(e(:)), mean(e(:) > 0), max(e(:)), mean(sum(e,1)), ...
                     mean(sc(:),'omitnan'), mean(R(g,s).nFirms(tE+1,:))];
        te = sum(e,1);
        T1h(row,:) = [NaN NaN NaN tinv(0.975,nS-1)*std(te)/sqrt(nS) NaN NaN];
    end
end
disp(array2table(T1, 'RowNames', rn, 'VariableNames', ...
    {'MeanExits','ShareActive','MaxCascade','TotalExits','EntrySuccess','FinalFirms'}))
writeLatexTable(fullfile(tabDir,'tab_exits_app.tex'), gHead, rowG, rowS, T1, ...
    {'Mean Exits','Share Active','Max Cascade','Total Exits','Entry Success','Final Firms'}, ...
    {'%.4f','%.4f','%d','%.2f','%.3f','%.1f'}, ...
    sprintf(['Exit and entry statistics, sensitivity simulations (mean over %s; 95\\%% confidence ' ...
    'interval of Total Exits in parentheses). Periods up to %s.'], runTxt, tEndTxt), ...
    'tab:exit_app', T1h, '0.85\textwidth');

% ---- Correlation tables C2-C4, same structure as Tables A2-A4 of the main analysis ----
% All tables: pooled Spearman correlations over the new firms of all runs that survive their
% entry period; every variable is measured as a deviation from its period-specific mean across
% runs; singleton categories (proximity >= 1) are excluded.
% Each table has at most three panels so that it fits on one page. Panel specification:
%   {title, correlation type, control(s), variable Y}
%   control : '' = none, a field name = one control, a cell of field names = several controls
%   Y       : '' = new firm's log-productivity (newProd); otherwise the variable correlated
%             with the proximity of the target category
% Significance stars from the p-values of corr/partialcorr:  *** p<0.01, ** p<0.05, * p<0.1.
spanHead = {'1--100','101--250','251--400','$>$400'};
spanVar  = {'s1_100','s101_250','s251_400','s400plus'};
starTxt  = '$^{***}$ $p<0.01$, $^{**}$ $p<0.05$, $^{*}$ $p<0.1$. ';

% ---- Table C2: new firms' productivity and proximity ----
pan3a = { ...
    'Panel A: Spearman',                                         'Spearman', '',        ''; ...
    'Panel B: Partial Spearman, control: category productivity', 'Spearman', 'catProd', ''};
if ~hasCatProd, pan3a(2,:) = []; end
[RHO, PV] = corrPanelSet(pan3a, R, nG, tEndG, spans, rn, spanVar);
writeCorrTable(fullfile(tabDir,'tab_corr_app.tex'), gHead, rowG, rowS, RHO, PV, pan3a(:,1), spanHead, ...
    sprintf(['New firms'' log-productivity and the proximity of their targeted categories, sensitivity ' ...
    'simulations (computed as in Table~\\ref{tab:corr}; %s). ' starTxt 'Periods up to %s.'], ...
    runTxt, tEndTxt), 'tab:corr_app', '0.7\textwidth');

% ---- Table C3: quantity and quality of suppliers as channels ----
% Panel A (quantity): control for the number of suppliers of the new firm.
% Panel B (quality):  control for the mean productivity of its suppliers.
% Panel C: both. Panel C close to zero means that the correlation decomposes into these two
% components (by construction of the productivity function; not a test for other channels).
pan3b = { ...
    'Panel A: Partial Spearman, control: number of suppliers', ...
                                                        'Spearman', 'newIn',             ''; ...
    'Panel B: Partial Spearman, control: mean productivity of suppliers', ...
                                                        'Spearman', 'supProd',           ''; ...
    'Panel C: Partial Spearman, controls: number and mean productivity of suppliers', ...
                                                        'Spearman', {'newIn','supProd'}, ''};
[RHO, PV] = corrPanelSet(pan3b, R, nG, tEndG, spans, rn, spanVar);
writeCorrTable(fullfile(tabDir,'tab_corr_chan_app.tex'), gHead, rowG, rowS, RHO, PV, pan3b(:,1), spanHead, ...
    sprintf(['Quantity and quality of suppliers as channels, sensitivity simulations (computed as in ' ...
    'Table~\\ref{tab:corr_chan}; %s). ' starTxt 'Periods up to %s.'], ...
    runTxt, tEndTxt), 'tab:corr_chan_app', '0.75\textwidth');

% ---- Table C4: proximity and the productivity of the new firms' suppliers ----
pan3c = { ...
    'Panel A: Mean log-productivity of all suppliers',       'Spearman', '',      'supProd'; ...
    'Panel B: Mean log-productivity of essential suppliers', 'Spearman', '',      'essProd'; ...
    'Panel C: Mean log-productivity of all suppliers, control: number of suppliers', ...
                                                             'Spearman', 'newIn', 'supProd'};
[RHO, PV] = corrPanelSet(pan3c, R, nG, tEndG, spans, rn, spanVar);
writeCorrTable(fullfile(tabDir,'tab_corr_sup_app.tex'), gHead, rowG, rowS, RHO, PV, pan3c(:,1), spanHead, ...
    sprintf(['Proximity of the targeted category and the productivity of new firms'' suppliers, ' ...
    'sensitivity simulations (computed as in Table~\\ref{tab:corr_sup}; %s). ' starTxt ...
    'Periods up to %s.'], runTxt, tEndTxt), 'tab:corr_sup_app', '0.75\textwidth');

%% ================= LOCAL FUNCTIONS (must stay at the END of the script) =================
function tsRows(name, rows, R, tEndG, colors, names, tnames)
% size(rows,1) rows x nG columns. A/B/C overlaid, mean + 95% CI. Each panel keeps its own limits.
    nc = numel(tEndG);  nr = size(rows,1);
    tl = prepFig(nr,nc);
    for r = 1:nr
        ax = gobjects(1,nc);  M = cell(1,nc);
        for g = 1:nc
            ax(g) = nexttile(tl,(r-1)*nc+g);
            [M{g},H] = tsAxes(R,g,rows{r,1},rows{r,2},tEndG(g),rows{r,4},colors,rows{r,5});
            xlim([0 tEndG(g)])
            if r == 1, title(tnames{g}); end
            if r == nr, xlabel('Time'); end
            if g == 1
                ylabel(rows{r,3});
                if r == 1, sharedLegend(tl,H,names); end
            end
        end
        if rows{r,6} ~= 0                                % shade periods in which A is ahead of BOTH B and C
            for g = 1:nc
                yl = ylim(ax(g));
                if rows{r,6} > 0
                    d = M{g}{1} > M{g}{2} & M{g}{1} > M{g}{3};   % A higher than B and C
                else
                    d = M{g}{1} < M{g}{2} & M{g}{1} < M{g}{3};   % A lower than B and C (e.g. prices)
                end
                t = (1:numel(d))';
                a = area(ax(g), t, yl(1) + (yl(2)-yl(1))*double(d), yl(1), ...
                    'FaceColor', colors(1,:), 'FaceAlpha', 0.12, ...
                    'EdgeColor','none', 'HandleVisibility','off');
                uistack(a,'bottom');
                ylim(ax(g), yl)
            end
        end
    end
    finish(tl,name)
end

function [M,H] = tsAxes(R, g, field, tf, tEnd, tOff, colors, nonneg)
    hold on
    M = cell(1,3);  H = gobjects(1,3);
    for s = 1:3
        X = tf(R(g,s).(field));
        X = X(1:min(tEnd-tOff, size(X,1)), :);
        t = (1:size(X,1))';
        n = sum(~isnan(X),2);
        m = mean(X,2,'omitnan');
        h = tinv(0.975, max(n-1,1)) .* std(X,0,2,'omitnan') ./ sqrt(n);
        lo = m - h;  hi = m + h;
        if nonneg, lo = max(lo,0); end
        ok = ~isnan(lo) & ~isnan(hi);
        fill([t(ok); flipud(t(ok))], [lo(ok); flipud(hi(ok))], colors(s,:), ...
            'FaceAlpha',0.2, 'EdgeColor','none', 'HandleVisibility','off');
        H(s) = plot(t, m, 'Color', colors(s,:), 'LineWidth', 1.5);
        M{s} = m;
    end
end

function tl = prepFig(nr, nc, hRow)
% New figure at its EXACT printed size (width = \textwidth) with a compact tiled layout.
% Include the PDF in LaTeX WITHOUT scaling:  \includegraphics{graphs/figC1.pdf}
    o = getappdata(0,'figOpts');
    if nargin < 3, hRow = 0.8*o.W/nc + 0.25; end
    f = figure;
    set(f, 'Units','inches', 'Position', [1 1 o.W hRow*nr+0.35], 'Resize','off', 'Color','w');
    tl = tiledlayout(f, nr, nc, 'TileSpacing','compact', 'Padding','compact');
end

function finish(tl, name)
% One font size for all text, then export as vector PDF (graphs/<name>.pdf).
    o = getappdata(0,'figOpts');
    f = ancestor(tl,'figure');
    set(findall(f,'-property','FontSize'), 'FontSize', o.FS);
    set(findall(f,'Type','axes'), 'TitleFontSizeMultiplier',1, 'LabelFontSizeMultiplier',1, ...
        'TickLength',[0.02 0.02]);
    drawnow
    exportgraphics(f, fullfile(o.dir, [name '.pdf']), 'ContentType','vector');
end

function lg = sharedLegend(tl, h, s)
% One horizontal legend above the panels.
    o = getappdata(0,'figOpts');
    lg = legend(h, s, 'Orientation','horizontal', 'Box','off', 'FontSize', o.FS);
    lg.Layout.Tile = 'north';
    lg.ItemTokenSize = [15 8];
end

function writeLatexTable(fname, gHead, rowG, rowS, D, heads, fmts, cap, lab, Hw, width)
% Complete LaTeX table (requires adjustbox and float); Hw: optional 95% CI half-widths.
    if nargin < 10, Hw = []; end
    if nargin < 11, width = '\textwidth'; end
    nc  = size(D,2);
    fid = fopen(fname,'w');
    fprintf(fid,'\\begin{table}[H]\n\\centering\n\\caption{%s}\n\\label{%s}\n', cap, lab);
    fprintf(fid,'\\begin{adjustbox}{max width=%s}\n\\begin{tabular}{ll%s}\n\\hline\n', width, repmat('c',1,nc));
    hd = [{gHead,'Innovation Scenario'}, heads];
    hd = cellfun(@stackHead, hd, 'UniformOutput', false);
    fprintf(fid,'%s \\\\\n\\hline\n', strjoin(hd,' & '));
    for r = 1:size(D,1)
        newGroup = (r == 1) || ~strcmp(rowG{r}, rowG{r-1});
        if newGroup && r > 1, fprintf(fid,'\\hline\n'); end
        g = '';  if newGroup, g = rowG{r}; end
        v = cell(1,nc);
        for j = 1:nc
            if isnan(D(r,j)), v{j} = '--'; continue; end
            v{j} = sprintf(fmts{j}, D(r,j));
            if ~isempty(Hw) && ~isnan(Hw(r,j))
                v{j} = sprintf(['%s ($\\pm$' fmts{j} ')'], v{j}, Hw(r,j));
            end
        end
        fprintf(fid,'%s & %s & %s \\\\\n', g, rowS{r}, strjoin(v,' & '));
    end
    fprintf(fid,'\\hline\n\\end{tabular}\n\\end{adjustbox}\n\\end{table}\n');
    fclose(fid);
    fprintf('LaTeX table written to %s\n', fname);
end

function bb = spanBars(C, L, U, colors, slabel)
    hold on
    bb = bar(C, 'grouped');
    for s = 1:3
        bb(s).FaceColor = colors(s,:);
        errorbar(bb(s).XEndPoints, C(:,s), C(:,s)-L(:,s), U(:,s)-C(:,s), ...
            'k', 'LineStyle','none', 'CapSize',4, 'HandleVisibility','off');
    end
    set(gca,'XTick',1:numel(slabel),'XTickLabel',slabel)
    yline(0,'-','HandleVisibility','off')
end

function h = stackHead(h)
    k = find(h == ' ', 1, 'last');
    if isempty(k), return; end
    h = sprintf('\\begin{tabular}[c]{@{}c@{}}%s\\\\%s\\end{tabular}', h(1:k-1), h(k+1:end));
end

function [Pd, Xd, Zd, keep, tIdx] = corrPrep(R, g, s, tEndG, ctrlVar, yVar)
% Deviations from period-specific means across runs.
%   ctrlVar : '' (no control), one field name, or a cell array of field names (several controls)
%   yVar    : variable correlated with proximity (default 'newProd' = new firm's log-productivity)
%   Zd      : cell array, one matrix (periods x runs) per control variable
    if nargin < 6 || isempty(yVar), yVar = 'newProd'; end
    ctrlVar = ctrlList(ctrlVar);
    nz = numel(ctrlVar);
    tw = 1:min(tEndG(g)-1, size(R(g,s).proximity,1));
    P = R(g,s).proximity(tw,:);   X = R(g,s).(yVar)(tw,:);
    ok = ~isnan(P) & ~isnan(X) & ~(P >= 1);       % P >= 1: singleton categories excluded
    Z = cell(1,nz);
    for j = 1:nz
        Z{j} = R(g,s).(ctrlVar{j})(tw,:);
        ok = ok & ~isnan(Z{j});
    end
    % Use only observations where ALL variables exist, then demean each variable by period.
    P(~ok) = NaN;  X(~ok) = NaN;
    Pd = P - mean(P,2,'omitnan');  Xd = X - mean(X,2,'omitnan');
    keep = ok & ~isnan(Pd) & ~isnan(Xd);
    Zd = cell(1,nz);
    for j = 1:nz
        Z{j}(~ok) = NaN;  Zd{j} = Z{j} - mean(Z{j},2,'omitnan');
        keep = keep & ~isnan(Zd{j});
    end
    tIdx = repmat(tw(:), 1, size(P,2));
end

function c = ctrlList(ctrlVar)
% Converts the control specification into a cell array of field names ({} = no control).
    if iscell(ctrlVar), c = ctrlVar; return; end
    if isempty(ctrlVar) || strlength(ctrlVar) == 0, c = {}; else, c = {char(ctrlVar)}; end
end

function Zm = zCols(Zd, mk)
% Selected observations (logical mask mk) of all control variables, one column per control.
    Zm = cell2mat(cellfun(@(v) v(mk), Zd, 'UniformOutput', false));
end

function corrFigure(name, ctype, ctrlVar, R, tEndG, tnames, names, colors, spans, slabel)
% Row 1: pooled correlation (Fisher-z 95% CI); row 2: mean of per-run correlations (t-based CI).
    nz = numel(ctrlList(ctrlVar));  ctrl = nz > 0;      % number of control variables
    nSp = size(spans,1);  nc = numel(tEndG);
    tl = prepFig(2,nc);
    for g = 1:nc
        Cp = nan(nSp,3);  Lp = Cp;  Up = Cp;
        Cr = nan(nSp,3);  Lr = Cr;  Ur = Cr;
        for s = 1:3
            [Pd, Xd, Zd, keep, tIdx] = corrPrep(R, g, s, tEndG, ctrlVar);
            nRun = size(Pd,2);
            for q = 1:nSp
                mk = keep & tIdx >= spans(q,1) & tIdx <= spans(q,2);
                if nnz(mk) > 30
                    if ctrl, rho = partialcorr(Pd(mk), Xd(mk), zCols(Zd,mk), 'Type', ctype);
                    else,    rho = corr(Pd(mk), Xd(mk), 'Type', ctype); end
                    z = atanh(rho);  sz = 1/sqrt(nnz(mk)-3-nz);
                    Cp(q,s) = rho;  Lp(q,s) = tanh(z-1.96*sz);  Up(q,s) = tanh(z+1.96*sz);
                end
                rr = nan(1,nRun);
                for k = 1:nRun
                    m = false(size(mk));  m(:,k) = mk(:,k);   % observations of run k only
                    if nnz(m) > 20
                        if ctrl, rr(k) = partialcorr(Pd(m), Xd(m), zCols(Zd,m), 'Type', ctype);
                        else,    rr(k) = corr(Pd(m), Xd(m), 'Type', ctype); end
                    end
                end
                n = sum(~isnan(rr));
                if n > 2
                    mu = mean(rr,'omitnan');
                    h  = tinv(0.975, n-1) * std(rr,'omitnan') / sqrt(n);
                    Cr(q,s) = mu;  Lr(q,s) = mu-h;  Ur(q,s) = mu+h;
                end
            end
        end
        lab = ctype;  if ctrl, lab = ['partial ' ctype]; end
        nexttile(tl,g);      bb = spanBars(Cp,Lp,Up,colors,slabel);
        title(tnames{g})
        if g == 1
            ylabel(sprintf('Pooled %s \\rho', lab));
            sharedLegend(tl,bb,names);
        end
        nexttile(tl,nc+g);   spanBars(Cr,Lr,Ur,colors,slabel);
        xlabel('Period of entry')
        if g == 1, ylabel(sprintf('Mean per-run %s \\rho', lab)); end
    end
    finish(tl,name)
end

function [RHO, PV] = corrPanelSet(panels, R, nG, tEndG, spans, rn, spanVar)
% Computes all panels of one correlation table (one row per simulation x scenario, one column
% per period of entry) and prints them in the console.
%   panels : {title, correlation type, control(s), Y variable} per panel
    nPan = size(panels,1);
    RHO  = nan(nG*3, size(spans,1), nPan);  PV = RHO;
    for pnl = 1:nPan
        row = 0;
        for g = 1:nG
            for s = 1:3
                row = row + 1;
                [RHO(row,:,pnl), PV(row,:,pnl)] = corrStats(R, g, s, tEndG, spans, ...
                    panels{pnl,2}, panels{pnl,3}, panels{pnl,4});
            end
        end
        fprintf('\n%s\n', panels{pnl,1});
        disp(array2table(RHO(:,:,pnl), 'RowNames', rn, 'VariableNames', spanVar))
    end
end

function [rho, pv] = corrStats(R, g, s, tEndG, spans, ctype, ctrlVar, yVar)
% Pooled (partial) correlation between proximity and yVar (default: entrant log-productivity),
% with p-values, by period of entry. ctrlVar: '', one field name, or a cell of field names.
    if nargin < 8, yVar = ''; end
    nSp = size(spans,1);
    rho = nan(1,nSp);  pv = rho;
    ctrl = ~isempty(ctrlList(ctrlVar));
    [Pd, Xd, Zd, keep, tIdx] = corrPrep(R, g, s, tEndG, ctrlVar, yVar);
    for q = 1:nSp
        mk = keep & tIdx >= spans(q,1) & tIdx <= spans(q,2);
        if nnz(mk) > 30
            if ctrl, [rho(q), pv(q)] = partialcorr(Pd(mk), Xd(mk), zCols(Zd,mk), 'Type', ctype);
            else,    [rho(q), pv(q)] = corr(Pd(mk), Xd(mk), 'Type', ctype); end
        end
    end
end

function writeCorrTable(fname, gHead, rowG, rowS, RHO, PV, panels, heads, cap, lab, width)
% One panel per specification; *** p<0.01, ** p<0.05, * p<0.1 (requires adjustbox and float).
    if nargin < 11, width = '\textwidth'; end
    [nR, nc, nP] = size(RHO);
    fid = fopen(fname,'w');
    fprintf(fid,'\\begin{table}[H]\n\\centering\n\\caption{%s}\n\\label{%s}\n', cap, lab);
    fprintf(fid,'\\begin{adjustbox}{max width=%s}\n\\begin{tabular}{ll%s}\n\\hline\n', width, repmat('c',1,nc));
    fprintf(fid,'%s & Scenario & \\multicolumn{%d}{c}{Period of entry} \\\\\n', gHead, nc);
    fprintf(fid,'\\cline{3-%d}\n', nc+2);
    fprintf(fid,' & & %s \\\\\n\\hline\n', strjoin(heads,' & '));
    for p = 1:nP
        if p > 1, fprintf(fid,'\\hline\n'); end
        fprintf(fid,'\\multicolumn{%d}{l}{\\textit{%s}} \\\\\n', nc+2, panels{p});
        for r = 1:nR
            newGroup = (r == 1) || ~strcmp(rowG{r}, rowG{r-1});
            g = '';  if newGroup, g = rowG{r}; end
            v = cell(1,nc);
            for j = 1:nc
                if isnan(RHO(r,j,p)), v{j} = '--'; continue; end
                st = '';
                if     PV(r,j,p) < 0.01, st = '^{***}';
                elseif PV(r,j,p) < 0.05, st = '^{**}';
                elseif PV(r,j,p) < 0.10, st = '^{*}';
                end
                v{j} = sprintf('$%.2f%s$', RHO(r,j,p), st);
            end
            fprintf(fid,'%s & %s & %s \\\\\n', g, rowS{r}, strjoin(v,' & '));
        end
    end
    fprintf(fid,'\\hline\n\\end{tabular}\n\\end{adjustbox}\n\\end{table}\n');
    fclose(fid);
    fprintf('LaTeX table written to %s\n', fname);
end

function syncLim(axs, prop)
    L = cell2mat(get(axs(:), prop));
    set(axs, prop, [min(L(:,1)) max(L(:,2))]);
end