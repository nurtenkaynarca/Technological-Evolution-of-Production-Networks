function generateSimulationFiles(t_s, index_targeting, index_innovation, ...
    lambda_0, lambda_0_new,  T_mature, lambda_1, ncp, index_save, index_nc)
% GENERATESIMULATIONFILES  Simulates how a network of firms that buy inputs from
% each other changes over time, when one new firm tries to enter the economy in
% every period. The results of one simulation run are saved to a .mat file.
%
% =========================================================================
% KEY TERMS 
% =========================================================================
%   supplier / customer : if firm i buys an input from firm j, then j is a
%                         SUPPLIER of i and i is a CUSTOMER of j.
%   A (adjacency matrix): an n_f x n_f table of zeros and ones, where n_f is the
%                         number of firms. A(i,j) = 1 means "firm i buys from
%                         firm j".
%   in-degree           : number of suppliers of a firm  (= sum of its row in A)
%   out-degree          : number of customers of a firm  (= sum of its column in A)
%   category            : a group of firms that use similar inputs, roughly
%                         an "industry". Firms are regrouped every ncp periods.
%   essential inputs    : suppliers used by EVERY firm in a category, i.e. the
%                         standard inputs needed to make that kind of product.
%   optional inputs     : suppliers used by some, but not all, firms in a category.
%   proximity           : a number that measures how similar the firms of a
%                         category are (also called "homogeneity"); see below.
%
% =========================================================================
% INPUTS
% =========================================================================
%   t_s              : number of this simulation run (Monte Carlo repetition).
%   index_targeting  : how the entrant chooses the category it enters. Only
%                      categories that are not empty AND have at least one
%                      essential input (proximity > 0) can be targeted.
%                      0 = random: every such category has the same chance
%                      1 = productivity: the chance is proportional to the
%                          category's mean log-productivity, so more productive
%                          categories are chosen more often
%                      2 = homogeneity: the chance is proportional to the
%                          category's proximity, so categories whose firms use
%                          very similar inputs are chosen more often
%   index_innovation : how widely the entrant searches for its suppliers
%                      0 = Scenario A, "local search": the entrant only uses
%                          suppliers that firms of its category already use
%                          (essential + optional inputs)
%                      1 = Scenario B, "broad search": as in A, plus it may add
%                          ONE extra supplier chosen from any firm in the economy
%                      2 = Scenario C, "recent search": as in A, plus it may add
%                          ONE extra supplier chosen among the firms that entered
%                          during the last c_size periods
%   lambda_0         : basic productivity level of the incumbent firms (a constant
%                      that every initial firm has, independently of suppliers)
%   lambda_0_new     : basic productivity level of NEW firms (entrants),
%                      may be different than lambda_0, i.e. new firms start at a
%                      disadvantage. It is used when the entrant chooses its
%                      suppliers, when customers decide whether to buy from it,
%                      and whenever the productivity of all firms is recomputed
%                      (each firm always uses its own basic level).
%   T_mature         : number of periods after which a new firm "matures": its
%                      basic productivity level is raised from lambda_0_new to
%                      lambda_0. A firm that entered in period t0 is upgraded at
%                      the start of period t0 + T_mature. Use Inf to never upgrade.
%   lambda_1         : strength of technological spillovers, i.e. how much a
%                      firm's productivity increases with the productivity of
%                      its suppliers (the paper uses 0.004)
%   ncp              : number of periods between two regroupings of firms into
%                      categories (regrouping happens when mod(t+1,ncp) == 1,
%                      i.e. at the start of periods ncp, 2*ncp, 3*ncp, ...)
%   index_save       : 0 = do not save the weight matrices s_W (smaller files)
%                      1 = also save the weight matrices s_W
%   index_nc         : how the number of categories is set at each regrouping
%                      1 = increasing (INC): number of categories =
%                          round(n_f/c_size), i.e. about one category per c_size
%                          firms, so the number of categories grows with the
%                          economy (this is the default if the input is omitted)
%                      0 = fixed (FNC): the number of categories stays at its
%                          initial value from i_data_ar.mat, so the categories
%                          themselves become larger as firms enter
%
% =========================================================================
% PRODUCTIVITY FORMULA (eq. 12 of the paper, as implemented here)
% =========================================================================
%   log-productivity = (I - lambda_1*A)^(-1) * lam0_v  +  eps
%   where I is the identity matrix and lam0_v is the vector of basic productivity
%   levels (lambda_0 for initial and matured firms, lambda_0_new for young entrants).
%   - The first term is the "structural" part. It solves
%         a_i = lam0_v(i) + lambda_1 * (sum of a_j over the suppliers j of firm i),
%     so productivity is passed on along supplier chains (a supplier's supplier
%     also matters, but less).
%   - eps is a random shock drawn from an exponential distribution with mean 0.5.
%     It is ADDED OUTSIDE the inverse, so a firm's shock does not spread to its
%     customers. It is generated as -0.5*log(rand), which has exactly the same
%     distribution as exprnd(0.5).
%
% =========================================================================
% CATEGORY PROXIMITY (homogeneity)
% =========================================================================
%   proximity of a category = (number of suppliers used by ALL firms of the
%   category) / (largest number of suppliers of any firm of the category).
%   It is between 0 and 1 for categories with two or more firms: 1 means all firms
%   use exactly the same inputs, 0 means they have no input in common.
%   (Note: a category with a single firm gets a value slightly above 1, because
%   the firm's own column is counted as "shared"; see categoryProximity below.)
%
% =========================================================================
% OUTPUT
% =========================================================================
%   A .mat file named
%     "sim_<index_targeting>_<index_innovation>_<t_s>.mat"      if index_nc = 1 (INC)
%     "sim_fnc_<index_targeting>_<index_innovation>_<t_s>.mat"  if index_nc = 0 (FNC)
%   containing the following variables. Most of them are cell arrays with T+1 cells:
%   cell 1 = initial economy, cell t+1 = economy at the end of period t.
%     s_W              : weight matrix W (share of a firm's input spending on each
%                        supplier); only if index_save = 1
%     s_idxfirms       : position index of each firm; only if index_save = 1
%     s_logprod        : log-productivity of every firm
%     s_logprices      : log-price of every firm
%     s_growth         : log real GDP of the economy (one number per state)
%     s_firm_catlabels : category of every firm
%     s_firm_id        : permanent id of every firm (ids never change, so they can
%                        be used to follow a firm over time, even though its
%                        position in A changes when other firms exit)
%     s_indegree       : number of suppliers of every firm
%     s_outdegree      : number of customers of every firm
%   In every cell, firms are listed in the same order as the rows of A at that time.
%
%     s_cat_prox  : T cells. Cell t = proximity of every category at the START of
%                   period t, i.e. before that period's entrant arrives.
%     entry_log   : 13 x T matrix, one column per period (see below).
%
%
%   entry_log records EVERY entry attempt, including failed ones, and its columns
%   are never deleted:
%     row 1 : period
%     row 2 : id of the category the entrant targeted (NaN if no category could
%             be targeted in this period, i.e. no attempt took place)
%     row 3 : proximity of that category before the entry attempt (NaN if no
%             category could be targeted)
%     row 4 : proximity of that category after the entry and the exits (computed
%             even if the entrant itself exited; NaN if the entry failed)
%     row 5 : number of incumbent firms that exited in this period
%             (NaN if the entry failed)
%     row 6 : was the entry successful, i.e. did at least one customer start
%             buying from the entrant? (1 = yes, 0 = no)
%     row 7 : was the entrant still in the network at the end of its entry period?
%             (1 = yes, 0 = no; NaN if the entry failed)
%     row 8 : period in which the entrant left the network (NaN if it is still
%             alive at the end of the simulation, or if the entry failed)
%     row 9 : permanent id of the entrant (NaN if the entry failed); use it to
%             find the firm in s_firm_id
%     row 10: number of essential suppliers of the entrant (recorded for every
%             attempt, also failed ones; NaN if no category could be targeted)
%     row 11: mean log-productivity of the entrant's suppliers (period t-1 values)
%     row 12: mean log-productivity of its essential suppliers (period t-1 values)
%     row 13: number of optional inputs available in the target category

% If index_nc is not given, use the increasing number of categories (INC), so that
% older calls with only 9 inputs behave exactly as before.
if nargin < 10 || isempty(index_nc), index_nc = 1; end
if ~ismember(index_nc, [0 1]), error('index_nc must be 0 or 1.'); end

%% ------------------------------------------------------------------------
%% 1. LOAD THE INITIAL NETWORK AND PARAMETERS
%% ------------------------------------------------------------------------
data = load("i_data_ar.mat");

A               = data.A;               % who buys from whom: A(i,j)=1 if firm i buys from firm j
W               = data.W;               % spending shares: each row of A divided by its sum, so a firm
                                        % spends the same share of its input budget on each supplier
idx_firms       = data.idxfirms;        % position index of each firm
firm_catlabels  = data.firm_catlabels;  % category of each firm (firms with similar inputs share a category)
c_size          = data.c_size;          % target category size (50 firms); also the length of the
                                        % "recent entrants" window used in Scenario C
n_f             = data.n_f;             % current number of firms
n_categories    = data.n_categories;    % current number of categories
alpha           = data.alpha;           % labour share of costs (0.6); intermediate inputs are 1-alpha
eps_v           = data.eps_v;           % initial random productivity shocks, one per firm
% entry_t stores the entry information of every firm currently in the network,
% one column per firm. Rows: [entry period; category id; proximity before entry;
% proximity after entry; number of exits; number of essential suppliers].
% Initial firms: entry period 0, all other rows NaN (not applicable).
entry_t         = [zeros(1,n_f); nan(5,n_f)];

%% ------------------------------------------------------------------------
%% 2. INITIAL ECONOMY: PRODUCTIVITIES, PRICES, GDP
%% ------------------------------------------------------------------------

In = speye(n_f);                     % identity matrix (sparse, to save memory)
lam0_v = lambda_0 * ones(n_f,1);     % basic productivity level of each firm (one value per firm,
                                     % same order as the rows of A); all initial firms get lambda_0
% Structural productivity: solves a = lam0_v + lambda_1*A*a, i.e. each firm's basic
% level plus lambda_1 times the summed productivity of its suppliers.
logproductivity_raw = (In - lambda_1*sparse(A)) \ lam0_v;
% Actual productivity = structural part + the firm's own random shock.
% The shock is added here, outside the network formula, so it does not spread.
logproductivity = logproductivity_raw + eps_v;
% Equilibrium log-prices. Each price satisfies p = (1-alpha)*W*p - logproductivity
% (a firm's price = (1-alpha) x weighted average price of its suppliers minus its
% productivity). Solving for p gives p = -(I-(1-alpha)W)^(-1) * logproductivity.
logprices = (In - (1-alpha)*W) \ (-logproductivity);
% Log real GDP. Households spend equally on all goods, so real income is higher
% when prices are lower: log real GDP = minus the average log-price.
logrealva = -mean(logprices);
gamma = 1;               % targeting intensity: the category weights used in the entrant's
                         % choice are raised to this power (used if index_targeting is 1 or 2);
                         % gamma = 1 means the chance is simply proportional to the weight

T = 750;                % number of periods to simulate (one entry attempt per period)

A = double(A);
A(1:size(A,1)+1:end) = 0;    % set the diagonal of A to zero: no firm buys from itself

%% ------------------------------------------------------------------------
%% 3. STORAGE FOR RESULTS (cell 1 = initial economy, cell t+1 = end of period t)
%% ------------------------------------------------------------------------
if index_save == 1
s_W=cell(T+1,1);
s_idxfirms=cell(T+1,1);
end
s_logprod=cell(T+1,1);
s_logprices=cell(T+1,1);
s_growth=cell(T+1,1);
s_firm_catlabels=cell(T+1,1);
s_firm_id   = cell(T+1,1);   % permanent firm ids, in the same order as the rows of A
s_cat_prox  = cell(T,1);     % proximity of every category at the start of period t (before the entrant)
s_indegree  = cell(T+1,1);
s_outdegree = cell(T+1,1);

% Permanent firm ids. When firms exit, they are removed from A and the remaining
% firms move up, so a firm's position (row number) changes over time. Its id does
% not: ids are removed together with the firms but never reused or renumbered.
firm_id   = 1:n_f;          % initial firms get ids 1, 2, ..., n_f
next_id   = n_f + 1;        % id that the next successful entrant will receive
% One column per period for the entry attempt of that period. Failed attempts are
% included and columns are never deleted. Everything starts as NaN (unknown).
entry_log = nan(13,T);                    
% Save the initial economy (cell 1)
if index_save == 1
s_W{1} = sparse(W);
s_idxfirms{1} = idx_firms;
end
s_logprod{1} = logproductivity;
s_logprices{1} = logprices;
s_growth{1} = logrealva;
s_firm_catlabels{1} = firm_catlabels;
s_firm_id{1} = firm_id;
s_indegree{1}  = sum(A,2);   % number of suppliers of each firm = sum of its row of A
s_outdegree{1} = sum(A,1)';  % number of customers of each firm = sum of its column of A

%% ------------------------------------------------------------------------
%% 4. MAIN LOOP: ONE ENTRY ATTEMPT PER PERIOD
%% ------------------------------------------------------------------------
for t = 1:T
    
    %% --- 4.0 UPGRADE THE BASIC PRODUCTIVITY OF MATURED ENTRANTS ---------
    % A new firm starts with the lower basic level lambda_0_new. Once T_mature
    % periods have passed since its entry, it is upgraded to lambda_0, the level
    % of the initial firms. Row 1 of entry_t is the entry period (0 = initial firm,
    % which is never upgraded). The last condition skips firms already upgraded.
    matured = (entry_t(1,:) > 0) & (t - entry_t(1,:) >= T_mature) & (lam0_v(:)' ~= lambda_0);
    if any(matured)
        lam0_v(matured) = lambda_0;
        % Recompute productivities, prices and GDP with the upgraded levels.
        % The current random shocks (eps_v) are KEPT, so the only change in
        % productivity comes from the upgrade.
        In = speye(n_f);
        logproductivity_raw = (In - lambda_1*sparse(A)) \ lam0_v(:);
        logproductivity = logproductivity_raw + eps_v;
        logprices = (In - (1-alpha)*W) \ (-logproductivity);
        logrealva = -mean(logprices);
    end

    %% --- 4.1 REGROUPING FIRMS INTO CATEGORIES -------------------------
    % Every ncp periods, firms are regrouped into categories of firms that use
    % similar inputs. The similarity of two groups is the number of suppliers they
    % have in common divided by the larger of their numbers of suppliers.
    % The procedure starts with every firm in its own group and then repeatedly
    % merges the two most similar groups, one pair at a time, until the target
    % number of categories is reached. The target is round(n_f/c_size) if
    % index_nc == 1 (INC: about one category per c_size firms), or it stays at its
    % initial value if index_nc == 0 (FNC).

    if mod(t+1,ncp) == 1
        if index_nc == 1
            n_categories = round(n_f/c_size);   % INC: more firms -> more categories
        end                                     % FNC: keep the number of categories unchanged
        D = sum(A,2);                        % number of suppliers of each group (at first, each firm)
        C = A;  C(1:n_f+1:end) = 1;          % C(g,:) = inputs of group g. The diagonal is set to 1 so
                                             % that a firm's own product counts as one of its "positions"
        cat_c = num2cell(1:n_f);             % list of groups; at first every firm is its own group
        nCat  = n_f;                         % current number of groups
        % S(i,j) = similarity between groups i and j
        %        = (number of common inputs) / (larger number of inputs of the two).
        % C*C' counts, for every pair of groups, the inputs they share.
        % max(...,1) avoids dividing by zero for firms without suppliers.
        S = (C*C') ./ max(max(D,D'),1);
        S(1:nCat+1:end) = -inf;              % a group cannot be merged with itself

        while nCat > n_categories
            % Find the most similar pair of groups. If several pairs are equally
            % similar, the pair that appears LAST in S is taken: S is flipped
            % (reversed in both directions), max() returns the first maximum of the
            % flipped matrix, and that is the last maximum of the original one.
            Sf = S(end:-1:1, end:-1:1);
            [~, k] = max(Sf(:));
            [rr, cc] = ind2sub(size(Sf), k);
            x = nCat + 1 - rr;                   % convert the positions back to the
            y = nCat + 1 - cc;                   % original (unflipped) numbering
            if x > y, [x, y] = deal(y, x); end   % keep the smaller number x; group y is merged into x

            % Merge group y into group x:
            % - the members of both groups are put together;
            % - the inputs of the merged group are only the inputs that BOTH groups
            %   have (multiplying two 0/1 rows keeps a 1 only where both are 1);
            % - its number of suppliers is the larger of the two.
            cat_c{x} = sort([cat_c{x}, cat_c{y}]);
            C(x,:)   = C(x,:) .* C(y,:);
            D(x)     = max(D(x), D(y));

            % Delete group y from all lists, since it now belongs to group x.
            cat_c(y) = [];  C(y,:) = [];  D(y) = [];
            S(y,:)   = [];  S(:,y) = [];
            nCat = nCat - 1;

            % Recompute the similarity between the merged group x and every other
            % group (all other similarities are unchanged).
            s = (C*C(x,:)') ./ max(max(D, D(x)), 1);
            s(x) = -inf;
            S(x,:) = s';
            S(:,x) = s;
        end

        % Turn the list of groups into one category number per firm.
        firm_catlabels = zeros(1,n_f);
        for i = 1:numel(cat_c)
            firm_catlabels(cat_c{i}) = i;
        end
        clear C D S nCat cat_c Sf            % remove temporary variables
    end

    %% --- 4.1b CATEGORY PROXIMITY (before the entrant arrives) ---------
    % The proximity of every category is computed at the start of the period, so
    % s_cat_prox{t} describes the network as it is BEFORE this period's entry attempt.
    cat_prox = categoryProximity(A, firm_catlabels, n_categories);
    s_cat_prox{t} = cat_prox;

    %% --- 4.2 WHICH CATEGORY DOES THE ENTRANT TRY TO ENTER? -----------
    lab = firm_catlabels(:);
    cnt = accumarray(lab, 1, [n_categories 1]);          % number of firms in each category
    % Categories that can be targeted: not empty AND with at least one essential
    % input (proximity > 0). A category whose firms share no input has no standard
    % technology for a new firm to build on, so it is never targeted. Proximity is 0
    % exactly when a category has no essential input, because categoryProximity
    % counts common inputs with the same rule as the essential inputs in 4.3.
    ok  = cnt > 0 & cat_prox(:) > 0;

    if ~any(ok)
        % No category can be targeted, so there is no entry attempt in this period.
        % The economy stays unchanged: record the period (rows 2, 3 and 10 stay NaN),
        % save the state as in 4.6 and go to the next period.
        entry_log(1,t) = t;
        entry_log(6,t) = 0;
        if index_save == 1
            s_W{t+1} = sparse(W);
            s_idxfirms{t+1} = idx_firms;
        end
        s_logprod{t+1}        = logproductivity;
        s_logprices{t+1}      = logprices;
        s_growth{t+1}         = logrealva;
        s_firm_catlabels{t+1} = firm_catlabels;
        s_firm_id{t+1}        = firm_id;
        s_indegree{t+1}       = sum(A,2);
        s_outdegree{t+1}      = sum(A,1)';
        continue
    end

    if index_targeting == 0
        % RANDOM targeting: every category that can be targeted has the same chance.
        eligible = find(ok);
        t_cat = eligible(randi(numel(eligible)));

    else
        % WEIGHTED targeting ("roulette wheel"): each category gets a weight w, and
        % its chance of being chosen is its weight divided by the sum of all weights.
        % Categories that cannot be targeted get weight 0, so they are never chosen.
        w = zeros(n_categories,1);
        if index_targeting == 1
            % PRODUCTIVITY targeting: weight = mean log-productivity of the
            % category's firms (raised to the power gamma).
            sm = accumarray(lab, logproductivity(:), [n_categories 1]);   % sum of log-productivity per category
            w(ok) = (sm(ok)./cnt(ok)).^gamma;
        elseif index_targeting == 2
            % HOMOGENEITY targeting: weight = proximity of the category (raised to
            % the power gamma), so categories of very similar firms are preferred.
            w(ok) = cat_prox(ok).^gamma;
        else
            error('index_targeting must be 0, 1 or 2.');
        end
        % Draw the category: cp holds the cumulative chances (they increase from
        % near 0 to 1). A uniform random number between 0 and 1 is drawn, and the
        % first category whose cumulative chance reaches that number is chosen.
        cp = cumsum(w/sum(w));  cp(end) = 1;             % cp(end)=1 guards against rounding errors
        t_cat = find(rand <= cp, 1, 'first');
    end
    t_cat_firms = find(firm_catlabels==t_cat);           % incumbent firms of the chosen category
    % Record the attempt. The entry is marked as failed (row 6 = 0) for now and
    % changed to 1 below if a customer adopts the entrant.
    entry_log(1:3,t) = [t; t_cat; cat_prox(t_cat)];
    entry_log(6,t)   = 0;

    %% --- 4.3 THE ENTRANT CHOOSES ITS SUPPLIERS ------------------------
    % ESSENTIAL inputs = suppliers used by ALL firms of the chosen category (the
    % standard inputs needed to make this kind of product). A firm cannot buy from
    % itself, so if a category member is itself used by all OTHER members, it would
    % be missed. To avoid this, each firm's own column is set to 1 before checking.
    nc = numel(t_cat_firms);
    R = A(t_cat_firms,:);                            % rows of A for the category's firms
    R(sub2ind(size(R), 1:nc, t_cat_firms)) = 1;      % each firm's own column set to 1
    K_essentials = find(all(R,1));                   % columns that are 1 for every firm
    n_ess = numel(K_essentials);          % number of essential suppliers of the entrant
    entry_log(10,t) = n_ess;              % essential suppliers of this period's entrant
    % OPTIONAL inputs = suppliers used by at least one, but not all, firms of the category.
    K_other = setdiff(find(any(A(t_cat_firms,:),1)), K_essentials);

    % The entrant always buys all essential inputs.
    new_suppliers = K_essentials;
    k  = numel(new_suppliers);                       % number of essential suppliers
    % Safety check: only categories with at least one essential input can be
    % targeted (see 4.2), so k must be positive here.
    assert(k > 0, 'The target category has no essential inputs');
    % Sums used below to compute the entrant's price quickly. The productivity of a
    % supplier is its ACTUAL productivity (structural part + its shock).
    Sp = sum(logproductivity(new_suppliers));        % summed log-productivity of the essential suppliers
    Sq = sum(logprices(new_suppliers));              % summed log-price of the essential suppliers

    % STARTING OPTION: essential suppliers only.
    %   log-productivity = basic level + lambda_1 * (summed suppliers' log-productivity) + shock
    %   log-price        = (1-alpha) * average supplier log-price - log-productivity
    % Only this starting option gets a random positive shock (e_shock). It represents
    % the advantage of using the standard, well-known inputs of the category. The
    % alternative supplier sets tested below get NO shock, because they are new
    % combinations whose result is uncertain.
    e_shock = -0.5*log(rand);            % random shock, exponential with mean 0.5
    lambda_e = lambda_0_new;             % the entrant's basic productivity level
    logproductivity_e =  lambda_e + lambda_1*Sp + e_shock;
    logprice_e = ((1-alpha)/k)*Sq - logproductivity_e;

    % ALTERNATIVE OPTIONS (all scenarios): essential inputs plus m optional inputs,
    % for m = 1, 2, ..., 10 (or fewer if there are fewer optional suppliers).
    % For a given m, the entrant's log-price can be written as
    %   (1-alpha)/(k+m) * Sq - (basic level + lambda_1*Sp)
    %   + the sum, over the m chosen optional suppliers j, of
    %     [ (1-alpha)/(k+m) * price_j - lambda_1 * productivity_j ]
    % The term in brackets is a "score" that depends only on supplier j itself, so
    % the best m suppliers are simply the m suppliers with the lowest scores. This
    % finds the same best set as trying every possible combination, but much faster.
    % Each option is kept if its price is at least as low as the best price found so
    % far (so if two options are equally cheap, the one with more suppliers is kept).
    if ~isempty(K_other)
        prO = logprices(K_other);
        prO = prO(:);                                % log-prices of the optional suppliers
        lpO = logproductivity(K_other);
        lpO = lpO(:);                                % log-productivities of the optional suppliers
        for m = 1:min(10,numel(K_other))
            cscore = (1-alpha)/(k+m)*prO - lambda_1*lpO;   % score of each optional supplier
            [cs, ord] = mink(cscore, m);                   % the m lowest scores and their positions
            val = ((1-alpha)/(k+m))*Sq - (lambda_e + lambda_1*Sp) + sum(cs);   % entrant's log-price
            if val <= logprice_e
                chosen = K_other(ord);
                new_suppliers = union(K_essentials, chosen);
                logproductivity_e =  lambda_e + lambda_1*(Sp + sum(lpO(ord)));
                logprice_e = val;
            end
        end
    end
    new_suppliers = new_suppliers(:)';               % make it a row vector

    % ONE EXTRA SUPPLIER (Scenarios B and C only): the entrant may add one more
    % supplier from a wider group of firms, if this makes it cheaper.
    %   B: any firm in the economy
    %   C: only firms that entered during the last c_size periods
    % In both cases, firms that are already suppliers of the entrant and the
    % category's optional suppliers (already tried above) are excluded.
    if index_innovation == 1
        cand = 1:n_f;
    elseif index_innovation == 2
        cand = find(entry_t(1,:) > 0 & t - entry_t(1,:) <= c_size);   % row 1 of entry_t = entry period
    end

    if index_innovation > 0
        cand = setdiff(cand, [new_suppliers K_other]);
        [new_suppliers, logproductivity_e, logprice_e] = addOne(new_suppliers, ...
        cand, logproductivity, logprices, alpha, lambda_1, lambda_e, ...
        logproductivity_e, logprice_e);
    end

    % Productivity of the entrant's suppliers as used in its evaluation (equilibrium
    % of period t-1). Together with the number of suppliers (in-degree), this splits
    % the entrant's productivity into a quantity and a quality component.
    entry_log(11,t) = mean(logproductivity(new_suppliers));   % mean log-productivity of all its suppliers
    entry_log(12,t) = mean(logproductivity(K_essentials));    % mean log-productivity of its essential suppliers
    entry_log(13,t) = numel(K_other);                         % number of optional inputs it could choose from

    % Add the entrant to the economy for now, as firm number n_f+1 (the last row and
    % column of A), with its chosen productivity, price and suppliers. It will be
    % removed again below if no customer wants to buy from it.
    logproductivity(n_f+1) = logproductivity_e;
    logprices(n_f+1)       = logprice_e;
    lam0_v(n_f+1,1)        = lambda_e;

    % Safety check: the same supplier must not appear twice in the list.
    assert(numel(new_suppliers) == numel(unique(new_suppliers)), ...
        'Duplicate firm in the entrant''s supplier set');

    A(n_f+1,new_suppliers) = 1;   % the entrant buys from its chosen suppliers
    A(:,n_f+1) = 0;               % nobody buys from the entrant yet

    %% --- 4.4 DO CUSTOMERS START BUYING FROM THE ENTRANT? --------------
    % Potential customers = firms that currently buy from at least one firm of the
    % chosen category. Each of them compares its current price with the price it
    % would have if it bought from the entrant, and switches if that is cheaper.
    K_customers = find(any(A(1:n_f,t_cat_firms),2))';
    % One random shock is drawn for this round and used for every option of every
    % customer in this period, so the comparison between options is not affected
    % by different random draws.
    eps_i = -0.5*log(rand);
    for ci = 1:numel(K_customers)
        c = K_customers(ci);
        % The customer's own essential inputs: the suppliers used by every firm of
        % the customer's category (computed as in 4.3). The customer itself is
        % removed from this list, because a firm cannot buy from itself.
        % Essential inputs are never dropped.
        c_cat = firm_catlabels(c);
        c_cat_firms = find(firm_catlabels==c_cat);
        nc = numel(c_cat_firms);
        R = A(c_cat_firms,:);
        R(sub2ind(size(R), 1:nc, c_cat_firms)) = 1;
        c_cat_essentials = find(all(R,1));
        c_cat_essentials = setdiff(c_cat_essentials,c);

        Ic = find(A(c,:));             % current suppliers of the customer
        suppliers_i = Ic;              % by default, keep the current suppliers
        logprice_i = logprices(c);     % current price of the customer (the price to beat)
        % Suppliers that may be changed: the customer's current non-essential
        % suppliers, plus the entrant (n_f+1) as a new possibility.
        i_othersuppliers = union(setdiff(Ic,c_cat_essentials), n_f+1);

        % Two kinds of options are tested (essential suppliers are always kept):
        %   j = nO-1 : leave out ONE of the changeable suppliers. Leaving out the
        %              entrant gives back the current set; leaving out an old
        %              supplier means the entrant REPLACES that supplier.
        %   j = nO   : keep all of them, i.e. ADD the entrant to the current suppliers.
        % The subsets are built directly instead of with nchoosek, which behaves
        % differently when it receives a single number instead of a vector.
        nO = numel(i_othersuppliers);                    % number of changeable suppliers (entrant included)
        for j = nO-1:nO
            if j > 0                                     % skip the empty set (entrant is the only option)
                if j == nO
                    a = i_othersuppliers;                % keep all = add the entrant
                else
                    a = zeros(nO, nO-1);                 % each row: the set with one supplier left out
                    for r = 1:nO
                        d = nO + 1 - r;                  % row r leaves out element d (same order as nchoosek:
                                                         % last element first), so ties are resolved as before
                        a(r,:) = i_othersuppliers([1:d-1, d+1:end]);
                    end
                end
                for kk = 1:size(a,1)
                    ps = union(c_cat_essentials,a(kk,:));   % supplier set of this option
                    % Same productivity and price formulas as for any firm, using
                    % the customer's own basic productivity level.
                    possible_productivity_i = lam0_v(c)  ...
                    + lambda_1*sum(logproductivity(ps)) ...
                    + eps_i;
                    possible_price_i = ...
                        (1-alpha)/numel(ps)*sum(logprices(ps)) ...
                        - possible_productivity_i;
                    % Remember the cheapest option found so far (it must be strictly
                    % cheaper than the current price).
                    if possible_price_i < logprice_i
                        logprice_i = possible_price_i;
                        suppliers_i = ps;
                    end
                end
            end
        end       
        % Apply the new supplier set only if it includes the entrant. (Other changes,
        % which do not involve the entrant, are not applied.)
        if ismember(n_f+1,suppliers_i)
            A(c,:) = 0;
            A(c,suppliers_i) = 1;
        end
    end

    %% --- 4.5 UPDATE THE NETWORK: ENTRY AND EXITS ----------------------
    if any(A(:,n_f+1))
        % SUCCESS: at least one customer now buys from the entrant, so it joins the network.
        idx_firms = 1:n_f+1;
        firm_catlabels(n_f+1) = t_cat;     % the entrant belongs to the category it chose
        % Entry information of the entrant. Rows 4 and 5 are filled in below, once
        % the exits are known.
        entry_t(:,n_f+1) = [t; t_cat; cat_prox(t_cat); NaN; NaN; n_ess];
        % Give the entrant its permanent id and record the successful entry.
        firm_id(n_f+1) = next_id;
        entry_log(6,t) = 1;
        entry_log(9,t) = next_id;
        next_id = next_id + 1;

        % Remember which firm is the entrant, because positions change when firms
        % are removed below.
        n_before  = n_f + 1;                              % number of firms before exits (entrant included)
        isEntrant = false(1,n_f+1);  isEntrant(end) = true;

        % EXITS: a firm that no longer has any customer (its column of A is all
        % zeros) leaves the economy. When it leaves, it stops buying from its own
        % suppliers, and some of them may then have no customer left either. So
        % this is repeated until every remaining firm has at least one customer
        % (an "exit cascade").
        while sum(any(A,1)) < size(A,1)
            m0 = logical(any(A,1));        % true for firms that still have customers
            A = A(m0,m0);                  % keep only those firms, in all variables
            idx_firms      = idx_firms(m0);
            firm_catlabels = firm_catlabels(m0);
            entry_t        = entry_t(:,m0);
            isEntrant      = isEntrant(m0);
            firm_id        = firm_id(m0);
            lam0_v         = lam0_v(m0);
        end
        n_f = size(A,1);                   % new number of firms

        % Exit statistics
        n_removed   = n_before - n_f;               % all firms removed (including the entrant if it left)
        entrantLive = any(isEntrant);               % is the entrant still in the network?
        n_exit_inc  = n_removed - ~entrantLive;     % incumbents that exited (the entrant is not counted)

        % Proximity of the chosen category AFTER the entry and the exits (computed
        % even if the entrant itself has already left).
        prox_after = categoryProximity(A, firm_catlabels, n_categories, t_cat);
        entry_log(4,t) = prox_after;
        entry_log(5,t) = n_exit_inc;
        entry_log(7,t) = entrantLive;
        if ~entrantLive, entry_log(8,t) = t; end    % the entrant left in its own entry period

        % If the entrant is still in the network, complete its entry information.
        if entrantLive
            ep = find(isEntrant);
            entry_t(4,ep) = prox_after;
            entry_t(5,ep) = n_exit_inc;
        end

        % Record the exit period of EARLIER entrants that left in this period:
        % entrants with an id (row 9), no exit period yet (row 8), whose id is no
        % longer among the firms in the network. (Exits only happen after a
        % successful entry, so checking here never misses an exit.)
        past = entry_log(9,1:t-1);
        gone = ~isnan(past) & isnan(entry_log(8,1:t-1)) & ~ismember(past, firm_id);
        entry_log(8, find(gone)) = t;

        W = sparse(A./sum(A,2));           % each firm spends the same share on each of its suppliers

        % Recompute the whole economy for the new network: structural productivities,
        % a NEW random shock for every firm, equilibrium prices and log real GDP.
        In = speye(n_f);
        logproductivity_raw = (In - lambda_1*sparse(A)) \ lam0_v;
        eps_v = -0.5*log(rand(n_f,1));
        logproductivity = logproductivity_raw + eps_v;
        logprices = (In - (1-alpha)*W) \ (-logproductivity);
        logrealva = -mean(logprices);
    else
        % FAILURE: no customer wants to buy from the entrant. It is removed again, and
        % the economy stays exactly as it was (W, prices, productivities and GDP keep
        % their previous values). In entry_log, row 6 stays 0 and rows 4, 5, 7, 8, 9
        % stay NaN.
        logproductivity(n_f+1) = [];
        logprices(n_f+1) = [];
        lam0_v(n_f+1) = [];
        A(n_f+1,:) = [];
        A(:,n_f+1) = [];
    end

    %% --- 4.6 SAVE THE ECONOMY AT THE END OF THIS PERIOD ---------------
    % (If you change what is saved here, change the same lines in 4.2, which saves
    % the state of periods in which no category can be targeted.)
    if index_save == 1
    s_W{t+1} = sparse(W);
    s_idxfirms{t+1} = idx_firms;
    end
    
    s_logprod{t+1} = logproductivity;
    s_logprices{t+1} = logprices;
    s_growth{t+1} = logrealva;
    s_firm_catlabels{t+1} = firm_catlabels;
    s_firm_id{t+1} = firm_id;
    s_indegree{t+1}  = sum(A,2);     % number of suppliers of each firm (row sums)
    s_outdegree{t+1} = sum(A,1)';    % number of customers of each firm (column sums)
end

%% ------------------------------------------------------------------------
%% 5. WRITE THE RESULTS TO A FILE
%% ------------------------------------------------------------------------
% The file name tells the regime (INC or FNC), the targeting rule, the innovation
% scenario and the run number, so that different simulations do not overwrite
% each other.
if index_nc == 1
    filename = sprintf("sim_%d_%d_%d.mat", index_targeting, index_innovation, t_s);
else
    filename = sprintf("sim_fnc_%d_%d_%d.mat", index_targeting, index_innovation, t_s);
end

if index_save == 0
    % without the weight matrices (smaller files)
    save(filename,'s_firm_catlabels','s_growth','s_logprices','s_logprod', ...
        's_firm_id','entry_log','s_cat_prox','s_indegree','s_outdegree');
elseif index_save == 1
    % with the weight matrices s_W and the position indices s_idxfirms
    save(filename,'s_W','s_firm_catlabels','s_growth','s_logprices','s_logprod', ...
        's_idxfirms','s_firm_id','entry_log','s_cat_prox','s_indegree','s_outdegree');
else
    error('index_save must be 0 or 1.');
end
end

%% ==========================================================================
function [ns, lp_e, price_e] = addOne( ...
    ns, cand, lp, pr, alpha, scalar_p, lambda_0_e, ...
    lp_e, price_e)
% ADDONE  Tries to add ONE extra supplier to the entrant's current suppliers. Every
% candidate is tested, and the best one is added only if it makes the entrant
% cheaper than it already is.
%
% INPUTS
%   ns         : current suppliers of the entrant
%   cand       : candidate firms for the extra supplier
%   lp, pr     : log-productivity and log-price of every existing firm
%   alpha      : labour share of costs
%   scalar_p   : spillover strength lambda_1
%   lambda_0_e : the entrant's basic productivity level
%   lp_e       : the entrant's current log-productivity
%   price_e    : the entrant's current log-price (the price to beat)
% OUTPUTS
%   the supplier set, log-productivity and log-price of the entrant, updated if a
%   supplier was added and unchanged otherwise.
%
% Note: as for all alternative supplier sets, no random shock is included here.
ns = unique(ns(:)');
cand = setdiff(cand(:)', ns);      % remove candidates that are already suppliers
if isempty(cand), return; end      % no candidate left: nothing changes
k    = numel(ns) + 1;              % number of suppliers after adding one
prc  = pr(cand);  prc = prc(:)';   % log-prices of the candidates
lpc  = lp(cand);  lpc = lpc(:)';   % log-productivities of the candidates
% The entrant's log-price for every candidate, computed all at once:
%   (1-alpha) * average log-price of the suppliers
%   - (basic level + lambda_1 * summed log-productivity of the suppliers)
vals = (1-alpha)*(sum(pr(ns)) + prc)/k ...
       - (lambda_0_e + scalar_p*(sum(lp(ns)) + lpc));
mn = min(vals);                    % lowest price among all candidates
if mn < price_e                    % add the supplier only if this is strictly cheaper
    j = find(vals == mn, 1, 'last');   % if several candidates are equally good, take the last one
    ns = [ns, cand(j)];
    lp_e = lambda_0_e + scalar_p*sum(lp(ns));
    price_e = mn;
end
end

%% ==========================================================================
function prox = categoryProximity(A, labels, nCat, onlyCat)
% CATEGORYPROXIMITY  Measures how similar the firms of a category are:
%   proximity = (number of suppliers used by ALL firms of the category)
%               / (largest number of suppliers of any firm of the category).
% 1 means all firms use the same inputs; 0 means they have no input in common.
% Empty categories get NaN. A single-firm category gets a value slightly above 1,
% because its own column is counted as a shared input (see the line marked below).
%
% INPUTS
%   A       : who buys from whom (A(i,j)=1 if firm i buys from firm j)
%   labels  : category of each firm
%   nCat    : number of categories
%   onlyCat : (optional) a single category. If given, only that category is
%             computed and one number is returned; otherwise one value per
%             category is returned.
if nargin < 4
    cats = 1:nCat;
    prox = nan(nCat,1);
else
    cats = onlyCat;
    prox = nan;
end
for q = 1:numel(cats)
    g = cats(q);
    idx = find(labels == g);                      % firms of category g
    if isempty(idx), continue; end                % empty category: leave NaN
    R = A(idx,:);
    R(sub2ind(size(R), 1:numel(idx), idx)) = 1;   % each firm's own column set to 1, since a firm
                                                  % cannot buy from itself (same rule as for
                                                  % essential inputs in the main code)
    common = sum(all(R,1));                       % number of inputs used by all firms
    maxdeg = max(sum(A(idx,:),2));                % largest number of suppliers in the category
    prox(q) = common / max(maxdeg,1);             % max(...,1) avoids dividing by zero
end
end
