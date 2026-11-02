% FIGURES_MAIN  Figures and tables of the main text and of Appendices A and B of
% "Technological evolution of production networks".
%
% All simulation files must be in the current folder, together with i_data_ar.mat:
%   sim_<targeting>_<innovation>_<run>.mat   INC regime (index_nc = 1), targeting 0, 1, 2
%   sim_fnc_0_<innovation>_<run>.mat         FNC regime (index_nc = 0), random targeting
% (innovation 0, 1, 2 = Scenarios A, B, C), as written by generateSimulationFiles.m.
%
% Output (numbered as in the paper):
%   graphs/fig1.pdf ... fig8.pdf, figA1.pdf, figB1.pdf, figB2.pdf
%   tables/tab_exits.tex (Table 2), tab_newprod.tex (Table 3), tab_ess_only.tex (Table A1),
%   tab_corr.tex (Table A2), tab_corr_chan.tex (Table A3), tab_corr_sup.tex (Table A4),
%   tab_cat_growth.tex (Table B1)
% Table 1 (parameters) is written directly in the LaTeX file.

%% ================= SETTINGS =================
clear; clc
i_data = load('i_data_ar.mat');

tgt    = 0:2;                                   % index_targeting (INC groups 1-3)
tnames = {'INC - Random','INC - Productivity','INC - Homogeneity','FNC - Random'};
texG   = {'INC -- Random','INC -- Productivity','INC -- Homogeneity','FNC -- Random'};
colOrder = [4 1 2 3];                           % order of columns/rows: FNC first, then INC
nG     = 4;                                     % groups 1-3: INC, 4: FNC random
scen   = 0:2;                                   % index_innovation -> Scenarios A, B, C (overlaid)
names  = {'A','B','C'};
nSimG  = [100 100 100 100];                     % runs per group: INC random, INC productivity, INC homogeneity, FNC random
colors = [0 0.4470 0.7410; 0.8500 0.3250 0.0980; 0.9290 0.6940 0.1250];
set(0,"DefaultLineLineWidth",0.8);
proxVersion = 'before';                         % proximity of the target category before the entrant enters
wEO    = 10;                                    % moving-average window (periods) for new firms' variables
Tmax   = 750;                                   % periods used in all figures and tables
ncp    = 50;                                    % periods between two re-categorizations
none = @(X) X;
ma   = @(X) movmean(X, wEO, 1, 'omitnan');      % moving average over time, per run
% ---- figure layout: figures are built at the EXACT printed size and included unscaled ----
figW   = 5.4;          % \textwidth in inches: in LaTeX type \the\textwidth (pt) and divide by 72.27
figFS  = 8;            % font size (pt) of all text in the figures = size in the paper
figDir = 'graphs';     % figures are exported here as vector PDF
setappdata(0,'figOpts',struct('W',figW,'FS',figFS,'dir',figDir));
if ~exist(figDir,'dir'), mkdir(figDir); end
tabDir = 'tables';     % LaTeX tables are written here
if ~exist(tabDir,'dir'), mkdir(tabDir); end

%% ================= LOAD =================
for g = 1:nG
for s = 1:numel(scen)
    for k = 1:nSimG(g)
        f = load(simFile(g,s,k,tgt,scen), ...
            's_growth','s_logprod','s_logprices','s_indegree','s_outdegree', ...
            'entry_log','s_cat_prox','s_firm_catlabels','s_firm_id');
        nT = min(numel(f.s_growth), Tmax+1);          % states: 1 = initial, t+1 = end of period t
        if k == 1
            R(g,s).nFirms       = zeros(nT,nSimG(g));
            R(g,s).nLinks       = zeros(nT,nSimG(g));
            R(g,s).meanLogProd  = zeros(nT,nSimG(g));
            R(g,s).meanLogPrice = zeros(nT,nSimG(g));
            R(g,s).growth       = zeros(nT,nSimG(g));
            R(g,s).exits        = zeros(nT-1,nSimG(g));
            R(g,s).success      = zeros(nT-1,nSimG(g));   % entry successful (1/0), entry_log row 6
            R(g,s).newIn        = nan(nT-1,nSimG(g));
            R(g,s).newOut       = nan(nT-1,nSimG(g));
            R(g,s).newProd      = nan(nT-1,nSimG(g));
            R(g,s).newEss       = nan(nT-1,nSimG(g));
            R(g,s).newOpt       = nan(nT-1,nSimG(g));
            R(g,s).supProd      = nan(nT-1,nSimG(g));   % mean log-prod. of the new firm's suppliers (entry_log row 11)
            R(g,s).essProd      = nan(nT-1,nSimG(g));   % mean log-prod. of its essential suppliers (row 12)
            R(g,s).optAvail     = nan(nT-1,nSimG(g));   % optional inputs available in the target category (row 13)
            R(g,s).proximity    = nan(nT-1,nSimG(g));
            R(g,s).catProd      = nan(nT-1,nSimG(g));
        end
        n = cellfun(@numel, f.s_indegree(1:nT));   n = n(:);
        R(g,s).nFirms(:,k) = n;
        tmp = cellfun(@sum, f.s_indegree(1:nT));
        R(g,s).nLinks(:,k) = tmp(:) ./ n;           % input links per firm (network density)
        tmp = cellfun(@mean, f.s_logprod(1:nT));
        R(g,s).meanLogProd(:,k) = tmp(:);           % mean log-productivity
        tmp = cellfun(@mean, f.s_logprices(1:nT));
        R(g,s).meanLogPrice(:,k) = tmp(:);          % mean log-price
        tmp = cell2mat(f.s_growth(1:nT));
        R(g,s).growth(:,k) = tmp(:);                % log real value added
        survived = (f.entry_log(7,1:nT-1) == 1)';
        ex = f.entry_log(5,1:nT-1)';  ex(isnan(ex)) = 0;
        R(g,s).exits(:,k) = ex;
        % Entry success (1/0). Periods in which no category could be targeted (no entry
        % attempt: entry_log row 2 is NaN) are set to NaN, so they are left out of the
        % denominator of the entry success rate.
        sc = double(f.entry_log(6,1:nT-1) == 1)';
        sc(isnan(f.entry_log(2,1:nT-1))') = NaN;
        R(g,s).success(:,k) = sc;
        % New firms that survive their entry period: the new firm is the last firm in the network.
        for p = find(survived)'
            inD = f.s_indegree{p+1}(end);
            ess = f.entry_log(10,p);
            R(g,s).newIn(p,k)   = inD;                   % in-degree = essential + optional inputs
            R(g,s).newOut(p,k)  = f.s_outdegree{p+1}(end);
            R(g,s).newProd(p,k) = f.s_logprod{p+1}(end);
            R(g,s).newEss(p,k)  = ess;
            R(g,s).newOpt(p,k)  = inD - ess;
            % Suppliers of the new firm, measured with the productivities it saw when it chose
            % them (equilibrium of period p-1).
            R(g,s).supProd(p,k)  = f.entry_log(11,p);
            R(g,s).essProd(p,k)  = f.entry_log(12,p);
            R(g,s).optAvail(p,k) = f.entry_log(13,p);
        end
        if strcmp(proxVersion,'before')
            R(g,s).proximity(:,k) = f.entry_log(3,1:nT-1)';
        else
            R(g,s).proximity(:,k) = f.entry_log(4,1:nT-1)';
        end
        % Mean log-productivity of the target category before entry (state p = end of p-1).
        % Periods with re-categorization at the start of p are skipped, since the labels
        % in state p differ from those used to select the target category.
        for p = 1:nT-1
            if mod(p+1, ncp) == 1, continue; end
            tc = f.entry_log(2,p);
            if ~isnan(tc)
                lab = f.s_firm_catlabels{p};  lp = f.s_logprod{p};
                R(g,s).catProd(p,k) = mean(lp(lab == tc));
            end
        end
        % Category characteristics per re-categorization window (Appendix B)
        [Wk, Sk] = catWindows(f, ncp, Tmax);
        if k == 1
            R(g,s).catW = cell(1,nSimG(g));
            R(g,s).catS = nan(size(Sk,1), size(Sk,2), nSimG(g));
        end
        R(g,s).catW{k}     = [Wk, k*ones(size(Wk,1),1)];   % last column = run
        R(g,s).catS(:,:,k) = Sk;
    end
end
end

% Productivity of new firms relative to all firms and to the incumbents of their target
% category. newProd(p,k) is measured in state p+1 (end of the entry period), so it is compared
% with the mean log-productivity of all firms in the same state; catProd(p,k) is the mean of
% the incumbents of the target category before entry (NaN in re-categorization periods).
for g = 1:nG
for s = 1:3
    R(g,s).newRel    = R(g,s).newProd - R(g,s).meanLogProd(2:end,:);
    R(g,s).newRelCat = R(g,s).newProd - R(g,s).catProd;
end
end

%% ================= LAST REPORTED PERIOD =================
% tEndG(g) = last reported state. Simulations would be truncated if log real value added in
% Scenario A explodes (lambda_1*rho(M_t) close to one); with lambda_1 = 0.004 this does not
% happen, and all 750 periods are reported (tEndG = 751 in all groups).
tEndG = zeros(1,nG);
for g = 1:nG
    i = find(any(R(g,1).growth >= 30, 2), 1, 'first');
    if isempty(i), i = size(R(g,1).growth,1); end
    tEndG(g) = i;
end
disp(tEndG)

%% ================= DEGREES AT tEnd (second pass, pooled over runs) =================
inDeg = cell(nG,3);  outDeg = cell(nG,3);
for g = 1:nG
for s = 1:3
    for k = 1:nSimG(g)
        f = load(simFile(g,s,k,tgt,scen), 's_indegree','s_outdegree');
        inDeg{g,s}  = [inDeg{g,s};  f.s_indegree{tEndG(g)}(:)];
        outDeg{g,s} = [outDeg{g,s}; f.s_outdegree{tEndG(g)}(:)];
    end
end
end
in0  = sum(i_data.A,2);   out0 = sum(i_data.A,1)';

%% ================= COMMON SETTINGS OF THE TABLES =================
% All tables use periods 1..t_end (t_end = tEndG(g)-1). Rows: FNC first, then INC (colOrder).
nRow = numel(colOrder)*3;
rn   = cell(nRow,1);  rowG = cell(nRow,1);  rowS = cell(nRow,1);
row = 0;
for c = 1:numel(colOrder)
    for s = 1:3
        row = row + 1;
        rn{row}   = sprintf('%s | %s', tnames{colOrder(c)}, names{s});
        rowG{row} = texG{colOrder(c)};  rowS{row} = names{s};
    end
end
if all(nSimG == nSimG(1))
    runsTxt = sprintf('%d runs', nSimG(1));
else
    runsTxt = sprintf('%d runs under FNC and %d runs under INC', nSimG(4), nSimG(1));
end
if all(tEndG == tEndG(1))
    tEndTxt = sprintf('%d in all scenarios', tEndG(1)-1);
else
    tEndTxt = sprintf(['%d under FNC, and %d, %d and %d under INC for random, ' ...
        'productivity and homogeneity targeting, respectively'], ...
        tEndG(4)-1, tEndG(1)-1, tEndG(2)-1, tEndG(3)-1);
end
spans    = [1 150; 151 300; 301 450; 451 600; 601 750];   % periods of entry
slabel   = {'1-150','151-300','301-450','451-600','601-750'};
spans2   = [spans; 1 Inf];                                % + all periods
spanTxt  = {'1--150','151--300','301--450','451--600','601--750','All'};
spanHead = spanTxt(1:5);
spanVar  = {'s1_150','s151_300','s301_450','s451_600','s601_750'};
nSp2     = size(spans2,1);
starTxt  = '$^{***}$, $^{**}$ and $^{*}$ denote significance at the 1\\%%, 5\\%% and 10\\%% levels. ';
baseTxt  = sprintf(['All variables are measured as deviations from their period-specific mean across ' ...
    'runs, and correlations are computed by pooling the new firms of all runs (%s) that survive their ' ...
    'entry period. '], runsTxt);

%% =====================================================================
%% SECTION 4.1: EVOLUTION OF PRODUCTION NETWORK STRUCTURE
%% =====================================================================
% Row spec of time-series figures: {field, transform, ylabel, tOff, nonneg, shade}
% shade: +1 = shade periods in which the mean of A is higher than in BOTH B and C,
%        -1 = periods in which it is lower than in both (prices), 0 = no shading

% ---- Figure 1: network density (input links per firm) ----
tsRows('fig1', {'nLinks', none,'Links per firm', 0,false,0}, R,tEndG,colors,names,tnames,colOrder);

% ---- Figure 2: in-degree (top) and out-degree (bottom) distributions, initial and at t_end ----
nc2 = numel(colOrder) + 1;
tl = prepFig(2,nc2);
Dall = {inDeg, outDeg};  d0 = {in0, out0};  xl = {'In-degree','Out-degree'};
for r = 1:2
    nexttile(tl,(r-1)*nc2+1);                            % initial distribution
    [F0,x0] = ecdf(d0{r});
    stairs(x0, F0, 'k', 'LineWidth', 1.5);
    xlabel(xl{r}); ylabel('CDF')
    if r == 1, title({'Initial', 't = 0'}); end
    ax = gobjects(1,numel(colOrder));  H = gobjects(1,3);
    for c = 1:numel(colOrder)
        g = colOrder(c);
        ax(c) = nexttile(tl,(r-1)*nc2+1+c); hold on
        for s = 1:3
            [F,x] = ecdf(Dall{r}{g,s});
            H(s) = stairs(x, F, 'Color', colors(s,:), 'LineWidth', 1.5);
        end
        xlabel(xl{r})
        if r == 1, title({tnames{g}, sprintf('t = %d', tEndG(g)-1)}); end
        if c == 1 && r == 1, sharedLegend(tl,H,names); end
    end
    isInc = colOrder <= 3;
    syncLim(ax(isInc),'XLim'); syncLim(ax(isInc),'YLim')   % FNC keeps its own limits
end
finish(tl,'fig2')

% ---- Table 2: exits, entry success and final number of firms ----
%   Mean exits    : mean number of incumbent exits per period
%   Exits 1-100   : cumulative exits per run in periods 1-100 (mean over runs, 95% CI)
%   Max cascade   : largest number of exits in a single period (all runs)
%   Total exits   : cumulative exits per run (mean over runs, 95% CI)
%   Entry success : share of entry attempts adopted by at least one customer
%   Final firms   : number of firms at t_end (mean over runs)
T2 = nan(nRow,6);  T2h = nan(nRow,6);
row = 0;
for c = 1:numel(colOrder)
    g  = colOrder(c);
    tE = tEndG(g) - 1;
    for s = 1:3
        row = row + 1;
        e  = R(g,s).exits(1:tE,:);
        sc = R(g,s).success(1:tE,:);
        e100 = e(1:min(100,tE),:);                              % exits in periods 1-100
        T2(row,:) = [mean(e(:)), mean(sum(e100,1)), max(e(:)), mean(sum(e,1)), ...
                     mean(sc(:),'omitnan'), mean(R(g,s).nFirms(tE+1,:))];   % state tE+1 = end of period tE
        te = sum(e,1);  t100 = sum(e100,1);                     % per run
        T2h(row,:) = [NaN tinv(0.975,nSimG(g)-1)*std(t100)/sqrt(nSimG(g)) NaN ...
                      tinv(0.975,nSimG(g)-1)*std(te)/sqrt(nSimG(g)) NaN NaN];
    end
end
disp(array2table(T2, 'RowNames', rn, 'VariableNames', ...
    {'MeanExits','Exits1_100','MaxCascade','TotalExits','EntrySuccess','FinalFirms'}))
fprintf('Initial number of firms: %d\n', R(1,1).nFirms(1,1));
writeLatexTable(fullfile(tabDir,'tab_exits.tex'), rowG, rowS, T2, ...
    {'Mean Exits','Exits 1--100','Max Cascade','Total Exits','Entry Success','Final Firms'}, ...
    {'%.4f','%.2f','%d','%.2f','%.3f','%.1f'}, ...
    sprintf(['Exit and entry statistics by categorization regime and targeting strategy ' ...
    '(mean over %s; 95\\%% confidence intervals of Exits 1--100 and Total Exits in parentheses). ' ...
    'Statistics are computed up to the last reported period (%s).'], runsTxt, tEndTxt), ...
    'tab:exit_cascade_results', T2h, '\textwidth');

%% =====================================================================
%% SECTION 4.2: DRIVERS OF PRODUCTION NETWORK EVOLUTION
%% =====================================================================
% ---- Figure 3: proximity (technological homogeneity) of the targeted category ----
tsRows('fig3', {'proximity',none,'Proximity',1,false,0}, R,tEndG,colors,names,tnames,colOrder);

% ---- Figure 4: new firms' in-degree, essential inputs, optional inputs and out-degree (MA) ----
tsRows('fig4', {'newIn',  ma,'In-degree',        1,false,0; ...
                'newEss', ma,'Essential inputs', 1,false,0; ...
                'newOpt', ma,'Optional inputs',  1,false,0; ...
                'newOut', ma,'Out-degree',       1,false,0}, ...
       R,tEndG,colors,names,tnames,colOrder);

% ---- Figure 5: suppliers of new firms (MA over entry periods) ----
% Row 1: mean log-productivity of all suppliers; row 2: of the essential suppliers (both in
% the equilibrium before entry); row 3: number of optional inputs available in the target category.
tsRows('fig5', {'supProd',  ma,{'Suppliers''','mean log-prod.'},           1,false,1; ...
                'essProd',  ma,{'Essential suppliers''','mean log-prod.'}, 1,false,1; ...
                'optAvail', ma,{'Optional inputs','available'},            1,false,1}, ...
       R,tEndG,colors,names,tnames,colOrder);

% ---- Figure 6: new firms' productivity and the proximity of their target category ----
% Row 1: pooled Spearman correlation (all new firms of all runs), Fisher-z 95% CI.
% Row 2: Spearman correlation per run, mean over runs, t-based 95% CI.
corrFigure('fig6', 'Spearman', '', R, tEndG, colOrder, tnames, names, colors, spans, slabel);

%% =====================================================================
%% SECTION 4.3: EVOLUTION OF ECONOMIC OUTCOMES
%% =====================================================================
% ---- Table 3: productivity of new firms relative to all firms, by period of entry ----
% Mean over runs of the per-run mean of (new firm log-productivity - mean of all firms);
% only new firms that survive their entry period; 95% CI half-width (t-based).
T3 = nan(nRow,nSp2);  T3h = T3;
row = 0;
for c = 1:numel(colOrder)
    g  = colOrder(c);
    tE = tEndG(g) - 1;
    for s = 1:3
        row = row + 1;
        Y  = R(g,s).newRel(1:tE,:);
        tt = (1:tE)';
        for q = 1:nSp2
            m  = tt >= spans2(q,1) & tt <= spans2(q,2);
            mr = mean(Y(m,:),1,'omitnan');                     % per-run mean
            n  = sum(~isnan(mr));
            T3(row,q)  = mean(mr,'omitnan');
            T3h(row,q) = tinv(0.975,max(n-1,1))*std(mr,'omitnan')/sqrt(n);
        end
    end
end
disp(array2table(T3, 'RowNames', rn, 'VariableNames', [spanVar {'All'}]))
writeLatexTable(fullfile(tabDir,'tab_newprod.tex'), rowG, rowS, T3, spanTxt, ...
    repmat({'%.2f'},1,nSp2), ...
    sprintf(['Log-productivity of new firms relative to the mean log-productivity of all firms, ' ...
    'by period of entry (mean over %s; 95\\%% confidence intervals in parentheses). ' ...
    'Only new firms that survive their entry period are included. Periods up to %s.'], runsTxt, tEndTxt), ...
    'tab:newprod', T3h, '\textwidth');

% ---- Figure 7: log real value added ----
tsRows('fig7', {'growth',none,'Log real value added',0,false,1}, R,tEndG,colors,names,tnames,colOrder);

% ---- Figure 8: mean log-productivity and mean log-price ----
tsRows('fig8', {'meanLogProd', none,'Mean log-productivity',0,false, 1; ...
                'meanLogPrice',none,'Mean log-price',       0,false,-1}, R,tEndG,colors,names,tnames,colOrder);

%% =====================================================================
%% APPENDIX A: ADDITIONAL ANALYSIS
%% =====================================================================
% ---- Table A1: share of new firms that use only essential inputs, by period of entry ----
% A new firm uses only essential inputs if its in-degree equals its number of essential inputs
% (newOpt == 0); share per run, averaged over runs; 95% CI half-width (t-based).
TA1 = nan(nRow,nSp2);  TA1h = TA1;
row = 0;
for c = 1:numel(colOrder)
    g  = colOrder(c);
    tE = tEndG(g) - 1;
    for s = 1:3
        row = row + 1;
        O  = R(g,s).newOpt(1:tE,:);
        tt = (1:tE)';
        for q = 1:nSp2
            m  = tt >= spans2(q,1) & tt <= spans2(q,2);
            X  = O(m,:);
            sh = sum(X == 0,1) ./ sum(~isnan(X),1);           % per-run share
            n  = sum(~isnan(sh));
            TA1(row,q)  = 100*mean(sh,'omitnan');
            TA1h(row,q) = 100*tinv(0.975,max(n-1,1))*std(sh,'omitnan')/sqrt(n);
        end
    end
end
disp(array2table(TA1, 'RowNames', rn, 'VariableNames', [spanVar {'All'}]))
writeLatexTable(fullfile(tabDir,'tab_ess_only.tex'), rowG, rowS, TA1, spanTxt, ...
    repmat({'%.1f'},1,nSp2), ...
    sprintf(['Share of new firms (\\%%) that use only the essential inputs of their targeted ' ...
    'category, by period of entry (mean over %s; 95\\%% confidence intervals in parentheses).'], runsTxt), ...
    'tab:ess_only', TA1h, '0.95\textwidth');

% ---- Figure A1: productivity of new firms (MA over entry periods) ----
% Row 1: log-productivity; row 2: relative to the mean of all firms; row 3: relative to the
% mean of the incumbents of the target category before entry.
tsRows('figA1', {'newProd',   ma,{'New firms''','log-productivity'}, 1,false,1; ...
                 'newRel',    ma,{'Relative to','all firms'},        1,false,1; ...
                 'newRelCat', ma,{'Relative to','target category'},  1,false,1}, ...
       R,tEndG,colors,names,tnames,colOrder);

% ---- Correlation tables A2-A4, by period of entry ----
% Pooled Spearman correlations over the new firms of all runs that survive their entry period;
% every variable is measured as a deviation from its period-specific mean across runs (as in
% Figure 6); singleton categories (proximity >= 1) are excluded.
% Panel specification: {title, correlation type, control(s), variable Y, variable X}
%   control : '' = none, a field name = one control, a cell of field names = several controls
%   Y       : '' = new firm's log-productivity (newProd);  X : '' = proximity of the target category
% Significance stars from the p-values of corr/partialcorr: *** p<0.01, ** p<0.05, * p<0.1.

% ---- Table A2: new firms' productivity and proximity ----
panA2 = { ...
    'Panel A: Spearman',                                         'Spearman', '',        '', ''; ...
    'Panel B: Partial Spearman, control: category productivity', 'Spearman', 'catProd', '', ''};
[RHO, PV] = corrPanelSet(panA2, R, colOrder, tEndG, spans, rn, spanVar);
writeCorrTable(fullfile(tabDir,'tab_corr.tex'), rowG, rowS, RHO, PV, panA2(:,1), spanHead, ...
    sprintf(['Correlation between the new firms'' log-productivity and the proximity of their ' ...
    'targeted categories. %sPanel B reports the partial Spearman correlation ' ...
    'that controls for the mean log-productivity of the firms in the target category before entry ' ...
    '(category productivity). ' starTxt], baseTxt), 'tab:corr', ...
    'Period of entry', '0.65\textwidth');

% ---- Table A3: quantity and quality of suppliers as channels ----
% Panel A (quantity): the correlation vanishes once the number of suppliers is fixed if it
%   runs through the number of essential inputs.
% Panel B (quality): the correlation changes once supplier productivity is fixed if
%   homogeneity changes how productive the new firm's suppliers are.
% Panel C: both. The new firm's productivity is built from the number and productivity of its
%   suppliers plus a random shock, so Panel C close to zero means that the correlation
%   decomposes fully into these two components.
panA3 = { ...
    'Panel A: Partial Spearman, control: number of suppliers', ...
        'Spearman', 'newIn',             '', ''; ...
    'Panel B: Partial Spearman, control: mean productivity of suppliers', ...
        'Spearman', 'supProd',           '', ''; ...
    'Panel C: Partial Spearman, controls: number and mean productivity of suppliers', ...
        'Spearman', {'newIn','supProd'}, '', ''};
[RHO, PV] = corrPanelSet(panA3, R, colOrder, tEndG, spans, rn, spanVar);
writeCorrTable(fullfile(tabDir,'tab_corr_chan.tex'), rowG, rowS, RHO, PV, panA3(:,1), spanHead, ...
    sprintf(['Partial Spearman correlation between the new firms'' log-productivity and the proximity of ' ...
    'their targeted categories, controlling for the number of suppliers (in-degree) of the new firm ' ...
    '(Panel A), for the mean log-productivity of its suppliers before entry (Panel B), and for both ' ...
    '(Panel C), by period of entry. %s' starTxt 'Periods up to %s.'], baseTxt, tEndTxt), 'tab:corr_chan', ...
    'Period of entry', '0.75\textwidth');

% ---- Table A4: proximity and the productivity of the new firms' suppliers ----
% Are new firms that enter more homogeneous categories connected to more (or less) productive
% suppliers? Panel C checks that the relation is not a by-product of the number of suppliers.
panA4 = { ...
    'Panel A: Mean log-productivity of all suppliers',       'Spearman', '',      'supProd', ''; ...
    'Panel B: Mean log-productivity of essential suppliers', 'Spearman', '',      'essProd', ''; ...
    'Panel C: Mean log-productivity of all suppliers, control: number of suppliers', ...
        'Spearman', 'newIn', 'supProd', ''};
[RHO, PV] = corrPanelSet(panA4, R, colOrder, tEndG, spans, rn, spanVar);
writeCorrTable(fullfile(tabDir,'tab_corr_sup.tex'), rowG, rowS, RHO, PV, panA4(:,1), spanHead, ...
    sprintf(['Spearman correlation between the proximity of the targeted category and the mean ' ...
    'log-productivity of the new firms'' suppliers (all suppliers in Panels A and C, essential suppliers ' ...
    'in Panel B), measured in the equilibrium before entry, by period of entry. Panel C controls for the ' ...
    'number of suppliers of the new firm. %s' starTxt 'Periods up to %s.'], baseTxt, tEndTxt), 'tab:corr_sup', ...
    'Period of entry', '0.75\textwidth');

%% =====================================================================
%% APPENDIX B: DISTRIBUTION AND CHARACTERISTICS OF CATEGORIES
%% =====================================================================
% Categories are rebuilt at the start of periods ncp, 2ncp, ... (mod(t+1,ncp) == 1), so a
% category is defined only between two re-categorizations. Each category is followed over one
% WINDOW: from the state at the end of period t0 (labels just rebuilt; t0 = 0 is the initial
% network) to the state at the end of period t0+ncp-1 (before the next re-categorization).
% One observation = one category in one window of one run. Only windows that end before t_end
% are used. Singleton categories are excluded from the homogeneity statistics, the binned
% figure and the regressions (their homogeneity is not defined).
xw = [0, ncp:ncp:Tmax]';                              % window start periods t0

% ---- Figure B1: dispersion across categories over time ----
winRows('figB1', {2,'CV of category size'; ...
                  4,{'SD of homogeneity','across categories'}; ...
                  5,{'SD of mean log-prod.','across categories'}}, ...
        R,tEndG,colors,names,tnames,colOrder,xw,ncp);

% ---- Figure B2: exit rate and net growth vs category characteristics (10 quantile bins) ----
catBinFigure('figB2', {'relProd','exitRate','Rel. mean log-productivity',{'Exit rate','within window (%)'}; ...
                       'homog',  'exitRate','Homogeneity',               {'Exit rate','within window (%)'}; ...
                       'logSize','netGrowth','Log category size',        {'Net growth','within window (%)'}}, ...
             R,tEndG,colors,names,tnames,colOrder,ncp,10);

% ---- Console: descriptive statistics of categories (all valid windows pooled) ----
fprintf('\nCATEGORY CHARACTERISTICS (category-windows, singletons included in counts)\n');
for c = 1:numel(colOrder)
    g = colOrder(c);
    for s = 1:3
        S = R(g,s).catS;  vw = (xw + ncp <= tEndG(g));
        V = catVars(R(g,s), tEndG(g), ncp, true);
        fprintf(['%-20s %s | categories/window %5.1f | singleton share %.3f | size mean %5.1f sd %5.1f ' ...
            '| homog mean %.2f sd %.2f | exit rate %.2f%% | net growth %.2f%%\n'], ...
            tnames{g}, names{s}, mean(S(vw,1,:),'all','omitnan'), mean(S(vw,3,:),'all','omitnan'), ...
            mean(V.size,'omitnan'), std(V.size,'omitnan'), mean(V.homog(V.size>1),'omitnan'), ...
            std(V.homog(V.size>1),'omitnan'), mean(V.exitRate,'omitnan'), mean(V.netGrowth,'omitnan'));
    end
end

% ---- Table B1: determinants of exit rates of categories ----
% OLS with run x window fixed effects (all variables demeaned within run-window), regressors
% standardized (coefficient = effect of one standard deviation, in percentage points of the
% category size at the start of the window), heteroskedasticity-robust (HC1) standard errors.
% Entry and growth of categories are not regressed: they mainly reflect the targeting rule.
regX     = {'logSize','homog','relProd','meanIn'};
regHeads = {'Log size','Homogeneity','Rel.\ productivity','Mean in-degree'};
B1 = nan(nRow, numel(regX));  P1 = B1;
row = 0;
for c = 1:numel(colOrder)
    g = colOrder(c);
    for s = 1:3
        row = row + 1;
        V = catVars(R(g,s), tEndG(g), ncp, false);
        X = cell2mat(cellfun(@(v) V.(v), regX, 'UniformOutput', false));
        y = V.exitRate;
        ok = all(~isnan(X),2) & ~isnan(y);
        [B1(row,:), P1(row,:)] = feOLS(y(ok), X(ok,:), V.grp(ok));
    end
end
disp(array2table(B1, 'RowNames', rn, 'VariableNames', regX))
writeCorrTable(fullfile(tabDir,'tab_cat_growth.tex'), rowG, rowS, B1, P1, {''}, regHeads, ...
    sprintf(['Determinants of exit rates of categories. One observation is a category between two ' ...
    're-categorizations (%d periods) in one run (%s). Exit rate: number of incumbents that exit within ' ...
    'the window, in \\%% of the category size at the start of the window. Regressors are measured at the ' ...
    'start of the window and standardized, so coefficients are the effects of one standard deviation in ' ...
    'percentage points; relative productivity is the mean log-productivity of the category minus the mean ' ...
    'over all firms. OLS with run $\\times$ window fixed effects and heteroskedasticity-robust standard ' ...
    'errors; singleton categories are excluded. ' starTxt 'Periods up to %s.'], ncp-1, runsTxt, tEndTxt), ...
    'tab:cat_exit', 'Exit rate (\%): category characteristics at the start of the window', '\textwidth');

%% ================= LOCAL FUNCTIONS (must stay at the END of the script) =================
function fname = simFile(g, s, k, tgt, scen)
% File name of run k: g = 1..3 INC results (targeting tgt(g)); g = 4 FNC results, random targeting.
% All files are read from the current folder.
    if g <= 3
        fname = sprintf('sim_%d_%d_%d.mat', tgt(g), scen(s), k);
    else
        fname = sprintf('sim_fnc_%d_%d_%d.mat', 0, scen(s), k);
    end
end
function tsRows(name, rows, R, tEndG, colors, names, tnames, cols)
% Figure with size(rows,1) rows x numel(cols) columns. A/B/C overlaid, mean + 95% CI.
% y-limits are shared across the INC columns (cols <= 3); the FNC column (4) keeps its own.
    if nargin < 8, cols = 1:3; end
    nc = numel(cols);
    isInc = cols <= 3;
    nr = size(rows,1);
    tl = prepFig(nr,nc);                              % final size BEFORE plotting
    for r = 1:nr
        ax = gobjects(1,nc);  M = cell(1,nc);
        for c = 1:nc
            g = cols(c);
            ax(c) = nexttile(tl,(r-1)*nc+c);
            [M{c},H] = tsAxes(R,g,rows{r,1},rows{r,2},tEndG(g),rows{r,4},colors,rows{r,5});
            xlim([0 max(tEndG(cols))])
            xline(tEndG(g), ':', 'Color', [0.4 0.4 0.4], 'HandleVisibility','off')
            if r == 1, title(tnames{g}); end
            if r == nr, xlabel('Time'); end
            if c == 1
                ylabel(rows{r,3});
                if r == 1, sharedLegend(tl,H,names); end
            end
        end
        syncLim(ax(isInc),'YLim')
        if rows{r,6} ~= 0                                % shade periods in which A is ahead of BOTH B and C
            for c = 1:nc
                yl = ylim(ax(c));
                if rows{r,6} > 0
                    d = M{c}{1} > M{c}{2} & M{c}{1} > M{c}{3};   % A higher than B and C
                else
                    d = M{c}{1} < M{c}{2} & M{c}{1} < M{c}{3};   % A lower than B and C (e.g. prices)
                end
                t = (1:numel(d))';
                a = area(ax(c), t, yl(1) + (yl(2)-yl(1))*double(d), yl(1), ...
                    'FaceColor', colors(1,:), 'FaceAlpha', 0.12, ...
                    'EdgeColor','none', 'HandleVisibility','off');
                uistack(a,'bottom');
                ylim(ax(c), yl)
            end
        end
    end
    finish(tl,name)
end

function [M,H] = tsAxes(R, g, field, tf, tEnd, tOff, colors, nonneg)
% Draws A/B/C means with 95% CI of the mean in the current axes.
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
% Opens a new figure at its EXACT printed size (width = \textwidth) and creates a compact
% tiled layout. Include the exported PDF in LaTeX WITHOUT scaling, so that the font size
% in the paper equals figFS:  \includegraphics{graphs/fig1.pdf}
    o = getappdata(0,'figOpts');
    if nargin < 3, hRow = 0.8*o.W/nc + 0.25; end         % panel height ~0.8 x panel width
    f = figure;
    set(f, 'Units','inches', 'Position', [1 1 o.W hRow*nr+0.35], 'Resize','off', 'Color','w');
    tl = tiledlayout(f, nr, nc, 'TileSpacing','compact', 'Padding','compact');
end
function finish(tl, name)
% One font size for all text, then export as vector PDF (graphs/<name>.pdf) at the size set by prepFig.
    o = getappdata(0,'figOpts');
    f = ancestor(tl,'figure');
    set(findall(f,'-property','FontSize'), 'FontSize', o.FS);
    set(findall(f,'Type','axes'), 'TitleFontSizeMultiplier',1, 'LabelFontSizeMultiplier',1, ...
        'TickLength',[0.02 0.02]);
    drawnow
    exportgraphics(f, fullfile(o.dir, [name '.pdf']), 'ContentType','vector');
end
function lg = sharedLegend(tl, h, s)
% One horizontal legend for the whole figure, placed above the panels (outside the axes),
% so it never covers data and never forces the panels to grow.
    o = getappdata(0,'figOpts');
    lg = legend(h, s, 'Orientation','horizontal', 'Box','off', 'FontSize', o.FS);
    lg.Layout.Tile = 'north';
    lg.ItemTokenSize = [15 8];
end

function syncLim(axs, prop)
    L = cell2mat(get(axs(:), prop));
    set(axs, prop, [min(L(:,1)) max(L(:,2))]);
end

function writeLatexTable(fname, rowG, rowS, D, heads, fmts, cap, lab, Hw, width)
% Writes a complete LaTeX table environment (requires graphicx and float).
%   rowG : regime/targeting label per row (printed only on the first row of a group)
%   rowS : innovation scenario label per row
%   D    : numeric data (one column per header), fmts: sprintf format per column
%   Hw   : optional 95% CI half-widths, printed in parentheses after each value
%   width: width of the table (default '\textwidth')
    if nargin < 9, Hw = []; end
    if nargin < 10, width = '\textwidth'; end
    nc  = size(D,2);
    fid = fopen(fname,'w');
    fprintf(fid,'\\begin{table}[H]\n\\centering\n\\caption{%s}\n\\label{%s}\n', cap, lab);
    fprintf(fid,'\\resizebox{%s}{!}{\n\\begin{tabular}{ll%s}\n\\hline\n', width, repmat('c',1,nc));
    hd = [{'Regime -- Targeting','Innovation Scenario'}, heads];
    hd = cellfun(@stackHead, hd, 'UniformOutput', false);
    fprintf(fid,'%s \\\\\n\\hline\n', strjoin(hd,' & '));
    for r = 1:size(D,1)
        newGroup = (r == 1) || ~strcmp(rowG{r}, rowG{r-1});
        if newGroup && r > 1, fprintf(fid,'\\hline\n'); end
        g = '';  if newGroup, g = rowG{r}; end
        v = cell(1,nc);
        for j = 1:nc
            v{j} = sprintf(fmts{j}, D(r,j));
            if ~isempty(Hw) && ~isnan(Hw(r,j))          % only cells with a CI get "(...)"
                v{j} = sprintf(['%s ($\\pm$' fmts{j} ')'], v{j}, Hw(r,j));
            end
        end
        fprintf(fid,'%s & %s & %s \\\\\n', g, rowS{r}, strjoin(v,' & '));
    end
    fprintf(fid,'\\hline\n\\end{tabular}\n}\n\\end{table}\n');
    fclose(fid);
    fprintf('LaTeX table written to %s\n', fname);
end

function bb = spanBars(C, L, U, colors, slabel)
% Grouped bars (time span x scenario) with error bars.
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
% Two-line header, split at the last space ("Innovation Scenario" -> Innovation / Scenario)
    k = find(h == ' ', 1, 'last');
    if isempty(k), return; end
    h = sprintf('\\begin{tabular}[c]{@{}c@{}}%s\\\\%s\\end{tabular}', h(1:k-1), h(k+1:end));
end

function corrFigure(name, ctype, ctrlVar, R, tEndG, colOrder, tnames, names, colors, spans, slabel)
% Correlation between entrants' log-productivity and the proximity of their targeted
% category, by period of entry. ctype = 'Spearman' (or 'Pearson').
% ctrlVar = ''        : simple correlation
%           'catProd' : partial correlation, controlling for the mean log-productivity
%                       of the firms in the target category
%           'newIn'   : partial correlation, controlling for the entrant's number of suppliers
% All variables are measured as deviations from their period-specific mean across runs.
    ctrl = ~isempty(ctrlVar);
    nSp = size(spans,1);
    nc  = numel(colOrder);
    tl = prepFig(2,nc);
    ax = gobjects(2,nc);
    for c = 1:nc
        g  = colOrder(c);
        tw = 1:min(tEndG(g)-1, size(R(g,1).proximity,1));
        Cp = nan(nSp,3);  Lp = Cp;  Up = Cp;          % pooled
        Cr = nan(nSp,3);  Lr = Cr;  Ur = Cr;          % per-run
        for s = 1:3
            P = R(g,s).proximity(tw,:);   X = R(g,s).newProd(tw,:);
            ok = ~isnan(P) & ~isnan(X) & ~(P >= 1);
            if ctrl
                Z  = R(g,s).(ctrlVar)(tw,:);              % control variable
                ok = ok & ~isnan(Z);
            end
            P(~ok) = NaN;  X(~ok) = NaN;
            Pd = P - mean(P,2,'omitnan');  Xd = X - mean(X,2,'omitnan');
            keep = ok & ~isnan(Pd) & ~isnan(Xd);
            if ctrl
                Z(~ok) = NaN;
                Zd = Z - mean(Z,2,'omitnan');
                keep = keep & ~isnan(Zd);
            end
            tIdx = repmat(tw(:), 1, size(P,2));
            nRun = size(P,2);
            nz   = double(ctrl);                              % number of control variables
            for q = 1:nSp
                mk = keep & tIdx >= spans(q,1) & tIdx <= spans(q,2);
                if nnz(mk) > 30                               % pooled estimate
                    if ctrl
                        rho = partialcorr(Pd(mk), Xd(mk), Zd(mk), 'Type', ctype);
                    else
                        rho = corr(Pd(mk), Xd(mk), 'Type', ctype);
                    end
                    z = atanh(rho);  sz = 1/sqrt(nnz(mk)-3-nz);
                    Cp(q,s) = rho;  Lp(q,s) = tanh(z-1.96*sz);  Up(q,s) = tanh(z+1.96*sz);
                end
                rr = nan(1,nRun);                             % per-run estimates
                for k = 1:nRun
                    m = mk(:,k);
                    if nnz(m) > 20
                        if ctrl
                            rr(k) = partialcorr(Pd(m,k), Xd(m,k), Zd(m,k), 'Type', ctype);
                        else
                            rr(k) = corr(Pd(m,k), Xd(m,k), 'Type', ctype);
                        end
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
        ax(1,c) = nexttile(tl,c);         bb = spanBars(Cp,Lp,Up,colors,slabel);
        title(tnames{g})
        if c == 1
            ylabel(sprintf('Pooled %s \\rho', lab));
            sharedLegend(tl,bb,names);
        end
        ax(2,c) = nexttile(tl,nc+c);      spanBars(Cr,Lr,Ur,colors,slabel);
        xlabel('Period of entry')
        if c == 1, ylabel(sprintf('Mean per-run %s \\rho', lab)); end
    end
    isInc = colOrder <= 3;
    tmp = ax(:,isInc);  syncLim(tmp(:),'YLim');          % FNC keeps own limits
    finish(tl,name)
end

function [RHO, PV] = corrPanelSet(panels, R, colOrder, tEndG, spans, rn, spanVar)
% Computes all panels of one correlation table (one row per regime-targeting x scenario,
% one column per period of entry) and prints them in the console.
%   panels : {title, correlation type, control(s), Y variable, X variable} per panel
    nPan = size(panels,1);
    nRow = numel(colOrder)*3;
    RHO  = nan(nRow, size(spans,1), nPan);  PV = RHO;
    for pnl = 1:nPan
        row = 0;
        for c = 1:numel(colOrder)
            g = colOrder(c);
            for s = 1:3
                row = row + 1;
                [RHO(row,:,pnl), PV(row,:,pnl)] = corrStats(R, g, s, tEndG, spans, ...
                    panels{pnl,2}, panels{pnl,3}, panels{pnl,4}, panels{pnl,5});
            end
        end
        fprintf('\n%s\n', panels{pnl,1});
        disp(array2table(RHO(:,:,pnl), 'RowNames', rn, 'VariableNames', spanVar))
    end
end

function [rho, pv] = corrStats(R, g, s, tEndG, spans, ctype, ctrlVar, yVar, xVar)
% Pooled (partial) correlation between a variable xVar (default 'proximity' = proximity of the
% target category) and an entrant variable yVar (default 'newProd' = the entrant's
% log-productivity), by period of entry, with p-values. Same data preparation as corrFigure.
%   ctrlVar : '' (no control), one field name, or a cell array of field names (several controls)
% Singleton categories (proximity >= 1) are always excluded, whatever xVar is.
    if nargin < 8 || isempty(yVar), yVar = 'newProd'; end
    if nargin < 9 || isempty(xVar), xVar = 'proximity'; end
    if ischar(ctrlVar) || isstring(ctrlVar)
        if strlength(ctrlVar) == 0, ctrlVar = {}; else, ctrlVar = {char(ctrlVar)}; end
    end
    nz  = numel(ctrlVar);                         % number of control variables
    ctrl = nz > 0;
    nSp = size(spans,1);
    rho = nan(1,nSp);  pv = rho;
    tw = 1:min(tEndG(g)-1, size(R(g,s).proximity,1));
    P = R(g,s).(xVar)(tw,:);   X = R(g,s).(yVar)(tw,:);
    Prox = R(g,s).proximity(tw,:);
    ok = ~isnan(P) & ~isnan(X) & ~(Prox >= 1);    % Prox >= 1: singleton categories excluded
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
        Z{j}(~ok) = NaN;
        Zd{j} = Z{j} - mean(Z{j},2,'omitnan');
        keep = keep & ~isnan(Zd{j});
    end
    tIdx = repmat(tw(:), 1, size(P,2));
    for q = 1:nSp
        mk = keep & tIdx >= spans(q,1) & tIdx <= spans(q,2);
        if nnz(mk) > 30
            if ctrl
                Zm = cell2mat(cellfun(@(v) v(mk), Zd, 'UniformOutput', false));   % one column per control
                [rho(q), pv(q)] = partialcorr(Pd(mk), Xd(mk), Zm, 'Type', ctype);
            else
                [rho(q), pv(q)] = corr(Pd(mk), Xd(mk), 'Type', ctype);
            end
        end
    end
end

function writeCorrTable(fname, rowG, rowS, RHO, PV, panels, heads, cap, lab, topHead, width)
% LaTeX table with one panel per specification (stacked vertically; requires adjustbox and float).
% Cells: coefficient with significance stars (*** p<0.01, ** p<0.05, * p<0.1).
% panels : panel titles ('' = no title row, for a table with a single panel)
% topHead: header spanning the value columns (default 'Period of entry')
% width  : maximum width of the table (default '\textwidth')
    if nargin < 10, topHead = 'Period of entry'; end
    if nargin < 11, width = '\textwidth'; end
    [nR, nc, nP] = size(RHO);
    fid = fopen(fname,'w');
    fprintf(fid,'\\begin{table}[H]\n\\centering\n\\caption{%s}\n\\label{%s}\n', cap, lab);
    fprintf(fid,'\\begin{adjustbox}{max width=%s}\n\\begin{tabular}{ll%s}\n\\hline\n', width, repmat('c',1,nc));
    fprintf(fid,'Regime -- Targeting & Scenario & \\multicolumn{%d}{c}{%s} \\\\\n', nc, topHead);
    fprintf(fid,'\\cline{3-%d}\n', nc+2);
    fprintf(fid,' & & %s \\\\\n\\hline\n', strjoin(heads,' & '));
    for p = 1:nP
        if p > 1, fprintf(fid,'\\hline\n'); end
        if ~isempty(panels{p})
            fprintf(fid,'\\multicolumn{%d}{l}{\\textit{%s}} \\\\\n', nc+2, panels{p});
        end
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
function [W, S] = catWindows(f, ncp, Tmax)
% Category characteristics per re-categorization window, for ONE run.
% Window w starts at the state "end of period t0" (index sA = t0+1; labels just rebuilt,
% t0 = 0: initial network) and ends at the state "end of period t0+ncp-1" (index sB = t0+ncp),
% i.e. just before the next re-categorization. Labels do not change inside the window
% (entrants keep the label of their target category).
% W : one row per category-window
%     [t0, category, size at start, size at end, entrants (survived entry period),
%      incumbent exits, homogeneity, essential inputs, rel. mean log-prod., mean in-degree, sB]
% S : one row per window (NaN if the window is incomplete)
%     [number of categories, CV of category size, share of singleton categories,
%      SD of homogeneity across categories (non-singletons), SD of rel. mean log-prod.]
    nT  = min(numel(f.s_growth), Tmax+1);
    xw  = [0, ncp:ncp:Tmax];
    S   = nan(numel(xw), 5);
    W   = zeros(0, 11);
    for w = 1:numel(xw)
        t0 = xw(w);  sA = t0 + 1;  sB = t0 + ncp;
        if sB > nT || sA > numel(f.s_cat_prox), continue; end
        lab  = f.s_firm_catlabels{sA}(:);  id  = f.s_firm_id{sA}(:);
        lp   = f.s_logprod{sA}(:);         ind = f.s_indegree{sA}(:);
        prox = f.s_cat_prox{sA}(:);        % start of period t0+1 = state sA (same labels)
        labB = f.s_firm_catlabels{sB}(:);  idB = f.s_firm_id{sB}(:);
        el   = f.entry_log(:, t0+1:sB-1);  % entry attempts inside the window
        cats = unique(lab)';
        Wk   = nan(numel(cats), 11);
        for q = 1:numel(cats)
            K   = cats(q);  mem = (lab == K);  n0 = sum(mem);
            ent = sum(el(2,:) == K & el(7,:) == 1);
            ex  = sum(~ismember(id(mem), idB));
            h   = prox(K);  if n0 < 2, h = NaN; end          % singleton: homogeneity undefined
            Wk(q,:) = [t0, K, n0, sum(labB == K), ent, ex, h, round(h*max(ind(mem))), ...
                       mean(lp(mem)) - mean(lp), mean(ind(mem)), sB];
        end
        W = [W; Wk]; %#ok<AGROW>
        sz = Wk(:,3);
        S(w,:) = [numel(cats), std(sz)/mean(sz), mean(sz == 1), std(Wk(:,7),'omitnan'), std(Wk(:,9))];
    end
end

function V = catVars(Rgs, tEnd, ncp, keepSingle)
% Pools the category-windows of all runs that end before tEnd and derives the variables
% used in Figure B2 and Table B1 (rates in % of the size at the start of the window).
    if nargin < 4, keepSingle = false; end
    Wm = vertcat(Rgs.catW{:});
    k  = Wm(:,11) <= tEnd;
    if ~keepSingle, k = k & Wm(:,3) >= 2; end
    Wm = Wm(k,:);
    V.size      = Wm(:,3);
    V.logSize   = log(Wm(:,3));
    V.homog     = Wm(:,7);
    V.nEss      = Wm(:,8);
    V.relProd   = Wm(:,9);
    V.meanIn    = Wm(:,10);
    V.entRate   = 100*Wm(:,5)./Wm(:,3);
    V.exitRate  = 100*Wm(:,6)./Wm(:,3);
    V.netGrowth = 100*(Wm(:,4) - Wm(:,3))./Wm(:,3);
    V.grp       = Wm(:,12)*1e5 + Wm(:,1);           % run x window
end

function [b, p] = feOLS(y, X, grp)
% OLS with group fixed effects (within transformation), standardized regressors and
% HC1 standard errors. Returns coefficients and two-sided p-values.
    [~,~,gi] = unique(grp);
    sdX = std(X, 0, 1);  sdX(sdX == 0) = NaN;
    Xd = zeros(size(X));
    for j = 1:size(X,2), Xd(:,j) = demeanBy(X(:,j), gi) / sdX(j); end
    yd = demeanBy(y, gi);
    Xd(:, isnan(sdX)) = [];                          % drop constant regressors
    n = numel(yd);  kx = size(Xd,2);
    df = n - kx - max(gi);                           % fixed effects use one df per group
    bb = Xd \ yd;  e = yd - Xd*bb;
    XXi = inv(Xd'*Xd);
    Vb  = XXi * (Xd' * (Xd .* e.^2)) * XXi * n/max(df,1);
    pp  = 2*tcdf(-abs(bb ./ sqrt(diag(Vb))), max(df,1));
    b = nan(1, size(X,2));  p = b;
    b(~isnan(sdX)) = bb;    p(~isnan(sdX)) = pp;
end

function winRows(name, rows, R, tEndG, colors, names, tnames, cols, xw, ncp)
% Time series over re-categorization windows (x = window start t0). A/B/C overlaid,
% mean over runs and 95% CI. rows: {column of catS, ylabel}.
    nc = numel(cols);  nr = size(rows,1);  isInc = cols <= 3;
    tl = prepFig(nr,nc);
    for r = 1:nr
        ax = gobjects(1,nc);
        for c = 1:nc
            g = cols(c);
            ax(c) = nexttile(tl,(r-1)*nc+c); hold on
            vw = (xw + ncp <= tEndG(g));
            H = gobjects(1,3);
            for s = 1:3
                X = reshape(R(g,s).catS(vw, rows{r,1}, :), sum(vw), []);
                t = xw(vw);
                n = sum(~isnan(X),2);
                m = mean(X,2,'omitnan');
                h = tinv(0.975, max(n-1,1)) .* std(X,0,2,'omitnan') ./ sqrt(n);
                ok = ~isnan(m) & ~isnan(h);
                fill([t(ok); flipud(t(ok))], [m(ok)-h(ok); flipud(m(ok)+h(ok))], colors(s,:), ...
                    'FaceAlpha',0.2, 'EdgeColor','none', 'HandleVisibility','off');
                H(s) = plot(t, m, '-o', 'Color', colors(s,:), 'LineWidth', 1.2, ...
                    'MarkerSize', 2, 'MarkerFaceColor', colors(s,:));
            end
            xlim([0 max(tEndG(cols))])
            if r == 1, title(tnames{g}); end
            if r == nr, xlabel('Start of window'); end
            if c == 1
                ylabel(rows{r,2});
                if r == 1, sharedLegend(tl,H,names); end
            end
        end
        syncLim(ax(isInc),'YLim')
    end
    finish(tl,name)
end

function catBinFigure(name, rows, R, tEndG, colors, names, tnames, cols, ncp, nBin)
% Binned scatter: category-windows of all runs pooled, x split into nBin quantile bins;
% mean of y per bin with 95% CI. rows: {x variable, y variable, xlabel, ylabel}.
    nc = numel(cols);  nr = size(rows,1);  isInc = cols <= 3;
    tl = prepFig(nr,nc);
    for r = 1:nr
        ax = gobjects(1,nc);
        for c = 1:nc
            g = cols(c);
            ax(c) = nexttile(tl,(r-1)*nc+c); hold on
            H = gobjects(1,3);
            for s = 1:3
                V = catVars(R(g,s), tEndG(g), ncp, false);
                x = V.(rows{r,1});  y = V.(rows{r,2});
                ok = ~isnan(x) & ~isnan(y);  x = x(ok);  y = y(ok);
                ed = unique(quantile(x, linspace(0,1,nBin+1)));
                if numel(ed) < 3, continue; end
                [~,~,b] = histcounts(x, ed);  k = b > 0;
                nb = accumarray(b(k), 1);
                xm = accumarray(b(k), x(k), [], @mean);
                ym = accumarray(b(k), y(k), [], @mean);
                ys = accumarray(b(k), y(k), [], @std);
                hw = tinv(0.975, max(nb-1,1)) .* ys ./ sqrt(nb);
                H(s) = errorbar(xm, ym, hw, '-o', 'Color', colors(s,:), 'LineWidth', 1.2, ...
                    'MarkerSize', 2, 'MarkerFaceColor', colors(s,:), 'CapSize', 2);
            end
            if r == 1, title(tnames{g}); end
            xlabel(rows{r,3})
            if c == 1
                ylabel(rows{r,4});
                if r == 1, sharedLegend(tl,H,names); end
            end
        end
        syncLim(ax(isInc),'YLim')
    end
    finish(tl,name)
end

function v = demeanBy(v, gi)
% Subtracts the group mean (groups given by the index vector gi).
    m = accumarray(gi, v, [], @mean);
    v = v - m(gi);
end